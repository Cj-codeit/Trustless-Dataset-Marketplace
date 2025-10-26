;; Trustless Dataset Marketplace
;; Peer-to-peer marketplace for trading curated datasets

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u500))
(define-constant err-not-found (err u501))
(define-constant err-insufficient-funds (err u502))
(define-constant err-unauthorized (err u503))
(define-constant err-invalid-state (err u504))
(define-constant err-already-purchased (err u505))

;; Data Variables
(define-data-var listing-count uint u0)
(define-data-var sale-count uint u0)
(define-data-var platform-fee-percent uint u5) ;; 5% platform fee
(define-data-var total-volume uint u0)
(define-data-var platform-revenue uint u0)
(define-data-var dispute-count uint u0)

;; Data Maps
(define-map listings uint
  {
    seller: principal,
    title: (string-ascii 100),
    description: (string-ascii 200),
    price: uint,
    dataset-hash: (buff 32),
    active: bool,
    created-at: uint
  }
)

(define-map sales uint
  {
    listing-id: uint,
    buyer: principal,
    seller: principal,
    price: uint,
    delivered: bool,
    accepted: bool,
    disputed: bool,
    purchased-at: uint
  }
)

(define-map escrow {sale-id: uint} uint)

(define-map seller-ratings principal
  {
    total-sales: uint,
    rating-sum: uint
  }
)

;; Additional Data Maps
(define-map buyer-purchases principal (list 100 uint))
(define-map seller-listings principal (list 100 uint))
(define-map dataset-categories uint (string-ascii 50))
(define-map favorites {user: principal, listing-id: uint} bool)
(define-map reviews {sale-id: uint}
  {
    rating: uint,
    comment: (string-ascii 200),
    timestamp: uint
  }
)

(define-map dispute-resolutions uint
  {
    sale-id: uint,
    resolver: principal,
    decision: (string-ascii 200),
    refund-percent: uint,
    resolved-at: uint
  }
)

;; Read-only functions
(define-read-only (get-listing (listing-id uint))
  (map-get? listings listing-id)
)

(define-read-only (get-sale (sale-id uint))
  (map-get? sales sale-id)
)

(define-read-only (get-listing-count)
  (ok (var-get listing-count))
)

(define-read-only (get-sale-count)
  (ok (var-get sale-count))
)

(define-read-only (get-seller-rating (seller principal))
  (match (map-get? seller-ratings seller)
    rating-data 
      (let 
        (
          (total-sales (get total-sales rating-data))
          (rating-sum (get rating-sum rating-data))
        )
        (if (> total-sales u0)
          (ok (/ rating-sum total-sales))
          (ok u0)
        )
      )
    (ok u0)
  )
)

(define-read-only (get-escrow-amount (sale-id uint))
  (ok (default-to u0 (map-get? escrow {sale-id: sale-id})))
)

(define-read-only (get-platform-fee-percent)
  (ok (var-get platform-fee-percent))
)

(define-read-only (get-total-volume)
  (ok (var-get total-volume))
)

(define-read-only (get-platform-revenue)
  (ok (var-get platform-revenue))
)

(define-read-only (is-favorite (user principal) (listing-id uint))
  (ok (default-to false (map-get? favorites {user: user, listing-id: listing-id})))
)

(define-read-only (get-review (sale-id uint))
  (ok (map-get? reviews {sale-id: sale-id}))
)

(define-read-only (get-category (listing-id uint))
  (ok (map-get? dataset-categories listing-id))
)

(define-read-only (calculate-platform-fee (price uint))
  (ok (/ (* price (var-get platform-fee-percent)) u100))
)

(define-read-only (calculate-seller-payout (price uint))
  (let
    (
      (fee (unwrap-panic (calculate-platform-fee price)))
    )
    (ok (- price fee))
  )
)