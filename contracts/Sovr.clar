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
(define-constant ERR_GROUP_NOT_FOUND (err u114))
(define-constant ERR_GROUP_EXISTS (err u115))
(define-constant ERR_NOT_GROUP_ADMIN (err u116))
(define-constant ERR_NOT_GROUP_MEMBER (err u117))
(define-constant ERR_MEMBER_EXISTS (err u118))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u119))
(define-constant ERR_PROPOSAL_EXPIRED (err u120))
(define-constant ERR_ALREADY_VOTED (err u121))
(define-constant ERR_INSUFFICIENT_VOTES (err u122))

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
(define-data-var group-counter uint u0)
(define-data-var proposal-counter uint u0)

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

;; Group/Organization management maps
(define-map identity-groups
  { group-id: uint }
  {
    name: (string-ascii 128),
    description: (string-ascii 256),
    admin: principal,
    member-count: uint,
    min-reputation: uint,
    created-at: uint,
    is-active: bool
  }
)

(define-map group-members
  { group-id: uint, member: principal }
  {
    joined-at: uint,
    role: (string-ascii 32),
    voting-power: uint,
    is-active: bool
  }
)

(define-map group-attributes
  { group-id: uint, key: (string-ascii 32) }
  {
    value: (string-ascii 256),
    set-by: principal,
    updated-at: uint
  }
)

(define-map group-proposals
  { proposal-id: uint }
  {
    group-id: uint,
    proposer: principal,
    proposal-type: (string-ascii 32),
    description: (string-ascii 256),
    target-data: (string-ascii 128),
    votes-for: uint,
    votes-against: uint,
    min-votes-required: uint,
    expires-at: uint,
    executed: bool
  }
)

