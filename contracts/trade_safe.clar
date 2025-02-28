;; TradeSafe - A trade assurance platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-trade (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-invalid-state (err u105))
(define-constant err-already-rated (err u106))
(define-constant err-timeout (err u107))

;; [Previous constants remain unchanged...]

;; Confirm delivery
(define-public (confirm-delivery (trade-id uint))
    (let
        ((trade (unwrap! (map-get? trades {trade-id: trade-id}) err-invalid-trade)))
        (asserts! (is-eq (get buyer trade) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status trade) TRADE_STATUS_PENDING) err-invalid-state)
        (asserts! (<= block-height (get timeout trade)) err-timeout)
        (try! (release-funds trade-id))
        (map-set trades
            {trade-id: trade-id}
            (merge trade {status: TRADE_STATUS_COMPLETED})
        )
        (ok true)
    )
)

;; Handle expired trade
(define-public (recover-expired-trade (trade-id uint))
    (let
        ((trade (unwrap! (map-get? trades {trade-id: trade-id}) err-invalid-trade)))
        (asserts! (is-eq (get buyer trade) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status trade) TRADE_STATUS_PENDING) err-invalid-state)
        (asserts! (> block-height (get timeout trade)) err-invalid-state)
        (try! (as-contract (stx-transfer? (get amount trade) tx-sender tx-sender)))
        (map-set trades
            {trade-id: trade-id}
            (merge trade {status: TRADE_STATUS_CANCELLED})
        )
        (ok true)
    )
)

;; [Rest of the contract remains unchanged...]
