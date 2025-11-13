(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-goal-locked (err u104))
(define-constant err-goal-not-met (err u105))
(define-constant err-invalid-amount (err u106))

(define-constant err-milestone-already-claimed (err u108))
(define-constant err-milestone-not-reached (err u109))

(define-data-var pool-balance uint u0)
(define-data-var total-interest uint u0)
(define-data-var next-goal-id uint u1)

(define-map savings-goals
  { goal-id: uint }
  {
    owner: principal,
    target-amount: uint,
    current-amount: uint,
    creation-block: uint,
    lock-duration: uint,
    is-active: bool
  }
)

(define-map user-goals
  { user: principal }
  { goal-ids: (list 10 uint) }
)

(define-map pool-shares
  { user: principal }
  { shares: uint }
)

(define-private (calculate-interest (amount uint))
  (/ (* amount u5) u1000)
)

(define-private (distribute-interest (user principal) (amount uint))
  (let ((current-shares (default-to u0 (get shares (map-get? pool-shares { user: user })))))
    (map-set pool-shares 
      { user: user } 
      { shares: (+ current-shares amount) }
    )
  )
)

(define-public (create-savings-goal (target-amount uint) (lock-duration uint))
  (let 
    (
      (goal-id (var-get next-goal-id))
      (current-block burn-block-height)
    )
    (asserts! (> target-amount u0) err-invalid-amount)
    (asserts! (> lock-duration u0) err-invalid-amount)
    
    (map-set savings-goals
      { goal-id: goal-id }
      {
        owner: tx-sender,
        target-amount: target-amount,
        current-amount: u0,
        creation-block: current-block,
        lock-duration: lock-duration,
        is-active: true
      }
    )
    
    (let ((current-goals (default-to (list) (get goal-ids (map-get? user-goals { user: tx-sender })))))
      (map-set user-goals 
        { user: tx-sender } 
        { goal-ids: (unwrap! (as-max-len? (append current-goals goal-id) u10) err-invalid-amount) }
      )
    )
    
    (var-set next-goal-id (+ goal-id u1))
    (ok goal-id)
  )
)

(define-public (deposit-to-goal (goal-id uint) (amount uint))
  (let 
    (
      (goal (unwrap! (map-get? savings-goals { goal-id: goal-id }) err-not-found))
      (new-amount (+ (get current-amount goal) amount))
      (interest (calculate-interest amount))
    )
    (asserts! (is-eq tx-sender (get owner goal)) err-owner-only)
    (asserts! (get is-active goal) err-goal-locked)
    (asserts! (> amount u0) err-invalid-amount)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set savings-goals
      { goal-id: goal-id }
      (merge goal { current-amount: new-amount })
    )
    
    (var-set pool-balance (+ (var-get pool-balance) amount))
    (var-set total-interest (+ (var-get total-interest) interest))
    (distribute-interest tx-sender interest)
    
    (ok new-amount)
  )
)

(define-public (withdraw-from-goal (goal-id uint))
  (let 
    (
      (goal (unwrap! (map-get? savings-goals { goal-id: goal-id }) err-not-found))
      (current-block burn-block-height)
      (unlock-block (+ (get creation-block goal) (get lock-duration goal)))
      (is-goal-met (>= (get current-amount goal) (get target-amount goal)))
      (can-withdraw (or is-goal-met (>= current-block unlock-block)))
      (withdrawal-amount (get current-amount goal))
      (user-shares (default-to u0 (get shares (map-get? pool-shares { user: tx-sender }))))
      (interest-reward (if (> user-shares u0) (/ (* user-shares (var-get total-interest)) (var-get pool-balance)) u0))
    )
    (asserts! (is-eq tx-sender (get owner goal)) err-owner-only)
    (asserts! (get is-active goal) err-goal-locked)
    (asserts! can-withdraw err-goal-locked)
    (asserts! (> withdrawal-amount u0) err-insufficient-funds)
    
    (try! (as-contract (stx-transfer? withdrawal-amount tx-sender (get owner goal))))
    
    (if (> interest-reward u0)
      (try! (as-contract (stx-transfer? interest-reward tx-sender (get owner goal))))
      true
    )
    
    (map-set savings-goals
      { goal-id: goal-id }
      (merge goal { current-amount: u0, is-active: false })
    )
    
    (map-set pool-shares
      { user: tx-sender }
      { shares: u0 }
    )
    
    (var-set pool-balance (- (var-get pool-balance) withdrawal-amount))
    
    (ok { withdrawn: withdrawal-amount, interest: interest-reward })
  )
)