(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  {
    vote: bool,
    voting-power: uint,
    voted-at: uint
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

;; Group/Organization management functions
(define-public (create-group 
  (name (string-ascii 128))
  (description (string-ascii 256))
  (min-reputation uint)
)
  (let
    (
      (group-id (+ (var-get group-counter) u1))
      (creator tx-sender)
      (creator-reputation (unwrap! (map-get? reputation-scores { owner: creator }) ERR_REPUTATION_NOT_FOUND))
    )
    ;; Require creator to have sufficient reputation to create groups
    (asserts! (>= (get total-score creator-reputation) u300) ERR_INSUFFICIENT_REPUTATION)
    (asserts! (is-some (map-get? identities { owner: creator })) ERR_IDENTITY_NOT_FOUND)
    (var-set group-counter group-id)
    (map-set identity-groups
      { group-id: group-id }
      {
        name: name,
        description: description,
        admin: creator,
        member-count: u1,
        min-reputation: min-reputation,
        created-at: stacks-block-height,
        is-active: true
      }
    )
    ;; Add creator as first member with admin role
    (map-set group-members
      { group-id: group-id, member: creator }
      {
        joined-at: stacks-block-height,
        role: "admin",
        voting-power: u10,
        is-active: true
      }
    )
    (ok group-id)
  )
)

(define-public (join-group (group-id uint))
  (let
    (
      (member tx-sender)
      (group-info (unwrap! (map-get? identity-groups { group-id: group-id }) ERR_GROUP_NOT_FOUND))
      (member-reputation (unwrap! (map-get? reputation-scores { owner: member }) ERR_REPUTATION_NOT_FOUND))
    )
    (asserts! (get is-active group-info) ERR_GROUP_NOT_FOUND)
    (asserts! (is-some (map-get? identities { owner: member })) ERR_IDENTITY_NOT_FOUND)
    (asserts! (>= (get total-score member-reputation) (get min-reputation group-info)) ERR_INSUFFICIENT_REPUTATION)
    (asserts! (is-none (map-get? group-members { group-id: group-id, member: member })) ERR_MEMBER_EXISTS)
    ;; Calculate voting power based on reputation
    (let
      (
        (voting-power (if (> (/ (get total-score member-reputation) u100) u5) u5 (/ (get total-score member-reputation) u100)))
      )
      (map-set group-members
        { group-id: group-id, member: member }
        {
          joined-at: stacks-block-height,
          role: "member",
          voting-power: voting-power,
          is-active: true
        }
      )
      ;; Update member count
      (map-set identity-groups
        { group-id: group-id }
        (merge group-info { member-count: (+ (get member-count group-info) u1) })
      )
      (ok true)
    )
  )
)

(define-public (leave-group (group-id uint))
  (let
    (
      (member tx-sender)
      (group-info (unwrap! (map-get? identity-groups { group-id: group-id }) ERR_GROUP_NOT_FOUND))
      (membership (unwrap! (map-get? group-members { group-id: group-id, member: member }) ERR_NOT_GROUP_MEMBER))
    )
    (asserts! (get is-active membership) ERR_NOT_GROUP_MEMBER)
    ;; Admin cannot leave if there are other members
    (asserts! (or (is-eq (get member-count group-info) u1) 
                  (not (is-eq (get role membership) "admin"))) ERR_NOT_GROUP_ADMIN)
    (map-set group-members
      { group-id: group-id, member: member }
      (merge membership { is-active: false })
    )
    ;; Update member count
    (map-set identity-groups
      { group-id: group-id }
      (merge group-info { member-count: (- (get member-count group-info) u1) })
    )
    (ok true)
  )
)

(define-public (set-group-attribute (group-id uint) (key (string-ascii 32)) (value (string-ascii 256)))
  (let
    (
      (setter tx-sender)
      (group-info (unwrap! (map-get? identity-groups { group-id: group-id }) ERR_GROUP_NOT_FOUND))
      (membership (unwrap! (map-get? group-members { group-id: group-id, member: setter }) ERR_NOT_GROUP_MEMBER))
    )
    (asserts! (get is-active group-info) ERR_GROUP_NOT_FOUND)
    (asserts! (get is-active membership) ERR_NOT_GROUP_MEMBER)
    ;; Only admin or members with voting power >= 3 can set attributes
    (asserts! (or (is-eq (get role membership) "admin") 
                  (>= (get voting-power membership) u3)) ERR_NOT_GROUP_ADMIN)
    (map-set group-attributes
      { group-id: group-id, key: key }
      {
        value: value,
        set-by: setter,
        updated-at: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (create-group-proposal 
  (group-id uint)
  (proposal-type (string-ascii 32))
  (description (string-ascii 256))
  (target-data (string-ascii 128))
)
  (let
    (
      (proposal-id (+ (var-get proposal-counter) u1))
      (proposer tx-sender)
      (group-info (unwrap! (map-get? identity-groups { group-id: group-id }) ERR_GROUP_NOT_FOUND))
      (membership (unwrap! (map-get? group-members { group-id: group-id, member: proposer }) ERR_NOT_GROUP_MEMBER))
      (min-votes (if (> (/ (get member-count group-info) u2) u1) (/ (get member-count group-info) u2) u1))
    )
    (asserts! (get is-active group-info) ERR_GROUP_NOT_FOUND)
    (asserts! (get is-active membership) ERR_NOT_GROUP_MEMBER)
    (var-set proposal-counter proposal-id)
    (map-set group-proposals
      { proposal-id: proposal-id }
      {
        group-id: group-id,
        proposer: proposer,
        proposal-type: proposal-type,
        description: description,
        target-data: target-data,
        votes-for: u0,
        votes-against: u0,
        min-votes-required: min-votes,
        expires-at: (+ stacks-block-height u1440),
        executed: false
      }
    )
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let
    (
      (voter tx-sender)
      (proposal (unwrap! (map-get? group-proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (membership (unwrap! (map-get? group-members { group-id: (get group-id proposal), member: voter }) ERR_NOT_GROUP_MEMBER))
    )
    (asserts! (< stacks-block-height (get expires-at proposal)) ERR_PROPOSAL_EXPIRED)
    (asserts! (get is-active membership) ERR_NOT_GROUP_MEMBER)
    (asserts! (is-none (map-get? proposal-votes { proposal-id: proposal-id, voter: voter })) ERR_ALREADY_VOTED)
    (let
      (
        (voting-power (get voting-power membership))
        (new-votes-for (if vote (+ (get votes-for proposal) voting-power) (get votes-for proposal)))
        (new-votes-against (if vote (get votes-against proposal) (+ (get votes-against proposal) voting-power)))
      )
      (map-set proposal-votes
        { proposal-id: proposal-id, voter: voter }
        {
          vote: vote,
          voting-power: voting-power,
          voted-at: stacks-block-height
        }
      )
      (map-set group-proposals
        { proposal-id: proposal-id }
        (merge proposal { votes-for: new-votes-for, votes-against: new-votes-against })
      )
      (ok true)
    )
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (executor tx-sender)
      (proposal (unwrap! (map-get? group-proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (group-info (unwrap! (map-get? identity-groups { group-id: (get group-id proposal) }) ERR_GROUP_NOT_FOUND))
      (membership (unwrap! (map-get? group-members { group-id: (get group-id proposal), member: executor }) ERR_NOT_GROUP_MEMBER))
    )
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_EXPIRED)
    (asserts! (get is-active membership) ERR_NOT_GROUP_MEMBER)
    (asserts! (>= (get votes-for proposal) (get min-votes-required proposal)) ERR_INSUFFICIENT_VOTES)
    (asserts! (> (get votes-for proposal) (get votes-against proposal)) ERR_INSUFFICIENT_VOTES)
    ;; Mark proposal as executed
    (map-set group-proposals
      { proposal-id: proposal-id }
      (merge proposal { executed: true })
    )
    ;; Execute based on proposal type (simplified implementation)
    (if (is-eq (get proposal-type proposal) "attribute")
        (begin
          (try! (set-group-attribute (get group-id proposal) "decision" (get target-data proposal)))
          (ok true))
        (ok true))
  )
)

;; Read-only functions for groups
(define-read-only (get-group (group-id uint))
  (map-get? identity-groups { group-id: group-id })
)

(define-read-only (get-group-member (group-id uint) (member principal))
  (map-get? group-members { group-id: group-id, member: member })
)

(define-read-only (get-group-attribute (group-id uint) (key (string-ascii 32)))
  (map-get? group-attributes { group-id: group-id, key: key })
)

(define-read-only (get-group-proposal (proposal-id uint))
  (map-get? group-proposals { proposal-id: proposal-id })
)

(define-read-only (get-proposal-vote (proposal-id uint) (voter principal))
  (map-get? proposal-votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (is-group-member (group-id uint) (member principal))
  (match (map-get? group-members { group-id: group-id, member: member })
    membership (get is-active membership)
    false
  )
)

(define-read-only (get-group-count)
  (var-get group-counter)
)

(define-read-only (get-proposal-count)
  (var-get proposal-counter)
)

