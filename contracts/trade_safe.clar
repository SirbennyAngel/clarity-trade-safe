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

;; Data variables
(define-data-var platform-fee uint u10) ;; 1% fee in basis points

;; Trade status enumeration  
(define-constant TRADE_STATUS_PENDING u0)
(define-constant TRADE_STATUS_CONFIRMED u1)
(define-constant TRADE_STATUS_DISPUTED u2)
(define-constant TRADE_STATUS_COMPLETED u3)
(define-constant TRADE_STATUS_CANCELLED u4)

;; Rating enumeration
(define-constant RATING_POSITIVE u1)
(define-constant RATING_NEGATIVE u0)

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
        description: (string-utf8 256),
        buyer-rating: (optional uint),
        seller-rating: (optional uint),
        rating-comment: (optional (string-utf8 256))
    }
)

;; User ratings data structure
(define-map user-ratings
    { user: principal }
    {
        positive-ratings: uint,
        negative-ratings: uint,
        total-trades: uint
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
                description: description,
                buyer-rating: none,
                seller-rating: none,
                rating-comment: none
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

;; Submit rating
(define-public (submit-rating (trade-id uint) (rating uint) (comment (string-utf8 256)))
    (let
        ((trade (unwrap! (map-get? trades {trade-id: trade-id}) err-invalid-trade)))
        
        ;; Verify trade is completed
        (asserts! (is-eq (get status trade) TRADE_STATUS_COMPLETED) err-invalid-state)
        
        ;; Check if caller is buyer or seller
        (asserts! (or (is-eq tx-sender (get buyer trade)) 
                    (is-eq tx-sender (get seller trade))) 
                err-unauthorized)
        
        ;; Check if rating already submitted
        (asserts! (if (is-eq tx-sender (get buyer trade))
                    (is-none (get buyer-rating trade))
                    (is-none (get seller-rating trade)))
                err-already-rated)
        
        ;; Update trade ratings
        (map-set trades
            {trade-id: trade-id}
            (merge trade 
                (if (is-eq tx-sender (get buyer trade))
                    {
                        buyer-rating: (some rating),
                        rating-comment: (some comment)
                    }
                    {
                        seller-rating: (some rating),
                        rating-comment: (some comment)
                    }
                )
            )
        )
        
        ;; Update user rating stats
        (let ((rated-user (if (is-eq tx-sender (get buyer trade))
                            (get seller trade)
                            (get buyer trade))))
            
            (match (map-get? user-ratings {user: rated-user})
                existing-rating
                (map-set user-ratings
                    {user: rated-user}
                    {
                        positive-ratings: (+ (default-to u0 (get positive-ratings existing-rating))
                                          (if (is-eq rating RATING_POSITIVE) u1 u0)),
                        negative-ratings: (+ (default-to u0 (get negative-ratings existing-rating))
                                          (if (is-eq rating RATING_NEGATIVE) u1 u0)),
                        total-trades: (+ (default-to u0 (get total-trades existing-rating)) u1)
                    }
                )
                (map-insert user-ratings
                    {user: rated-user}
                    {
                        positive-ratings: (if (is-eq rating RATING_POSITIVE) u1 u0),
                        negative-ratings: (if (is-eq rating RATING_NEGATIVE) u1 u0),
                        total-trades: u1
                    }
                )
            )
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

;; Get user rating
(define-read-only (get-user-rating (user principal))
    (ok (map-get? user-ratings {user: user}))
)

;; Existing functions remain unchanged...
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

(define-read-only (get-trade (trade-id uint))
    (ok (map-get? trades {trade-id: trade-id}))
)

(define-read-only (get-platform-fee)
    (ok (var-get platform-fee))
)