(define-public (add-pool-yield (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set total-interest (+ (var-get total-interest) amount))
    
    (ok amount)
  )
)

(define-read-only (get-goal (goal-id uint))
  (map-get? savings-goals { goal-id: goal-id })
)

(define-read-only (get-user-goals (user principal))
  (map-get? user-goals { user: user })
)

(define-read-only (get-user-shares (user principal))
  (map-get? pool-shares { user: user })
)

(define-read-only (get-pool-stats)
  {
    pool-balance: (var-get pool-balance),
    total-interest: (var-get total-interest),
    next-goal-id: (var-get next-goal-id)
  }
)

(define-read-only (get-goal-status (goal-id uint))
  (match (map-get? savings-goals { goal-id: goal-id })
    goal
    (let 
      (
        (current-block burn-block-height)
        (unlock-block (+ (get creation-block goal) (get lock-duration goal)))
        (progress (/ (* (get current-amount goal) u100) (get target-amount goal)))
      )
      (ok {
        progress: progress,
        unlocked: (>= current-block unlock-block)
      })
    )
    err-not-found
  )
)


(define-constant err-emergency-penalty-exceeds-balance (err u107))

(define-private (calculate-emergency-penalty 
  (goal-data { 
    owner: principal, 
    target-amount: uint, 
    current-amount: uint, 
    creation-block: uint, 
    lock-duration: uint, 
    is-active: bool 
  })
  (current-block-height uint))
  (let
    (
      (blocks-elapsed (- current-block-height (get creation-block goal-data)))
      (total-lock-blocks (get lock-duration goal-data))
      (time-progress (if (> total-lock-blocks u0) (/ (* blocks-elapsed u100) total-lock-blocks) u0))
      (penalty-rate (if (< time-progress u25) u20
                     (if (< time-progress u50) u15
                     (if (< time-progress u75) u10 u5))))
      (penalty-amount (/ (* (get current-amount goal-data) penalty-rate) u100))
    )
    { penalty: penalty-amount, rate: penalty-rate }
  )
)

(define-public (emergency-withdraw (goal-id uint))
  (let
    (
      (goal (unwrap! (map-get? savings-goals { goal-id: goal-id }) err-not-found))
      (current-block burn-block-height)
      (unlock-block (+ (get creation-block goal) (get lock-duration goal)))
      (is-locked (< current-block unlock-block))
      (is-goal-unmet (< (get current-amount goal) (get target-amount goal)))
      (requires-penalty (and is-locked is-goal-unmet))
      (penalty-data (calculate-emergency-penalty goal current-block))
      (penalty-amount (get penalty penalty-data))
      (withdrawal-amount (- (get current-amount goal) penalty-amount))
    )
    (asserts! (is-eq tx-sender (get owner goal)) err-owner-only)
    (asserts! (get is-active goal) err-goal-locked)
    (asserts! requires-penalty err-goal-locked)
    (asserts! (> (get current-amount goal) u0) err-insufficient-funds)
    (asserts! (>= (get current-amount goal) penalty-amount) err-emergency-penalty-exceeds-balance)
    
    (try! (as-contract (stx-transfer? withdrawal-amount tx-sender (get owner goal))))
    
    (var-set total-interest (+ (var-get total-interest) penalty-amount))
    (var-set pool-balance (- (var-get pool-balance) withdrawal-amount))
    
    (map-set savings-goals
      { goal-id: goal-id }
      (merge goal { current-amount: u0, is-active: false })
    )
    
    (ok { withdrawn: withdrawal-amount, penalty: penalty-amount, penalty-rate: (get rate penalty-data) })
  )
)

