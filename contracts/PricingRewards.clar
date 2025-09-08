;; ==========================================
;; Sovr Dynamic Pricing Rewards System
;; ==========================================

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_IDENTITY_NOT_FOUND (err u201))
(define-constant ERR_INSUFFICIENT_POINTS (err u202))
(define-constant ERR_INVALID_AMOUNT (err u203))
(define-constant ERR_REWARD_NOT_FOUND (err u204))
(define-constant ERR_TIER_NOT_FOUND (err u205))
(define-constant ERR_ALREADY_REDEEMED (err u206))
(define-constant ERR_MAX_TIER_REACHED (err u207))

;; Data variables
(define-data-var total-rewards-issued uint u0)
(define-data-var base-reward-rate uint u10) ;; Points per 1000 STX spent
(define-data-var loyalty-multiplier uint u150) ;; 1.5x multiplier for loyal users

;; User activity tracking
(define-map user-activity
  { user: principal }
  {
    total-transactions: uint,
    total-fees-paid: uint,
    loyalty-points: uint,
    points-redeemed: uint,
    tier-level: uint,
    last-activity: uint,
    streak-days: uint,
    first-activity: uint
  }
)

;; Loyalty tier definitions
(define-map loyalty-tiers
  { tier-id: uint }
  {
    name: (string-ascii 32),
    min-transactions: uint,
    min-fees-paid: uint,
    discount-percentage: uint,
    bonus-multiplier: uint,
    requirements: (string-ascii 128)
  }
)

;; Reward redemption tracking
(define-map redemptions
  { user: principal, redemption-id: uint }
  {
    points-used: uint,
    reward-type: (string-ascii 32),
    reward-value: uint,
    redeemed-at: uint,
    expires-at: uint,
    is-active: bool
  }
)

;; Available rewards catalog
(define-map reward-catalog
  { reward-id: uint }
  {
    name: (string-ascii 64),
    description: (string-ascii 256),
    point-cost: uint,
    reward-type: (string-ascii 32),
    value: uint,
    validity-period: uint,
    is-active: bool
  }
)

(define-data-var redemption-counter uint u0)
(define-data-var reward-catalog-counter uint u0)

;; Initialize default loyalty tiers
(map-set loyalty-tiers { tier-id: u1 }
  {
    name: "Bronze",
    min-transactions: u5,
    min-fees-paid: u5000,
    discount-percentage: u5,
    bonus-multiplier: u110,
    requirements: "5+ transactions, 5000+ STX fees"
  }
)

(map-set loyalty-tiers { tier-id: u2 }
  {
    name: "Silver", 
    min-transactions: u20,
    min-fees-paid: u25000,
    discount-percentage: u10,
    bonus-multiplier: u125,
    requirements: "20+ transactions, 25000+ STX fees"
  }
)

(map-set loyalty-tiers { tier-id: u3 }
  {
    name: "Gold",
    min-transactions: u50,
    min-fees-paid: u75000,
    discount-percentage: u15,
    bonus-multiplier: u150,
    requirements: "50+ transactions, 75000+ STX fees"
  }
)

(map-set loyalty-tiers { tier-id: u4 }
  {
    name: "Platinum",
    min-transactions: u100,
    min-fees-paid: u200000,
    discount-percentage: u20,
    bonus-multiplier: u200,
    requirements: "100+ transactions, 200000+ STX fees"
  }
)

;; Initialize default reward catalog
(map-set reward-catalog { reward-id: u1 }
  {
    name: "5% Service Discount",
    description: "5% discount on next service transaction",
    point-cost: u100,
    reward-type: "discount",
    value: u5,
    validity-period: u720, ;; ~5 days
    is-active: true
  }
)

(map-set reward-catalog { reward-id: u2 }
  {
    name: "10% Service Discount", 
    description: "10% discount on next service transaction",
    point-cost: u250,
    reward-type: "discount",
    value: u10,
    validity-period: u720,
    is-active: true
  }
)

(map-set reward-catalog { reward-id: u3 }
  {
    name: "Free Priority Support",
    description: "Free priority support access for 30 days",
    point-cost: u500,
    reward-type: "service",
    value: u30,
    validity-period: u4320, ;; ~30 days
    is-active: true
  }
)

(var-set reward-catalog-counter u3)

;; Public Functions

