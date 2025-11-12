(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-MEMBER (err u101))
(define-constant ERR-ALREADY-MEMBER (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u105))
(define-constant ERR-ALREADY-VOTED (err u106))
(define-constant ERR-PROPOSAL-EXPIRED (err u107))
(define-constant ERR-ALLOWANCE-NOT-FOUND (err u108))
(define-constant ERR-ALLOWANCE-NOT-READY (err u109))
(define-constant ERR-ALLOWANCE-ALREADY-EXISTS (err u110))
(define-constant ERR-CATEGORY-NOT-FOUND (err u111))
(define-constant ERR-BUDGET-EXCEEDED (err u112))
(define-constant ERR-CATEGORY-ALREADY-EXISTS (err u113))
(define-constant ERR-EXPENSE-NOT-FOUND (err u114))

(define-data-var required-signatures uint u2)
(define-data-var proposal-duration uint u144)
(define-data-var total-members uint u0)
(define-data-var expense-nonce uint u0)

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
        category: (string-ascii 20),
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

(define-map budget-categories
    (string-ascii 20)
    {
        limit: uint,
        spent: uint,
        created-by: principal,
    }
)

(define-map recurring-allowances
    principal
    {
        amount: uint,
        period-blocks: uint,
        last-claimed: uint,
        created-by: principal,
        signatures: uint,
        approved: bool,
    }
)

(define-map allowance-votes
    {
        beneficiary: principal,
        voter: principal,
    }
    bool
)

(define-map expense-records
    uint
    {
        spender: principal,
        amount: uint,
        category: (string-ascii 20),
        description: (string-ascii 50),
        timestamp: uint,
        approved-by: principal,
    }
)

(define-map monthly-spending
    {
        member: principal,
        month: uint,
        category: (string-ascii 20),
    }
    uint
)

(define-map category-totals
    {
        category: (string-ascii 20),
        month: uint,
    }
    uint
)

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
        (category (string-ascii 20))
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
            category: category,
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
    (let (
            (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (category (get category proposal))
            (amount (get amount proposal))
            (budget (map-get? budget-categories category))
        )
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (>= (get signatures proposal) (var-get required-signatures))
            ERR-NOT-AUTHORIZED
        )
        (asserts! (< burn-block-height (get expires-at proposal))
            ERR-PROPOSAL-EXPIRED
        )
        (asserts! (not (get executed proposal)) ERR-PROPOSAL-EXPIRED)
        (match budget
            existing-budget (begin
                (asserts!
                    (<= (+ (get spent existing-budget) amount)
                        (get limit existing-budget)
                    )
                    ERR-BUDGET-EXCEEDED
                )
                (map-set budget-categories category
                    (merge existing-budget { spent: (+ (get spent existing-budget) amount) })
                )
            )
            true
        )
        (try! (stx-transfer? amount tx-sender (get recipient proposal)))
        (unwrap!
            (record-expense (get recipient proposal) amount category
                (get description proposal)
            )
            ERR-INVALID-AMOUNT
        )
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

(define-public (create-allowance
        (beneficiary principal)
        (amount uint)
        (period-blocks uint)
    )
    (begin
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (> period-blocks u0) ERR-INVALID-AMOUNT)
        (asserts! (is-none (map-get? recurring-allowances beneficiary))
            ERR-ALLOWANCE-ALREADY-EXISTS
        )
        (map-set recurring-allowances beneficiary {
            amount: amount,
            period-blocks: period-blocks,
            last-claimed: u0,
            created-by: tx-sender,
            signatures: u0,
            approved: false,
        })
        (ok true)
    )
)

(define-public (vote-on-allowance (beneficiary principal))
    (let (
            (allowance (unwrap! (map-get? recurring-allowances beneficiary)
                ERR-ALLOWANCE-NOT-FOUND
            ))
            (has-voted (default-to false
                (map-get? allowance-votes {
                    beneficiary: beneficiary,
                    voter: tx-sender,
                })
            ))
        )
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (not has-voted) ERR-ALREADY-VOTED)
        (asserts! (not (get approved allowance)) ERR-ALREADY-VOTED)
        (map-set allowance-votes {
            beneficiary: beneficiary,
            voter: tx-sender,
        }
            true
        )
        (let ((new-signatures (+ (get signatures allowance) u1)))
            (map-set recurring-allowances beneficiary
                (merge allowance {
                    signatures: new-signatures,
                    approved: (>= new-signatures (var-get required-signatures)),
                })
            )
        )
        (ok true)
    )
)

