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