(define-read-only (preview-emergency-withdrawal (goal-id uint))
  (match (map-get? savings-goals { goal-id: goal-id })
    goal
    (let
      (
        (current-block burn-block-height)
        (penalty-data (calculate-emergency-penalty goal current-block))
        (penalty-amount (get penalty penalty-data))
        (net-withdrawal (- (get current-amount goal) penalty-amount))
      )
      (ok {
        current-balance: (get current-amount goal),
        penalty-amount: penalty-amount,
        penalty-rate: (get rate penalty-data),
        net-withdrawal: net-withdrawal
      })
    )
    err-not-found
  )
)

(define-map milestone-claims
  { goal-id: uint, milestone: uint }
  { claimed: bool }
)

(define-private (calculate-milestone-reward (target-amount uint) (milestone-level uint))
  (let
    (
      (base-reward (/ target-amount u100))
      (milestone-multiplier (if (is-eq milestone-level u25) u1
                            (if (is-eq milestone-level u50) u2
                            (if (is-eq milestone-level u75) u3 u0))))
    )
    (* base-reward milestone-multiplier)
  )
)

(define-private (get-milestone-percentage (current-amount uint) (target-amount uint))
  (if (is-eq target-amount u0)
    u0
    (/ (* current-amount u100) target-amount)
  )
)

(define-public (claim-milestone-reward (goal-id uint))
  (let
    (
      (goal (unwrap! (map-get? savings-goals { goal-id: goal-id }) err-not-found))
      (progress-pct (get-milestone-percentage (get current-amount goal) (get target-amount goal)))
      (milestone (if (>= progress-pct u75) u75
                 (if (>= progress-pct u50) u50
                 (if (>= progress-pct u25) u25 u0))))
      (already-claimed (default-to false (get claimed (map-get? milestone-claims { goal-id: goal-id, milestone: milestone }))))
      (reward-amount (calculate-milestone-reward (get target-amount goal) milestone))
      (available-interest (var-get total-interest))
    )
    (asserts! (is-eq tx-sender (get owner goal)) err-owner-only)
    (asserts! (get is-active goal) err-goal-locked)
    (asserts! (> milestone u0) err-milestone-not-reached)
    (asserts! (not already-claimed) err-milestone-already-claimed)
    (asserts! (>= available-interest reward-amount) err-insufficient-funds)
    
    (try! (as-contract (stx-transfer? reward-amount tx-sender (get owner goal))))
    
    (map-set milestone-claims
      { goal-id: goal-id, milestone: milestone }
      { claimed: true }
    )
    
    (var-set total-interest (- available-interest reward-amount))
    
    (ok { milestone: milestone, reward: reward-amount })
  )
)

(define-read-only (get-available-milestones (goal-id uint))
  (match (map-get? savings-goals { goal-id: goal-id })
    goal
    (let
      (
        (progress-pct (get-milestone-percentage (get current-amount goal) (get target-amount goal)))
        (milestone-25-claimed (default-to false (get claimed (map-get? milestone-claims { goal-id: goal-id, milestone: u25 }))))
        (milestone-50-claimed (default-to false (get claimed (map-get? milestone-claims { goal-id: goal-id, milestone: u50 }))))
        (milestone-75-claimed (default-to false (get claimed (map-get? milestone-claims { goal-id: goal-id, milestone: u75 }))))
      )
      (ok {
        progress: progress-pct,
        milestone-25-available: (and (>= progress-pct u25) (not milestone-25-claimed)),
        milestone-50-available: (and (>= progress-pct u50) (not milestone-50-claimed)),
        milestone-75-available: (and (>= progress-pct u75) (not milestone-75-claimed))
      })
    )
    err-not-found
  )
)