(define-public (claim-allowance)
    (let (
            (allowance (unwrap! (map-get? recurring-allowances tx-sender)
                ERR-ALLOWANCE-NOT-FOUND
            ))
            (current-block burn-block-height)
            (next-claim-block (+ (get last-claimed allowance) (get period-blocks allowance)))
        )
        (asserts! (get approved allowance) ERR-NOT-AUTHORIZED)
        (asserts! (>= current-block next-claim-block) ERR-ALLOWANCE-NOT-READY)
        (try! (stx-transfer? (get amount allowance) (get created-by allowance)
            tx-sender
        ))
        (unwrap!
            (record-expense tx-sender (get amount allowance) "allowance"
                "Recurring allowance claim"
            )
            ERR-INVALID-AMOUNT
        )
        (map-set recurring-allowances tx-sender
            (merge allowance { last-claimed: current-block })
        )
        (ok true)
    )
)

(define-public (cancel-allowance (beneficiary principal))
    (let ((allowance (unwrap! (map-get? recurring-allowances beneficiary)
            ERR-ALLOWANCE-NOT-FOUND
        )))
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts!
            (or (is-eq tx-sender (get created-by allowance)) (is-eq tx-sender beneficiary))
            ERR-NOT-AUTHORIZED
        )
        (map-delete recurring-allowances beneficiary)
        (ok true)
    )
)

(define-read-only (get-allowance (beneficiary principal))
    (map-get? recurring-allowances beneficiary)
)

(define-read-only (can-claim-allowance (beneficiary principal))
    (match (map-get? recurring-allowances beneficiary)
        allowance (let ((next-claim-block (+ (get last-claimed allowance) (get period-blocks allowance))))
            (and
                (get approved allowance)
                (>= burn-block-height next-claim-block)
            )
        )
        false
    )
)

(define-public (create-budget-category
        (category (string-ascii 20))
        (limit uint)
    )
    (begin
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> limit u0) ERR-INVALID-AMOUNT)
        (asserts! (is-none (map-get? budget-categories category))
            ERR-CATEGORY-ALREADY-EXISTS
        )
        (map-set budget-categories category {
            limit: limit,
            spent: u0,
            created-by: tx-sender,
        })
        (ok true)
    )
)

(define-public (update-budget-limit
        (category (string-ascii 20))
        (new-limit uint)
    )
    (let ((budget (unwrap! (map-get? budget-categories category) ERR-CATEGORY-NOT-FOUND)))
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> new-limit u0) ERR-INVALID-AMOUNT)
        (map-set budget-categories category (merge budget { limit: new-limit }))
        (ok true)
    )
)

(define-public (reset-budget-spending (category (string-ascii 20)))
    (let ((budget (unwrap! (map-get? budget-categories category) ERR-CATEGORY-NOT-FOUND)))
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (map-set budget-categories category (merge budget { spent: u0 }))
        (ok true)
    )
)

(define-read-only (get-budget-category (category (string-ascii 20)))
    (map-get? budget-categories category)
)

(define-read-only (get-budget-remaining (category (string-ascii 20)))
    (match (map-get? budget-categories category)
        budget (- (get limit budget) (get spent budget))
        u0
    )
)

(define-read-only (is-budget-exceeded
        (category (string-ascii 20))
        (amount uint)
    )
    (match (map-get? budget-categories category)
        budget (> (+ (get spent budget) amount) (get limit budget))
        false
    )
)

(define-private (record-expense
        (spender principal)
        (amount uint)
        (category (string-ascii 20))
        (description (string-ascii 50))
    )
    (let (
            (expense-id (var-get expense-nonce))
            (current-month (/ burn-block-height u4320))
            (current-spending (default-to u0
                (map-get? monthly-spending {
                    member: spender,
                    month: current-month,
                    category: category,
                })
            ))
            (current-category-total (default-to u0
                (map-get? category-totals {
                    category: category,
                    month: current-month,
                })
            ))
        )
        (map-set expense-records expense-id {
            spender: spender,
            amount: amount,
            category: category,
            description: description,
            timestamp: burn-block-height,
            approved-by: tx-sender,
        })
        (map-set monthly-spending {
            member: spender,
            month: current-month,
            category: category,
        }
            (+ current-spending amount)
        )
        (map-set category-totals {
            category: category,
            month: current-month,
        }
            (+ current-category-total amount)
        )
        (var-set expense-nonce (+ expense-id u1))
        (ok expense-id)
    )
)

(define-public (log-manual-expense
        (amount uint)
        (category (string-ascii 20))
        (description (string-ascii 50))
    )
    (begin
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (record-expense tx-sender amount category description)
    )
)

(define-read-only (get-expense (expense-id uint))
    (map-get? expense-records expense-id)
)

(define-read-only (get-member-monthly-spending
        (member principal)
        (month uint)
        (category (string-ascii 20))
    )
    (default-to u0
        (map-get? monthly-spending {
            member: member,
            month: month,
            category: category,
        })
    )
)

(define-read-only (get-category-monthly-total
        (category (string-ascii 20))
        (month uint)
    )
    (default-to u0
        (map-get? category-totals {
            category: category,
            month: month,
        })
    )
)

