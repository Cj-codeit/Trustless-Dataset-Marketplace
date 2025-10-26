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

;; Public functions
;; #[allow(unchecked_data)]
(define-public (create-listing 
  (title (string-ascii 100))
  (description (string-ascii 200))
  (price uint)
  (dataset-hash (buff 32))
  (category (string-ascii 50))
)
  (let
    (
      (new-listing-id (+ (var-get listing-count) u1))
    )
    (map-set listings new-listing-id
      {
        seller: tx-sender,
        title: title,
        description: description,
        price: price,
        dataset-hash: dataset-hash,
        active: true,
        created-at: stacks-block-height
      }
    )
    (map-set dataset-categories new-listing-id category)
    (var-set listing-count new-listing-id)
    (ok new-listing-id)
  )
)

(define-public (update-listing-price (listing-id uint) (new-price uint))
  (let
    (
      (listing (unwrap! (map-get? listings listing-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get seller listing)) err-unauthorized)
    (asserts! (get active listing) err-invalid-state)
    (ok (map-set listings listing-id
      (merge listing {price: new-price})
    ))
  )
)

(define-public (deactivate-listing (listing-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings listing-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get seller listing)) err-unauthorized)
    (ok (map-set listings listing-id
      (merge listing {active: false})
    ))
  )
)

(define-public (reactivate-listing (listing-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings listing-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get seller listing)) err-unauthorized)
    (ok (map-set listings listing-id
      (merge listing {active: true})
    ))
  )
)

;; #[allow(unchecked_data)]
(define-public (toggle-favorite (listing-id uint))
  (let
    (
      (current-status (default-to false (map-get? favorites {user: tx-sender, listing-id: listing-id})))
    )
    (ok (map-set favorites {user: tx-sender, listing-id: listing-id} (not current-status)))
  )
)

(define-public (purchase-dataset (listing-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings listing-id) err-not-found))
      (price (get price listing))
      (seller (get seller listing))
      (new-sale-id (+ (var-get sale-count) u1))
    )
    (asserts! (get active listing) err-invalid-state)
    (asserts! (not (is-eq tx-sender seller)) err-unauthorized)
    (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
    (map-set sales new-sale-id
      {
        listing-id: listing-id,
        buyer: tx-sender,
        seller: seller,
        price: price,
        delivered: false,
        accepted: false,
        disputed: false,
        purchased-at: stacks-block-height
      }
    )
    (map-set escrow {sale-id: new-sale-id} price)
    (var-set sale-count new-sale-id)
    (var-set total-volume (+ (var-get total-volume) price))
    (ok new-sale-id)
  )
)

(define-public (confirm-delivery (sale-id uint))
  (let
    (
      (sale (unwrap! (map-get? sales sale-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get buyer sale)) err-unauthorized)
    (asserts! (not (get accepted sale)) err-invalid-state)
    (asserts! (not (get disputed sale)) err-invalid-state)
    (try! (release-escrow sale-id))
    (ok (map-set sales sale-id
      (merge sale {accepted: true, delivered: true})
    ))
  )
)

;; #[allow(unchecked_data)]
(define-public (add-review (sale-id uint) (rating uint) (comment (string-ascii 200)))
  (let
    (
      (sale (unwrap! (map-get? sales sale-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get buyer sale)) err-unauthorized)
    (asserts! (get accepted sale) err-invalid-state)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-state)
    
    (map-set reviews {sale-id: sale-id}
      {
        rating: rating,
        comment: comment,
        timestamp: stacks-block-height
      }
    )
    (update-seller-rating (get seller sale) rating)
  )
)

;; Private functions
(define-private (release-escrow (sale-id uint))
  (let
    (
      (sale (unwrap! (map-get? sales sale-id) err-not-found))
      (escrow-amount (unwrap! (get-escrow-amount sale-id) err-not-found))
      (platform-fee (unwrap! (calculate-platform-fee escrow-amount) err-invalid-state))
      (seller-payout (- escrow-amount platform-fee))
    )
    (try! (as-contract (stx-transfer? seller-payout tx-sender (get seller sale))))
    (var-set platform-revenue (+ (var-get platform-revenue) platform-fee))
    (map-delete escrow {sale-id: sale-id})
    (ok true)
  )
)

(define-private (update-seller-rating (seller principal) (new-rating uint))
  (let
    (
      (current-rating (default-to {total-sales: u0, rating-sum: u0} (map-get? seller-ratings seller)))
      (new-total (+ (get total-sales current-rating) u1))
      (new-sum (+ (get rating-sum current-rating) new-rating))
    )
    (ok (map-set seller-ratings seller
      {
        total-sales: new-total,
        rating-sum: new-sum
      }
    ))
  )
)

(define-public (dispute-sale (sale-id uint))
  (let
    (
      (sale (unwrap! (map-get? sales sale-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get buyer sale)) err-unauthorized)
    (asserts! (not (get accepted sale)) err-invalid-state)
    (asserts! (not (get disputed sale)) err-invalid-state)
    (var-set dispute-count (+ (var-get dispute-count) u1))
    (ok (map-set sales sale-id
      (merge sale {disputed: true})
    ))
  )
)

;; #[allow(unchecked_data)]
(define-public (resolve-dispute (sale-id uint) (refund-percent uint) (decision (string-ascii 200)))
  (let
    (
      (sale (unwrap! (map-get? sales sale-id) err-not-found))
      (escrow-amount (unwrap! (get-escrow-amount sale-id) err-not-found))
      (refund-amount (/ (* escrow-amount refund-percent) u100))
      (seller-amount (- escrow-amount refund-amount))
      (dispute-id (var-get dispute-count))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get disputed sale) err-invalid-state)
    (asserts! (<= refund-percent u100) err-invalid-state)
    
    (if (> refund-amount u0)
      (try! (as-contract (stx-transfer? refund-amount tx-sender (get buyer sale))))
      true
    )
    
    (if (> seller-amount u0)
      (try! (as-contract (stx-transfer? seller-amount tx-sender (get seller sale))))
      true
    )
    
    (map-delete escrow {sale-id: sale-id})
    (map-set dispute-resolutions dispute-id
      {
        sale-id: sale-id,
        resolver: tx-sender,
        decision: decision,
        refund-percent: refund-percent,
        resolved-at: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u20) err-invalid-state) ;; Max 20% fee
    (ok (var-set platform-fee-percent new-fee))
  )
)

(define-public (withdraw-platform-revenue (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= amount (var-get platform-revenue)) err-insufficient-funds)
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    (ok (var-set platform-revenue (- (var-get platform-revenue) amount)))
  )
)