;; Record service usage and award loyalty points
(define-public (record-service-usage (fee-paid uint))
  (let
    (
      (user tx-sender)
      (current-activity (default-to 
        {
          total-transactions: u0,
          total-fees-paid: u0,
          loyalty-points: u0,
          points-redeemed: u0,
          tier-level: u0,
          last-activity: u0,
          streak-days: u0,
          first-activity: stacks-block-height
        }
        (map-get? user-activity { user: user })))
      (points-earned (calculate-points-earned fee-paid (get tier-level current-activity)))
      (new-total-transactions (+ (get total-transactions current-activity) u1))
      (new-total-fees (+ (get total-fees-paid current-activity) fee-paid))
      (new-loyalty-points (+ (get loyalty-points current-activity) points-earned))
      (new-tier (calculate-user-tier new-total-transactions new-total-fees))
      (streak (calculate-streak-days (get last-activity current-activity)))
    )
    ;; Verify user has Sovr identity
    (asserts! (contract-call? .Sovr verify-identity-ownership user) ERR_IDENTITY_NOT_FOUND)
    (asserts! (> fee-paid u0) ERR_INVALID_AMOUNT)
    
    (map-set user-activity
      { user: user }
      {
        total-transactions: new-total-transactions,
        total-fees-paid: new-total-fees,
        loyalty-points: new-loyalty-points,
        points-redeemed: (get points-redeemed current-activity),
        tier-level: new-tier,
        last-activity: stacks-block-height,
        streak-days: streak,
        first-activity: (get first-activity current-activity)
      }
    )
    (var-set total-rewards-issued (+ (var-get total-rewards-issued) points-earned))
    (ok points-earned)
  )
)

;; Redeem loyalty points for rewards
(define-public (redeem-reward (reward-id uint))
  (let
    (
      (user tx-sender)
      (user-act (unwrap! (map-get? user-activity { user: user }) ERR_IDENTITY_NOT_FOUND))
      (reward (unwrap! (map-get? reward-catalog { reward-id: reward-id }) ERR_REWARD_NOT_FOUND))
      (redemption-id (+ (var-get redemption-counter) u1))
    )
    (asserts! (get is-active reward) ERR_REWARD_NOT_FOUND)
    (asserts! (>= (get loyalty-points user-act) (get point-cost reward)) ERR_INSUFFICIENT_POINTS)
    
    ;; Deduct points and create redemption record
    (map-set user-activity
      { user: user }
      (merge user-act
        {
          loyalty-points: (- (get loyalty-points user-act) (get point-cost reward)),
          points-redeemed: (+ (get points-redeemed user-act) (get point-cost reward))
        }
      )
    )
    
    (var-set redemption-counter redemption-id)
    (map-set redemptions
      { user: user, redemption-id: redemption-id }
      {
        points-used: (get point-cost reward),
        reward-type: (get reward-type reward),
        reward-value: (get value reward),
        redeemed-at: stacks-block-height,
        expires-at: (+ stacks-block-height (get validity-period reward)),
        is-active: true
      }
    )
    (ok redemption-id)
  )
)

;; Calculate discount for user based on tier and active redemptions
(define-public (calculate-user-discount (user principal) (base-amount uint))
  (let
    (
      (user-act (unwrap! (map-get? user-activity { user: user }) ERR_IDENTITY_NOT_FOUND))
      (tier-info (map-get? loyalty-tiers { tier-id: (get tier-level user-act) }))
      (tier-discount (match tier-info
        tier (get discount-percentage tier)
        u0))
      ;; Check for active discount redemptions
      (active-discount (get-active-discount user))
      (total-discount (+ tier-discount active-discount))
      (max-discount u25) ;; Cap at 25%
      (final-discount (if (> total-discount max-discount) max-discount total-discount))
      (discount-amount (/ (* base-amount final-discount) u100))
    )
    (ok { 
      discount-percentage: final-discount,
      discount-amount: discount-amount,
      final-amount: (- base-amount discount-amount)
    })
  )
)

