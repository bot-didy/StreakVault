;; StreakVault - monthly (configurable) check-ins + streak rewards
;; Fund this contract with STX before calling (claim).
;; Built for Code4STX: time logic, state, payouts, admin config.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Errors
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-TOO-SOON       (err u101))
(define-constant ERR-NO-STREAK      (err u102))
(define-constant ERR-ALREADY-CLAIM  (err u103))
(define-constant ERR-NO-FUNDS       (err u104))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Config
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-data-var admin               principal tx-sender)
;; Approx "monthly" period as block windows. Tune for devnet/testnet/mainnet.
(define-data-var period-length       uint u52560)        ;; ~ 1 month in blocks (example)
(define-data-var min-streak-to-claim uint u3)            ;; must have >= this streak to claim
(define-data-var reward-per-claim    uint u1000000)      ;; 1_000_000 micro-STX = 1 STX (example)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; State
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Last check-in block for each user
(define-map last-checkin
  { user: principal }
  { height: uint })

;; User's running streak count
(define-map user-streak
  { user: principal }
  { count: uint })

;; Tracks whether a user has claimed in a given period-id
(define-map has-claimed
  { user: principal, period: uint }
  { claimed: bool })

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Views
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-read-only (get-config)
  { admin: (var-get admin),
    period-length: (var-get period-length),
    min-streak: (var-get min-streak-to-claim),
    reward-per-claim: (var-get reward-per-claim) })

(define-read-only (get-user (user principal))
  (let ((lc (default-to u0 (get height (map-get? last-checkin { user: user }))))
        (st (default-to u0 (get count  (map-get? user-streak  { user: user })))))
    { last-checkin: lc, streak: st }))

;; Deterministic "period id" based on the current block and period length.
(define-read-only (current-period)
  (/ stacks-block-height (var-get period-length)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Admin
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-private (only-admin)
  (is-eq tx-sender (var-get admin)))

(define-public (set-config (new-period uint) (new-min-streak uint) (new-reward uint))
  (begin
    (asserts! (only-admin) ERR-NOT-AUTHORIZED)
    (var-set period-length       new-period)
    (var-set min-streak-to-claim new-min-streak)
    (var-set reward-per-claim    new-reward)
    (ok true)))

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (only-admin) ERR-NOT-AUTHORIZED)
    (var-set admin new-admin)
    (ok true)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Core
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Users can check in once per "period-length" blocks.
(define-public (check-in)
  (let ((last (default-to u0 (get height (map-get? last-checkin { user: tx-sender }))))
        (now  stacks-block-height)
        (span (var-get period-length)))
    (if (>= (- now last) span)
        (begin
          (map-set last-checkin { user: tx-sender } { height: now })
          (let ((prev (default-to u0 (get count (map-get? user-streak { user: tx-sender }))))) 
            (map-set user-streak { user: tx-sender } { count: (+ prev u1) })
            (ok (+ prev u1))))
        ERR-TOO-SOON)))

;; Claim once per period if your streak >= min-streak-to-claim.
(define-public (claim)
  (let (
        (streak   (default-to u0 (get count (map-get? user-streak { user: tx-sender }))))
        (min-s    (var-get min-streak-to-claim))
        (periodId (current-period))
        (reward   (var-get reward-per-claim))
        (contract-principal (as-contract tx-sender))
       )
    (begin
      (asserts! (>= streak min-s) ERR-NO-STREAK)
      (asserts! (is-none (map-get? has-claimed { user: tx-sender, period: periodId })) ERR-ALREADY-CLAIM)
      ;; ensure contract has enough to pay
      (asserts! (>= (stx-get-balance contract-principal) reward) ERR-NO-FUNDS)
      (map-set has-claimed { user: tx-sender, period: periodId } { claimed: true })
      (stx-transfer? reward contract-principal tx-sender))))
