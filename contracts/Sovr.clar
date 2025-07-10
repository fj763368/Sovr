(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_IDENTITY_EXISTS (err u101))
(define-constant ERR_IDENTITY_NOT_FOUND (err u102))
(define-constant ERR_INVALID_ATTRIBUTE (err u103))
(define-constant ERR_VERIFICATION_EXISTS (err u104))
(define-constant ERR_VERIFICATION_NOT_FOUND (err u105))
(define-constant ERR_INVALID_VERIFIER (err u106))
(define-constant ERR_REPUTATION_NOT_FOUND (err u107))
(define-constant ERR_ENDORSEMENT_EXISTS (err u108))
(define-constant ERR_SELF_ENDORSEMENT (err u109))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u110))
(define-constant ERR_INVALID_SCORE (err u111))
(define-constant ERR_ACHIEVEMENT_EXISTS (err u112))
(define-constant ERR_ACHIEVEMENT_NOT_FOUND (err u113))

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
(define-data-var achievement-counter uint u0)

(define-map reputation-scores
  { owner: principal }
  {
    base-score: uint,
    endorsement-score: uint,
    verification-score: uint,
    achievement-score: uint,
    total-score: uint,
    last-updated: uint
  }
)

(define-map endorsements
  { endorser: principal, endorsed: principal }
  {
    score: uint,
    reason: (string-ascii 128),
    created-at: uint,
    is-active: bool
  }
)

(define-map achievements
  { owner: principal, achievement-id: uint }
  {
    title: (string-ascii 64),
    description: (string-ascii 256),
    category: (string-ascii 32),
    score-value: uint,
    earned-at: uint,
    verifier: principal
  }
)

(define-map achievement-types
  { achievement-id: uint }
  {
    title: (string-ascii 64),
    description: (string-ascii 256),
    category: (string-ascii 32),
    base-score: uint,
    requirements: (string-ascii 256),
    is-active: bool,
    created-at: uint
  }
)

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
    (map-set reputation-scores
      { owner: caller }
      {
        base-score: u100,
        endorsement-score: u0,
        verification-score: u0,
        achievement-score: u0,
        total-score: u100,
        last-updated: current-block
      }
    )
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
    (try! (update-reputation-score subject u25 "verification"))
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

