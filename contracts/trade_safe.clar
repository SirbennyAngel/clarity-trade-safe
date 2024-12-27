;; TradeSafe - A trade assurance platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-trade (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-invalid-state (err u105))

;; Data variables
(define-data-var platform-fee uint u10) ;; 1% fee in basis points

;; Trade status enumeration
(define-constant TRADE_STATUS_PENDING u0)
(define-constant TRADE_STATUS_CONFIRMED u1)
(define-constant TRADE_STATUS_DISPUTED u2)
(define-constant TRADE_STATUS_COMPLETED u3)
(define-constant TRADE_STATUS_CANCELLED u4)

;; Trade data structure
(define-map trades
    { trade-id: uint }
    {
        buyer: principal,
        seller: principal,
        amount: uint,
        status: uint,
        created-at: uint,
        timeout: uint,
        description: (string-utf8 256)
    }
)

;; Counter for trade IDs
(define-data-var trade-nonce uint u0)

;; Public functions

;; Create new trade
(define-public (create-trade (seller principal) (amount uint) (timeout uint) (description (string-utf8 256)))
    (let
        (
            (trade-id (+ (var-get trade-nonce) u1))
            (current-time block-height)
        )
        (asserts! (>= (stx-get-balance tx-sender) amount) err-insufficient-funds)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-insert trades
            { trade-id: trade-id }
            {
                buyer: tx-sender,
                seller: seller,
                amount: amount,
                status: TRADE_STATUS_PENDING,
                created-at: current-time,
                timeout: (+ current-time timeout),
                description: description
            }
        )
        (var-set trade-nonce trade-id)
        (ok trade-id)
    )
)

;; Confirm delivery
(define-public (confirm-delivery (trade-id uint))
    (let
        ((trade (unwrap! (map-get? trades {trade-id: trade-id}) err-invalid-trade)))
        (asserts! (is-eq (get buyer trade) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status trade) TRADE_STATUS_PENDING) err-invalid-state)
        (try! (release-funds trade-id))
        (map-set trades
            {trade-id: trade-id}
            (merge trade {status: TRADE_STATUS_COMPLETED})
        )
        (ok true)
    )
)

;; Release funds
(define-private (release-funds (trade-id uint))
    (let
        (
            (trade (unwrap! (map-get? trades {trade-id: trade-id}) err-invalid-trade))
            (fee-amount (/ (* (get amount trade) (var-get platform-fee)) u1000))
            (seller-amount (- (get amount trade) fee-amount))
        )
        (try! (as-contract (stx-transfer? seller-amount tx-sender (get seller trade))))
        (try! (as-contract (stx-transfer? fee-amount tx-sender contract-owner)))
        (ok true)
    )
)

;; Dispute trade
(define-public (dispute-trade (trade-id uint))
    (let
        ((trade (unwrap! (map-get? trades {trade-id: trade-id}) err-invalid-trade)))
        (asserts! (or (is-eq (get buyer trade) tx-sender) (is-eq (get seller trade) tx-sender)) err-unauthorized)
        (asserts! (is-eq (get status trade) TRADE_STATUS_PENDING) err-invalid-state)
        (map-set trades
            {trade-id: trade-id}
            (merge trade {status: TRADE_STATUS_DISPUTED})
        )
        (ok true)
    )
)

;; Cancel trade
(define-public (cancel-trade (trade-id uint))
    (let
        ((trade (unwrap! (map-get? trades {trade-id: trade-id}) err-invalid-trade)))
        (asserts! (is-eq (get buyer trade) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status trade) TRADE_STATUS_PENDING) err-invalid-state)
        (try! (as-contract (stx-transfer? (get amount trade) tx-sender tx-sender)))
        (map-set trades
            {trade-id: trade-id}
            (merge trade {status: TRADE_STATUS_CANCELLED})
        )
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-trade (trade-id uint))
    (ok (map-get? trades {trade-id: trade-id}))
)

(define-read-only (get-platform-fee)
    (ok (var-get platform-fee))
)