(define-read-only (get-current-month)
    (/ burn-block-height u4320)
)

(define-read-only (get-total-expenses)
    (var-get expense-nonce)
)

(define-read-only (calculate-savings-rate
        (member principal)
        (income uint)
        (month uint)
    )
    (let (
            (food-spending (get-member-monthly-spending member month "food"))
            (transport-spending (get-member-monthly-spending member month "transport"))
            (entertainment-spending (get-member-monthly-spending member month "entertainment"))
            (utilities-spending (get-member-monthly-spending member month "utilities"))
            (total-spending (+ (+ food-spending transport-spending)
                (+ entertainment-spending utilities-spending)
            ))
        )
        (if (> income u0)
            (/ (* (- income total-spending) u100) income)
            u0
        )
    )
)

;; ==========================================================
;; ADVANCED EXPENSE REPORTING & ANALYTICS FEATURES
;; ==========================================================

;; New error constants for reporting features
(define-constant ERR-INVALID-DATE-RANGE (err u115))
(define-constant ERR-NO-DATA-AVAILABLE (err u116))

;; Data structures for expense analytics
(define-map expense-trends
    {
        category: (string-ascii 20),
        quarter: uint,
    }
    {
        total-amount: uint,
        transaction-count: uint,
        average-amount: uint,
        highest-expense: uint,
        lowest-expense: uint,
    }
)

(define-map family-spending-summary
    {
        month: uint,
        year: uint,
    }
    {
        total-spent: uint,
        category-breakdown: (list 10 {
            category: (string-ascii 20),
            amount: uint,
        }),
        top-spender: principal,
        transactions-count: uint,
    }
)

(define-map expense-goals
    {
        member: principal,
        category: (string-ascii 20),
        quarter: uint,
    }
    {
        target-amount: uint,
        current-spent: uint,
        goal-status: (string-ascii 10), ;; "on-track", "over", "achieved"
        created-at: uint,
    }
)

;; Advanced expense reporting functions
(define-public (generate-expense-report
        (start-month uint)
        (end-month uint)
        (category (optional (string-ascii 20)))
    )
    (begin
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (<= start-month end-month) ERR-INVALID-DATE-RANGE)
        (asserts! (<= (- end-month start-month) u12) ERR-INVALID-DATE-RANGE) ;; Max 12 months
        (ok {
            period: {
                start: start-month,
                end: end-month,
            },
            total-expenses: (calculate-period-total start-month end-month category),
            average-monthly: (calculate-average-monthly start-month end-month category),
            expense-trend: (calculate-trend-direction start-month end-month category),
            generated-by: tx-sender,
            generated-at: burn-block-height,
        })
    )
)

(define-public (set-expense-goal
        (category (string-ascii 20))
        (target-amount uint)
        (quarter uint)
    )
    (begin
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> target-amount u0) ERR-INVALID-AMOUNT)
        (map-set expense-goals {
            member: tx-sender,
            category: category,
            quarter: quarter,
        } {
            target-amount: target-amount,
            current-spent: u0,
            goal-status: "on-track",
            created-at: burn-block-height,
        })
        (ok true)
    )
)

(define-public (update-goal-progress
        (member principal)
        (category (string-ascii 20))
        (quarter uint)
        (spent-amount uint)
    )
    (let (
            (goal (unwrap!
                (map-get? expense-goals {
                    member: member,
                    category: category,
                    quarter: quarter,
                })
                ERR-CATEGORY-NOT-FOUND
            ))
            (new-spent (+ (get current-spent goal) spent-amount))
            (target (get target-amount goal))
            (new-status (if (>= new-spent target)
                (if (> new-spent target)
                    "over"
                    "achieved"
                )
                "on-track"
            ))
        )
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (map-set expense-goals {
            member: member,
            category: category,
            quarter: quarter,
        }
            (merge goal {
                current-spent: new-spent,
                goal-status: new-status,
            })
        )
        (ok true)
    )
)

(define-public (create-family-spending-insights
        (month uint)
        (year uint)
    )
    (let (
            (total-spent (calculate-family-total-for-month month))
            (top-categories (get-top-spending-categories month u5))
            (top-spender (get-highest-spender month))
            (tx-count (count-monthly-transactions month))
        )
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (map-set family-spending-summary {
            month: month,
            year: year,
        } {
            total-spent: total-spent,
            category-breakdown: top-categories,
            top-spender: top-spender,
            transactions-count: tx-count,
        })
        (ok true)
    )
)

;; Read-only functions for expense analytics
(define-read-only (get-expense-report
        (start-month uint)
        (end-month uint)
        (category (optional (string-ascii 20)))
    )
    {
        period: {
            start: start-month,
            end: end-month,
        },
        total-expenses: (calculate-period-total start-month end-month category),
        average-monthly: (calculate-average-monthly start-month end-month category),
        expense-trend: (calculate-trend-direction start-month end-month category),
        generated-at: burn-block-height,
    }
)

