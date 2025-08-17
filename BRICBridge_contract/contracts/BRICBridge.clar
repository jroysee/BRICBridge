
;; title: BRICBridge - Synthetic Assets for BRIC Countries Composite Exposure
;; version: 1.0.0
;; summary: A smart contract that creates synthetic exposure to traditional assets from BRIC countries
;; description: BRICBridge enables users to mint synthetic assets backed by STX collateral,
;;              providing exposure to a composite of traditional assets from Brazil, Russia, India, and China

;; traits
;; SIP-010 compliance is built into the fungible token definition

;; token definitions
;; Define the synthetic BRIC token
(define-fungible-token syn-bric)

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_POSITION_NOT_FOUND (err u104))
(define-constant ERR_LIQUIDATION_THRESHOLD_NOT_MET (err u105))
(define-constant ERR_ORACLE_ERROR (err u106))

;; Collateralization ratio (150% = 15000 basis points)
(define-constant COLLATERAL_RATIO u15000)
(define-constant BASIS_POINTS u10000)
(define-constant LIQUIDATION_THRESHOLD u12000) ;; 120%
(define-constant LIQUIDATION_PENALTY u500) ;; 5%

;; BRIC composite price (mock oracle price in micro-STX per unit)
(define-constant INITIAL_BRIC_PRICE u100000000) ;; 100 STX per BRIC unit

;; data vars
(define-data-var contract-paused bool false)
(define-data-var total-collateral uint u0)
(define-data-var total-synthetic-supply uint u0)
(define-data-var bric-price uint INITIAL_BRIC_PRICE)
(define-data-var next-position-id uint u1)

;; data maps
;; User positions: collateral amount and synthetic tokens minted
(define-map user-positions 
    { user: principal, position-id: uint }
    { 
        collateral-amount: uint,
        synthetic-amount: uint,
        created-at: uint
    })

;; User position count
(define-map user-position-count principal uint)

;; Authorized oracles for price updates
(define-map authorized-oracles principal bool)

;; public functions

;; Initialize contract (only contract owner)
(define-public (initialize)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-oracles CONTRACT_OWNER true)
        (ok true)))

