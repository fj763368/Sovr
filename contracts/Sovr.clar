(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_IDENTITY_EXISTS (err u101))
(define-constant ERR_IDENTITY_NOT_FOUND (err u102))
(define-constant ERR_INVALID_ATTRIBUTE (err u103))
(define-constant ERR_VERIFICATION_EXISTS (err u104))
(define-constant ERR_VERIFICATION_NOT_FOUND (err u105))
(define-constant ERR_INVALID_VERIFIER (err u106))

(define-map identities 
  { owner: principal }
  {
    did: (string-ascii 64),
    created-at: uint,
    updated-at: uint,
    is-active: bool
  }
)

(define-map identity-attributes
  { owner: principal, key: (string-ascii 32) }
  {
    value: (string-ascii 256),
    is-public: bool,
    updated-at: uint
  }
)

(define-map verifications
  { 
    subject: principal,
    verifier: principal,
    claim-type: (string-ascii 32)
  }
  {
    claim-value: (string-ascii 256),
    verified-at: uint,
    expires-at: (optional uint),
    is-valid: bool
  }
)

(define-map trusted-verifiers
  { verifier: principal }
  {
    name: (string-ascii 64),
    added-at: uint,
    is-active: bool
  }
)

(define-data-var identity-counter uint u0)

(define-public (create-identity (did (string-ascii 64)))
  (let
    (
      (caller tx-sender)
      (current-block stacks-block-height)
    )
    (asserts! (is-none (map-get? identities { owner: caller })) ERR_IDENTITY_EXISTS)
    (map-set identities
      { owner: caller }
      {
        did: did,
        created-at: current-block,
        updated-at: current-block,
        is-active: true
      }
    )
    (var-set identity-counter (+ (var-get identity-counter) u1))
    (ok true)
  )
)

(define-public (update-identity-status (is-active bool))
  (let
    (
      (caller tx-sender)
      (identity (unwrap! (map-get? identities { owner: caller }) ERR_IDENTITY_NOT_FOUND))
    )
    (map-set identities
      { owner: caller }
      (merge identity { is-active: is-active, updated-at: stacks-block-height })
    )
    (ok true)
  )
)

(define-public (set-attribute (key (string-ascii 32)) (value (string-ascii 256)) (is-public bool))
  (let
    (
      (caller tx-sender)
    )
    (asserts! (is-some (map-get? identities { owner: caller })) ERR_IDENTITY_NOT_FOUND)
    (map-set identity-attributes
      { owner: caller, key: key }
      {
        value: value,
        is-public: is-public,
        updated-at: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (remove-attribute (key (string-ascii 32)))
  (let
    (
      (caller tx-sender)
    )
    (asserts! (is-some (map-get? identities { owner: caller })) ERR_IDENTITY_NOT_FOUND)
    (asserts! (is-some (map-get? identity-attributes { owner: caller, key: key })) ERR_INVALID_ATTRIBUTE)
    (map-delete identity-attributes { owner: caller, key: key })
    (ok true)
  )
)

(define-public (add-trusted-verifier (verifier principal) (name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set trusted-verifiers
      { verifier: verifier }
      {
        name: name,
        added-at: stacks-block-height,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (remove-trusted-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? trusted-verifiers { verifier: verifier })) ERR_INVALID_VERIFIER)
    (map-delete trusted-verifiers { verifier: verifier })
    (ok true)
  )
)

(define-public (issue-verification 
  (subject principal) 
  (claim-type (string-ascii 32)) 
  (claim-value (string-ascii 256))
  (expires-at (optional uint))
)
  (let
    (
      (verifier tx-sender)
    )
    (asserts! (is-some (map-get? identities { owner: subject })) ERR_IDENTITY_NOT_FOUND)
    (asserts! (is-some (map-get? trusted-verifiers { verifier: verifier })) ERR_INVALID_VERIFIER)
    (asserts! (is-none (map-get? verifications { subject: subject, verifier: verifier, claim-type: claim-type })) ERR_VERIFICATION_EXISTS)
    (map-set verifications
      { subject: subject, verifier: verifier, claim-type: claim-type }
      {
        claim-value: claim-value,
        verified-at: stacks-block-height,
        expires-at: expires-at,
        is-valid: true
      }
    )
    (ok true)
  )
)

(define-public (revoke-verification (subject principal) (claim-type (string-ascii 32)))
  (let
    (
      (verifier tx-sender)
      (verification (unwrap! (map-get? verifications { subject: subject, verifier: verifier, claim-type: claim-type }) ERR_VERIFICATION_NOT_FOUND))
    )
    (asserts! (is-some (map-get? trusted-verifiers { verifier: verifier })) ERR_INVALID_VERIFIER)
    (map-set verifications
      { subject: subject, verifier: verifier, claim-type: claim-type }
      (merge verification { is-valid: false })
    )
    (ok true)
  )
)

(define-read-only (get-identity (owner principal))
  (map-get? identities { owner: owner })
)

(define-read-only (get-attribute (owner principal) (key (string-ascii 32)))
  (let
    (
      (attribute (map-get? identity-attributes { owner: owner, key: key }))
    )
    (match attribute
      attr (if (get is-public attr)
             (some attr)
             (if (is-eq tx-sender owner)
                 (some attr)
                 none))
      none
    )
  )
)

(define-read-only (get-verification (subject principal) (verifier principal) (claim-type (string-ascii 32)))
  (let
    (
      (verification (map-get? verifications { subject: subject, verifier: verifier, claim-type: claim-type }))
    )
    (match verification
      ver (if (and 
                (get is-valid ver)
                (match (get expires-at ver)
                  exp (< stacks-block-height exp)
                  true))
              (some ver)
              none)
      none
    )
  )
)

(define-read-only (is-trusted-verifier (verifier principal))
  (match (map-get? trusted-verifiers { verifier: verifier })
    verifier-info (get is-active verifier-info)
    false
  )
)

(define-read-only (get-identity-count)
  (var-get identity-counter)
)

(define-read-only (verify-identity-ownership (owner principal))
  (is-some (map-get? identities { owner: owner }))
)

(define-read-only (get-trusted-verifier (verifier principal))
  (map-get? trusted-verifiers { verifier: verifier })
)