(define-read-only (get-expense-goal
        (member principal)
        (category (string-ascii 20))
        (quarter uint)
    )
    (map-get? expense-goals {
        member: member,
        category: category,
        quarter: quarter,
    })
)

(define-read-only (get-goal-achievement-rate
        (member principal)
        (quarter uint)
    )
    (let (
            (goals-achieved u0) ;; In a real implementation, iterate through goals
            (total-goals u1) ;; In a real implementation, count total goals
        )
        (if (> total-goals u0)
            (/ (* goals-achieved u100) total-goals)
            u0
        )
    )
)

(define-read-only (get-family-spending-insights
        (month uint)
        (year uint)
    )
    (map-get? family-spending-summary {
        month: month,
        year: year,
    })
)

(define-read-only (get-spending-comparison
        (member1 principal)
        (member2 principal)
        (month uint)
        (category (string-ascii 20))
    )
    (let (
            (spending1 (get-member-monthly-spending member1 month category))
            (spending2 (get-member-monthly-spending member2 month category))
            (difference (if (> spending1 spending2)
                (- spending1 spending2)
                (- spending2 spending1)
            ))
        )
        {
            member1-spending: spending1,
            member2-spending: spending2,
            difference: difference,
            higher-spender: (if (> spending1 spending2)
                member1
                member2
            ),
        }
    )
)

(define-read-only (predict-monthly-spending
        (member principal)
        (category (string-ascii 20))
        (current-month uint)
    )
    (let (
            (last-month-spending (get-member-monthly-spending member (- current-month u1) category))
            (two-months-ago (get-member-monthly-spending member (- current-month u2) category))
            (three-months-ago (get-member-monthly-spending member (- current-month u3) category))
            (average-spending (/ (+ (+ last-month-spending two-months-ago) three-months-ago) u3))
            (trend-factor (if (and
                    (> last-month-spending two-months-ago)
                    (> two-months-ago three-months-ago)
                )
                u110 ;; Increasing trend +10%
                (if (and
                        (< last-month-spending two-months-ago)
                        (< two-months-ago three-months-ago)
                    )
                    u90 ;; Decreasing trend -10%
                    u100 ;; Stable trend
                )
            ))
        )
        (/ (* average-spending trend-factor) u100)
    )
)

;; Helper functions for analytics
(define-private (calculate-period-total
        (start-month uint)
        (end-month uint)
        (category (optional (string-ascii 20)))
    )
    ;; Simplified implementation - in practice would iterate through months
    (match category
        cat
        (get-category-monthly-total cat start-month)
        u0 ;; Would sum all categories if none specified
    )
)

(define-private (calculate-average-monthly
        (start-month uint)
        (end-month uint)
        (category (optional (string-ascii 20)))
    )
    (let ((period-length (+ (- end-month start-month) u1)))
        (/ (calculate-period-total start-month end-month category) period-length)
    )
)

(define-private (calculate-trend-direction
        (start-month uint)
        (end-month uint)
        (category (optional (string-ascii 20)))
    )
    ;; Simplified trend calculation
    (let (
            (start-total (match category
                cat (get-category-monthly-total cat start-month)
                u0
            ))
            (end-total (match category
                cat (get-category-monthly-total cat end-month)
                u0
            ))
        )
        (if (> end-total start-total)
            "increasing"
            (if (< end-total start-total)
                "decreasing"
                "stable"
            )
        )
    )
)

(define-private (calculate-family-total-for-month (month uint))
    ;; Simplified implementation - would sum all members' spending
    u0
)

(define-private (get-top-spending-categories
        (month uint)
        (limit uint)
    )
    ;; Returns empty list - in practice would return top categories
    (list)
)

(define-private (get-highest-spender (month uint))
    ;; Returns contract caller - in practice would calculate actual top spender
    tx-sender
)

(define-private (count-monthly-transactions (month uint))
    u0
)

(define-map member-profiles
    { owner: principal }
    { nick: (string-utf8 32) }
)

(define-constant nickname-min-len u1)
(define-constant err-nickname-too-short (err u117))

(define-public (set-nickname (new-nickname (string-utf8 32)))
    (let (
            (caller tx-sender)
            (provided new-nickname)
            (provided-len (len provided))
        )
        (if (not (>= provided-len nickname-min-len))
            err-nickname-too-short
            (begin
                (map-set member-profiles { owner: caller } { nick: provided })
                (ok true)
            )
        )
    )
)

(define-read-only (get-nickname (profile-owner principal))
    (let ((entry (map-get? member-profiles { owner: profile-owner })))
        (match entry
            profile (some (get nick profile))
            none
        )
    )
)