(define-public (create-achievement-type 
  (title (string-ascii 64))
  (description (string-ascii 256))
  (category (string-ascii 32))
  (base-score uint)
  (requirements (string-ascii 256))
)
  (let
    (
      (achievement-id (+ (var-get achievement-counter) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> base-score u0) ERR_INVALID_SCORE)
    (var-set achievement-counter achievement-id)
    (map-set achievement-types
      { achievement-id: achievement-id }
      {
        title: title,
        description: description,
        category: category,
        base-score: base-score,
        requirements: requirements,
        is-active: true,
        created-at: stacks-block-height
      }
    )
    (ok achievement-id)
  )
)

(define-public (grant-achievement (owner principal) (achievement-id uint))
  (let
    (
      (achievement-type (unwrap! (map-get? achievement-types { achievement-id: achievement-id }) ERR_ACHIEVEMENT_NOT_FOUND))
      (verifier tx-sender)
    )
    (asserts! (is-some (map-get? identities { owner: owner })) ERR_IDENTITY_NOT_FOUND)
    (asserts! (is-some (map-get? trusted-verifiers { verifier: verifier })) ERR_INVALID_VERIFIER)
    (asserts! (get is-active achievement-type) ERR_ACHIEVEMENT_NOT_FOUND)
    (asserts! (is-none (map-get? achievements { owner: owner, achievement-id: achievement-id })) ERR_ACHIEVEMENT_EXISTS)
    (map-set achievements
      { owner: owner, achievement-id: achievement-id }
      {
        title: (get title achievement-type),
        description: (get description achievement-type),
        category: (get category achievement-type),
        score-value: (get base-score achievement-type),
        earned-at: stacks-block-height,
        verifier: verifier
      }
    )
    (try! (update-reputation-score owner (get base-score achievement-type) "achievement"))
    (ok true)
  )
)

(define-public (endorse-user (endorsed principal) (score uint) (reason (string-ascii 128)))
  (let
    (
      (endorser tx-sender)
      (endorser-reputation (unwrap! (map-get? reputation-scores { owner: endorser }) ERR_REPUTATION_NOT_FOUND))
    )
    (asserts! (not (is-eq endorser endorsed)) ERR_SELF_ENDORSEMENT)
    (asserts! (is-some (map-get? identities { owner: endorsed })) ERR_IDENTITY_NOT_FOUND)
    (asserts! (is-some (map-get? identities { owner: endorser })) ERR_IDENTITY_NOT_FOUND)
    (asserts! (>= (get total-score endorser-reputation) u200) ERR_INSUFFICIENT_REPUTATION)
    (asserts! (and (>= score u1) (<= score u50)) ERR_INVALID_SCORE)
    (asserts! (is-none (map-get? endorsements { endorser: endorser, endorsed: endorsed })) ERR_ENDORSEMENT_EXISTS)
    (map-set endorsements
      { endorser: endorser, endorsed: endorsed }
      {
        score: score,
        reason: reason,
        created-at: stacks-block-height,
        is-active: true
      }
    )
    (try! (update-reputation-score endorsed score "endorsement"))
    (ok true)
  )
)

(define-public (revoke-endorsement (endorsed principal))
  (let
    (
      (endorser tx-sender)
      (endorsement (unwrap! (map-get? endorsements { endorser: endorser, endorsed: endorsed }) ERR_ENDORSEMENT_EXISTS))
    )
    (asserts! (get is-active endorsement) ERR_ENDORSEMENT_EXISTS)
    (map-set endorsements
      { endorser: endorser, endorsed: endorsed }
      (merge endorsement { is-active: false })
    )
    (try! (update-reputation-score endorsed (- u0 (get score endorsement)) "endorsement"))
    (ok true)
  )
)

(define-private (update-reputation-score (owner principal) (score-change uint) (score-type (string-ascii 32)))
  (let
    (
      (current-reputation (unwrap! (map-get? reputation-scores { owner: owner }) ERR_REPUTATION_NOT_FOUND))
      (new-endorsement-score (if (is-eq score-type "endorsement")
                                (+ (get endorsement-score current-reputation) score-change)
                                (get endorsement-score current-reputation)))
      (new-verification-score (if (is-eq score-type "verification")
                                 (+ (get verification-score current-reputation) score-change)
                                 (get verification-score current-reputation)))
      (new-achievement-score (if (is-eq score-type "achievement")
                                (+ (get achievement-score current-reputation) score-change)
                                (get achievement-score current-reputation)))
      (new-total-score (+ (get base-score current-reputation) new-endorsement-score new-verification-score new-achievement-score))
    )
    (map-set reputation-scores
      { owner: owner }
      {
        base-score: (get base-score current-reputation),
        endorsement-score: new-endorsement-score,
        verification-score: new-verification-score,
        achievement-score: new-achievement-score,
        total-score: new-total-score,
        last-updated: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-read-only (get-reputation-score (owner principal))
  (map-get? reputation-scores { owner: owner })
)

(define-read-only (get-endorsement (endorser principal) (endorsed principal))
  (map-get? endorsements { endorser: endorser, endorsed: endorsed })
)

(define-read-only (get-achievement (owner principal) (achievement-id uint))
  (map-get? achievements { owner: owner, achievement-id: achievement-id })
)

(define-read-only (get-achievement-type (achievement-id uint))
  (map-get? achievement-types { achievement-id: achievement-id })
)

(define-read-only (get-user-achievements (owner principal))
  (ok (list
    (map-get? achievements { owner: owner, achievement-id: u1 })
    (map-get? achievements { owner: owner, achievement-id: u2 })
    (map-get? achievements { owner: owner, achievement-id: u3 })
    (map-get? achievements { owner: owner, achievement-id: u4 })
    (map-get? achievements { owner: owner, achievement-id: u5 })
  ))
)

(define-read-only (calculate-trust-level (owner principal))
  (let
    (
      (reputation (unwrap! (map-get? reputation-scores { owner: owner }) (err "no-reputation")))
      (total-score (get total-score reputation))
    )
    (if (>= total-score u1000)
        (ok "expert")
        (if (>= total-score u500)
            (ok "trusted")
            (if (>= total-score u200)
                (ok "verified")
                (ok "newcomer"))))
  )
)

(define-read-only (get-achievement-count)
  (var-get achievement-counter)
)