;; Mint synthetic BRIC tokens by depositing STX collateral
(define-public (mint-synthetic (collateral-amount uint))
    (let (
        (position-id (var-get next-position-id))
        (current-bric-price (var-get bric-price))
        (max-synthetic-amount (/ (* collateral-amount BASIS_POINTS) 
                                (* current-bric-price COLLATERAL_RATIO)))
        (synthetic-amount (* max-synthetic-amount BASIS_POINTS))
        (user-positions-count (default-to u0 (map-get? user-position-count tx-sender)))
    )
        ;; Validate inputs
        (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
        (asserts! (> collateral-amount u0) ERR_INVALID_AMOUNT)
        (asserts! (> synthetic-amount u0) ERR_INVALID_AMOUNT)
        
        ;; Transfer STX collateral from user to contract
        (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
        
        ;; Mint synthetic tokens to user
        (try! (ft-mint? syn-bric synthetic-amount tx-sender))
        
        ;; Update position
        (map-set user-positions
            { user: tx-sender, position-id: position-id }
            {
                collateral-amount: collateral-amount,
                synthetic-amount: synthetic-amount,
                created-at: block-height
            })
        
        ;; Update user position count
        (map-set user-position-count tx-sender (+ user-positions-count u1))
        
        ;; Update global state
        (var-set total-collateral (+ (var-get total-collateral) collateral-amount))
        (var-set total-synthetic-supply (+ (var-get total-synthetic-supply) synthetic-amount))
        (var-set next-position-id (+ position-id u1))
        
        (ok position-id)))

;; Burn synthetic tokens and withdraw collateral
(define-public (burn-synthetic (position-id uint))
    (let (
        (position (unwrap! (map-get? user-positions { user: tx-sender, position-id: position-id }) ERR_POSITION_NOT_FOUND))
        (collateral-amount (get collateral-amount position))
        (synthetic-amount (get synthetic-amount position))
    )
        ;; Validate position exists and user has sufficient synthetic tokens
        (asserts! (>= (ft-get-balance syn-bric tx-sender) synthetic-amount) ERR_INSUFFICIENT_BALANCE)
        
        ;; Burn synthetic tokens
        (try! (ft-burn? syn-bric synthetic-amount tx-sender))
        
        ;; Transfer collateral back to user
        (try! (as-contract (stx-transfer? collateral-amount tx-sender tx-sender)))
        
        ;; Remove position
        (map-delete user-positions { user: tx-sender, position-id: position-id })
        
        ;; Update global state
        (var-set total-collateral (- (var-get total-collateral) collateral-amount))
        (var-set total-synthetic-supply (- (var-get total-synthetic-supply) synthetic-amount))
        
        (ok true)))

;; Liquidate undercollateralized position
(define-public (liquidate-position (user principal) (position-id uint))
    (let (
        (position (unwrap! (map-get? user-positions { user: user, position-id: position-id }) ERR_POSITION_NOT_FOUND))
        (collateral-amount (get collateral-amount position))
        (synthetic-amount (get synthetic-amount position))
        (current-bric-price (var-get bric-price))
        (collateral-value (* collateral-amount BASIS_POINTS))
        (debt-value (* synthetic-amount current-bric-price))
        (collateral-ratio-current (/ (* collateral-value BASIS_POINTS) debt-value))
        (penalty-amount (/ (* collateral-amount LIQUIDATION_PENALTY) BASIS_POINTS))
        (liquidator-reward penalty-amount)
        (remaining-collateral (- collateral-amount penalty-amount))
    )
        ;; Check if position is undercollateralized
        (asserts! (< collateral-ratio-current LIQUIDATION_THRESHOLD) ERR_LIQUIDATION_THRESHOLD_NOT_MET)
        
        ;; Liquidator must have sufficient synthetic tokens to burn
        (asserts! (>= (ft-get-balance syn-bric tx-sender) synthetic-amount) ERR_INSUFFICIENT_BALANCE)
        
        ;; Burn liquidator's synthetic tokens
        (try! (ft-burn? syn-bric synthetic-amount tx-sender))
        
        ;; Transfer liquidator reward
        (try! (as-contract (stx-transfer? liquidator-reward tx-sender tx-sender)))
        
        ;; Transfer remaining collateral to original user
        (try! (as-contract (stx-transfer? remaining-collateral tx-sender user)))
        
        ;; Remove position
        (map-delete user-positions { user: user, position-id: position-id })
        
        ;; Update global state
        (var-set total-collateral (- (var-get total-collateral) collateral-amount))
        (var-set total-synthetic-supply (- (var-get total-synthetic-supply) synthetic-amount))
        
        (ok true)))

;; Update BRIC price (oracle function)
(define-public (update-bric-price (new-price uint))
    (begin
        (asserts! (default-to false (map-get? authorized-oracles tx-sender)) ERR_UNAUTHORIZED)
        (asserts! (> new-price u0) ERR_INVALID_AMOUNT)
        (var-set bric-price new-price)
        (ok true)))

;; Add authorized oracle (contract owner only)
(define-public (add-oracle (oracle principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-oracles oracle true)
        (ok true)))

;; Remove authorized oracle (contract owner only)
(define-public (remove-oracle (oracle principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-delete authorized-oracles oracle)
        (ok true)))

;; Pause/unpause contract (contract owner only)
(define-public (set-contract-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set contract-paused paused)
        (ok true)))

;; read only functions

;; Get synthetic token name
(define-read-only (get-name)
    (ok "Synthetic BRIC"))

;; Get synthetic token symbol
(define-read-only (get-symbol)
    (ok "SYN-BRIC"))

;; Get synthetic token decimals
(define-read-only (get-decimals)
    (ok u6))

;; Get total supply of synthetic tokens
(define-read-only (get-total-supply)
    (ok (ft-get-supply syn-bric)))

;; Get user's synthetic token balance
(define-read-only (get-balance (user principal))
    (ok (ft-get-balance syn-bric user)))

;; Get user position details
(define-read-only (get-position (user principal) (position-id uint))
    (map-get? user-positions { user: user, position-id: position-id }))

;; Get current BRIC price
(define-read-only (get-bric-price)
    (var-get bric-price))

;; Get total collateral locked
(define-read-only (get-total-collateral)
    (var-get total-collateral))

;; Get total synthetic supply
(define-read-only (get-total-synthetic-supply)
    (var-get total-synthetic-supply))

;; Calculate collateral ratio for a position
(define-read-only (get-collateral-ratio (user principal) (position-id uint))
    (match (map-get? user-positions { user: user, position-id: position-id })
        position
        (let (
            (collateral-amount (get collateral-amount position))
            (synthetic-amount (get synthetic-amount position))
            (current-bric-price (var-get bric-price))
            (collateral-value (* collateral-amount BASIS_POINTS))
            (debt-value (* synthetic-amount current-bric-price))
        )
            (ok (/ (* collateral-value BASIS_POINTS) debt-value)))
        ERR_POSITION_NOT_FOUND))

;; Check if position is liquidatable
(define-read-only (is-position-liquidatable (user principal) (position-id uint))
    (match (get-collateral-ratio user position-id)
        ratio (ok (< ratio LIQUIDATION_THRESHOLD))
        error (err error)))

;; Get user's position count
(define-read-only (get-user-position-count (user principal))
    (default-to u0 (map-get? user-position-count user)))

;; Check if oracle is authorized
(define-read-only (is-authorized-oracle (oracle principal))
    (default-to false (map-get? authorized-oracles oracle)))

;; Check if contract is paused
(define-read-only (is-contract-paused)
    (var-get contract-paused))

;; Get contract owner
(define-read-only (get-contract-owner)
    CONTRACT_OWNER)

;; private functions

;; Transfer function for SIP-010 compliance
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) ERR_UNAUTHORIZED)
        (ft-transfer? syn-bric amount sender recipient)))