;; Admin function to add new rewards to catalog
(define-public (add-reward-to-catalog 
  (name (string-ascii 64))
  (description (string-ascii 256))
  (point-cost uint)
  (reward-type (string-ascii 32))
  (value uint)
  (validity-period uint)
)
  (let
    (
      (reward-id (+ (var-get reward-catalog-counter) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> point-cost u0) ERR_INVALID_AMOUNT)
    (asserts! (> value u0) ERR_INVALID_AMOUNT)
    
    (var-set reward-catalog-counter reward-id)
    (map-set reward-catalog
      { reward-id: reward-id }
      {
        name: name,
        description: description,
        point-cost: point-cost,
        reward-type: reward-type,
        value: value,
        validity-period: validity-period,
        is-active: true
      }
    )
    (ok reward-id)
  )
)

;; Private helper functions

(define-private (calculate-points-earned (fee-paid uint) (tier-level uint))
  (let
    (
      (base-points (/ (* fee-paid (var-get base-reward-rate)) u1000))
      (tier-info (map-get? loyalty-tiers { tier-id: tier-level }))
      (multiplier (match tier-info
        tier (get bonus-multiplier tier)
        u100))
    )
    (/ (* base-points multiplier) u100)
  )
)

(define-private (calculate-user-tier (transactions uint) (fees-paid uint))
  (if (and (>= transactions u100) (>= fees-paid u200000))
      u4 ;; Platinum
      (if (and (>= transactions u50) (>= fees-paid u75000))
          u3 ;; Gold
          (if (and (>= transactions u20) (>= fees-paid u25000))
              u2 ;; Silver
              (if (and (>= transactions u5) (>= fees-paid u5000))
                  u1 ;; Bronze
                  u0 ;; No tier
              )
          )
      )
  )
)

(define-private (calculate-streak-days (last-activity uint))
  (let
    (
      (blocks-since-last (- stacks-block-height last-activity))
      (blocks-per-day u144) ;; Approximate blocks per day
    )
    (if (<= blocks-since-last (* blocks-per-day u2)) ;; Within 2 days
        u1
        u0)
  )
)

(define-private (get-active-discount (user principal))
  ;; Simplified: check if user has active discount redemption
  ;; In a full implementation, this would iterate through redemptions
  (let
    (
      (redemption (map-get? redemptions { user: user, redemption-id: u1 }))
    )
    (match redemption
      red (if (and (get is-active red) 
                   (< stacks-block-height (get expires-at red))
                   (is-eq (get reward-type red) "discount"))
              (get reward-value red)
              u0)
      u0)
  )
)

;; Read-only functions

(define-read-only (get-user-activity (user principal))
  (map-get? user-activity { user: user })
)

(define-read-only (get-user-tier-info (user principal))
  (let
    (
      (activity (map-get? user-activity { user: user }))
    )
    (match activity
      act (map-get? loyalty-tiers { tier-id: (get tier-level act) })
      none)
  )
)

(define-read-only (get-loyalty-tier (tier-id uint))
  (map-get? loyalty-tiers { tier-id: tier-id })
)

(define-read-only (get-reward-info (reward-id uint))
  (map-get? reward-catalog { reward-id: reward-id })
)

(define-read-only (get-user-redemption (user principal) (redemption-id uint))
  (map-get? redemptions { user: user, redemption-id: redemption-id })
)

(define-read-only (estimate-points-for-fee (fee-amount uint) (user principal))
  (let
    (
      (activity (map-get? user-activity { user: user }))
      (tier-level (match activity
        act (get tier-level act)
        u0))
    )
    (ok (calculate-points-earned fee-amount tier-level))
  )
)

;; Check if user qualifies for next tier
(define-read-only (check-tier-upgrade-eligibility (user principal))
  (let
    (
      (activity (unwrap! (map-get? user-activity { user: user }) ERR_IDENTITY_NOT_FOUND))
      (current-tier (get tier-level activity))
      (next-tier-id (+ current-tier u1))
      (next-tier (map-get? loyalty-tiers { tier-id: next-tier-id }))
    )
    (match next-tier
      tier (ok {
        current-tier: current-tier,
        next-tier: next-tier-id,
        transactions-needed: (if (>= (get total-transactions activity) (get min-transactions tier))
                               u0
                               (- (get min-transactions tier) (get total-transactions activity))),
        fees-needed: (if (>= (get total-fees-paid activity) (get min-fees-paid tier))
                       u0
                       (- (get min-fees-paid tier) (get total-fees-paid activity)))
      })
      (err u114))
  )
)

;; Get user's current point balance and tier status
(define-read-only (get-user-loyalty-status (user principal))
  (let
    (
      (activity (map-get? user-activity { user: user }))
      (sovr-identity (contract-call? .Sovr get-identity user))
    )
    (match activity
      act (ok {
        has-identity: (is-some sovr-identity),
        loyalty-points: (get loyalty-points act),
        tier-level: (get tier-level act),
        total-transactions: (get total-transactions act),
        total-fees-paid: (get total-fees-paid act),
        streak-days: (get streak-days act)
      })
      ERR_IDENTITY_NOT_FOUND)
  )
)

;; Get available rewards for user's point balance
(define-read-only (get-available-rewards (user principal))
  (let
    (
      (activity (map-get? user-activity { user: user }))
      (user-points (match activity
        act (get loyalty-points act)
        u0))
    )
    (ok (list
      (if (<= u100 user-points) (map-get? reward-catalog { reward-id: u1 }) none)
      (if (<= u250 user-points) (map-get? reward-catalog { reward-id: u2 }) none)
      (if (<= u500 user-points) (map-get? reward-catalog { reward-id: u3 }) none)
    ))
  )
)

;; Admin function to update reward rates
(define-public (update-reward-rates (new-base-rate uint) (new-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-base-rate u0) ERR_INVALID_AMOUNT)
    (asserts! (>= new-multiplier u100) ERR_INVALID_AMOUNT)
    
    (var-set base-reward-rate new-base-rate)
    (var-set loyalty-multiplier new-multiplier)
    (ok true)
  )
)

;; Get system statistics
(define-read-only (get-system-stats)
  (ok {
    total-rewards-issued: (var-get total-rewards-issued),
    base-reward-rate: (var-get base-reward-rate),
    loyalty-multiplier: (var-get loyalty-multiplier),
    total-redemptions: (var-get redemption-counter)
  })
)
