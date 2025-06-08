(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-MEMBER (err u101))
(define-constant ERR-ALREADY-MEMBER (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u105))
(define-constant ERR-ALREADY-VOTED (err u106))
(define-constant ERR-PROPOSAL-EXPIRED (err u107))

(define-data-var required-signatures uint u2)
(define-data-var proposal-duration uint u144)
(define-data-var total-members uint u0)

(define-map family-members
    principal
    bool
)
(define-map proposals
    uint
    {
        proposer: principal,
        recipient: principal,
        amount: uint,
        description: (string-ascii 50),
        signatures: uint,
        expires-at: uint,
        executed: bool,
    }
)

(define-map proposal-votes
    {
        proposal-id: uint,
        voter: principal,
    }
    bool
)
(define-data-var proposal-nonce uint u0)

(define-public (initialize
        (signatures uint)
        (duration uint)
    )
    (begin
        (asserts! (is-eq tx-sender contract-caller) ERR-NOT-AUTHORIZED)
        (var-set required-signatures signatures)
        (var-set proposal-duration duration)
        (map-set family-members tx-sender true)
        (var-set total-members u1)
        (ok true)
    )
)

(define-public (add-family-member (new-member principal))
    (begin
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-member new-member)) ERR-ALREADY-MEMBER)
        (map-set family-members new-member true)
        (var-set total-members (+ (var-get total-members) u1))
        (ok true)
    )
)

(define-public (remove-family-member (member principal))
    (begin
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-member member) ERR-INVALID-MEMBER)
        (map-delete family-members member)
        (var-set total-members (- (var-get total-members) u1))
        (ok true)
    )
)

(define-public (create-proposal
        (recipient principal)
        (amount uint)
        (description (string-ascii 50))
    )
    (let (
            (proposal-id (var-get proposal-nonce))
            (expires-at (+ burn-block-height (var-get proposal-duration)))
        )
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (map-set proposals proposal-id {
            proposer: tx-sender,
            recipient: recipient,
            amount: amount,
            description: description,
            signatures: u0,
            expires-at: expires-at,
            executed: false,
        })
        (var-set proposal-nonce (+ proposal-id u1))
        (ok proposal-id)
    )
)

(define-public (vote-on-proposal (proposal-id uint))
    (let (
            (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (has-voted (default-to false
                (map-get? proposal-votes {
                    proposal-id: proposal-id,
                    voter: tx-sender,
                })
            ))
        )
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (not has-voted) ERR-ALREADY-VOTED)
        (asserts! (< burn-block-height (get expires-at proposal))
            ERR-PROPOSAL-EXPIRED
        )
        (asserts! (not (get executed proposal)) ERR-PROPOSAL-EXPIRED)
        (map-set proposal-votes {
            proposal-id: proposal-id,
            voter: tx-sender,
        }
            true
        )
        (map-set proposals proposal-id
            (merge proposal { signatures: (+ (get signatures proposal) u1) })
        )
        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND)))
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (>= (get signatures proposal) (var-get required-signatures))
            ERR-NOT-AUTHORIZED
        )
        (asserts! (< burn-block-height (get expires-at proposal))
            ERR-PROPOSAL-EXPIRED
        )
        (asserts! (not (get executed proposal)) ERR-PROPOSAL-EXPIRED)
        (try! (stx-transfer? (get amount proposal) tx-sender (get recipient proposal)))
        (map-set proposals proposal-id (merge proposal { executed: true }))
        (ok true)
    )
)

(define-read-only (is-member (account principal))
    (default-to false (map-get? family-members account))
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-member-count)
    (var-get total-members)
)
