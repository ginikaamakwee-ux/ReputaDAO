(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PROPOSAL (err u101))
(define-constant ERR-ALREADY-VOTED (err u102))
(define-constant ERR-PROPOSAL-EXPIRED (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-ZERO-AMOUNT (err u105))
(define-constant ERR-INVALID-STATUS (err u106))
(define-constant ERR-SELF-DELEGATION (err u107))
(define-constant ERR-INVALID-TITLE-LENGTH (err u108))
(define-constant ERR-INVALID-DESC-LENGTH (err u109))

;; Data Maps
(define-map proposals 
    { proposal-id: uint }
    {
        title: (string-utf8 256),
        description: (string-utf8 1024),
        amount: uint,
        proposer: principal,
        votes-for: uint,
        votes-against: uint,
        status: (string-ascii 6),
        end-block: uint
    }
)

(define-map votes 
    { voter: principal, proposal-id: uint } 
    { voted: bool }
)

(define-map member-details
    { member: principal }
    { reputation: uint }
)

;; Constants
(define-constant VOTING_PERIOD u1440) ;; ~10 days in blocks
(define-constant MIN_PROPOSAL_AMOUNT u1000000) ;; in microSTX
(define-constant REQUIRED_APPROVAL_PERCENTAGE u70)

;; Variables
(define-data-var proposal-count uint u0)
(define-data-var dao-treasury uint u0)

;; Authorization check
(define-private (is-dao-member (user principal))
    (match (map-get? member-details { member: user })
        member-info true
        false))

;; Proposal Management
(define-public (submit-proposal (title (string-utf8 256)) 
                              (description (string-utf8 1024))
                              (amount uint))
    (let ((proposal-id (var-get proposal-count)))
        (asserts! (is-dao-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (>= amount MIN_PROPOSAL_AMOUNT) ERR-INVALID-PROPOSAL)
        (asserts! (> (len title) u0) ERR-INVALID-TITLE-LENGTH)
        (asserts! (> (len description) u0) ERR-INVALID-DESC-LENGTH)
        (asserts! (> amount u0) ERR-ZERO-AMOUNT)
        
        (map-set proposals
            { proposal-id: proposal-id }
            {
                title: title,
                description: description,
                amount: amount,
                proposer: tx-sender,
                votes-for: u0,
                votes-against: u0,
                status: "active",
                end-block: (+ stacks-block-height VOTING_PERIOD)
            }
        )
        
        (var-set proposal-count (+ proposal-id u1))
        (ok proposal-id)))

;; Voting System
(define-public (cast-vote (proposal-id uint) (vote-for bool))
    (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-INVALID-PROPOSAL))
          (voter-status (default-to { voted: false } 
                        (map-get? votes { voter: tx-sender, proposal-id: proposal-id }))))
        
        (asserts! (is-dao-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (not (get voted voter-status)) ERR-ALREADY-VOTED)
        (asserts! (<= stacks-block-height (get end-block proposal)) ERR-PROPOSAL-EXPIRED)
        
        (map-set votes 
            { voter: tx-sender, proposal-id: proposal-id }
            { voted: true })
            
        (if vote-for
            (map-set proposals { proposal-id: proposal-id }
                (merge proposal { votes-for: (+ (get votes-for proposal) u1) }))
            (map-set proposals { proposal-id: proposal-id }
                (merge proposal { votes-against: (+ (get votes-against proposal) u1) })))
        
        (ok true)))

;; Fund Management
(define-public (fund-dao)
    (let ((amount (stx-get-balance tx-sender)))
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set dao-treasury (+ (var-get dao-treasury) amount))
        (ok true)))

(define-public (execute-proposal (proposal-id uint))
    (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-INVALID-PROPOSAL)))
        (asserts! (>= stacks-block-height (get end-block proposal)) ERR-PROPOSAL-EXPIRED)
        (asserts! (is-proposal-approved proposal) ERR-NOT-AUTHORIZED)
        (asserts! (>= (var-get dao-treasury) (get amount proposal)) ERR-INSUFFICIENT-FUNDS)
        
        (try! (as-contract (stx-transfer? 
            (get amount proposal)
            tx-sender
            (get proposer proposal))))
            
        (var-set dao-treasury (- (var-get dao-treasury) (get amount proposal)))
        (map-set proposals { proposal-id: proposal-id }
            (merge proposal { status: "done" }))
        (ok true)))

;; Helper Functions
(define-private (is-proposal-approved (proposal {
        title: (string-utf8 256),
        description: (string-utf8 1024),
        amount: uint,
        proposer: principal,
        votes-for: uint,
        votes-against: uint,
        status: (string-ascii 6),
        end-block: uint
    }))
    (let ((total-votes (+ (get votes-for proposal) (get votes-against proposal))))
        (and
            (> total-votes u0)
            (>= (* (get votes-for proposal) u100) (* total-votes REQUIRED_APPROVAL_PERCENTAGE)))))

;; Membership Management
(define-public (join-dao (stake uint))
    (let ((current-rep (get-member-reputation tx-sender)))
        (asserts! (>= stake MIN_PROPOSAL_AMOUNT) ERR-INVALID-PROPOSAL)
        (try! (stx-transfer? stake tx-sender (as-contract tx-sender)))
        (var-set dao-treasury (+ (var-get dao-treasury) stake))
        (map-set member-details 
            { member: tx-sender }
            { reputation: (+ current-rep u1) })
        (ok true)))

(define-public (delegate-vote (delegate-to principal) (proposal-id uint))
    (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-INVALID-PROPOSAL))
          (voter-status (default-to { voted: false } 
                        (map-get? votes { voter: tx-sender, proposal-id: proposal-id }))))
        (asserts! (is-dao-member delegate-to) ERR-NOT-AUTHORIZED)
        (asserts! (not (get voted voter-status)) ERR-ALREADY-VOTED)
        (asserts! (<= stacks-block-height (get end-block proposal)) ERR-PROPOSAL-EXPIRED)
        (asserts! (not (is-eq tx-sender delegate-to)) ERR-SELF-DELEGATION)
        (asserts! (is-eq (get status proposal) "active") ERR-INVALID-STATUS)
        (map-set votes 
            { voter: tx-sender, proposal-id: proposal-id }
            { voted: true })
        (ok true)))

(define-public (increase-reputation (member principal))
    (let ((current-rep (get-member-reputation member)))
        (asserts! (is-dao-member tx-sender) ERR-NOT-AUTHORIZED)
        (map-set member-details 
            { member: member }
            { reputation: (+ current-rep u1) })
        (ok true)))

;; Read-Only Functions
(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals { proposal-id: proposal-id }))

(define-read-only (get-treasury-balance)
    (var-get dao-treasury))

(define-read-only (get-member-reputation (member principal))
    (default-to u0 
        (get reputation 
            (map-get? member-details { member: member }))))


;; Additional Functions
(define-public (withdraw-stake (amount uint))
    (let ((member-rep (get-member-reputation tx-sender)))
        (asserts! (is-dao-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-ZERO-AMOUNT)
        (asserts! (>= (var-get dao-treasury) amount) ERR-INSUFFICIENT-FUNDS)
        (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
        (var-set dao-treasury (- (var-get dao-treasury) amount))
        (ok true)))

(define-public (cancel-proposal (proposal-id uint))
    (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-INVALID-PROPOSAL)))
        (asserts! (is-eq tx-sender (get proposer proposal)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status proposal) "active") ERR-INVALID-STATUS)
        (asserts! (<= stacks-block-height (get end-block proposal)) ERR-PROPOSAL-EXPIRED)
        (map-set proposals { proposal-id: proposal-id }
            (merge proposal { status: "void" }))
        (ok true)))

(define-public (transfer-reputation (to principal) (amount uint))
    (let ((from-rep (get-member-reputation tx-sender))
          (to-rep (get-member-reputation to)))
        (asserts! (is-dao-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (>= from-rep amount) ERR-INSUFFICIENT-FUNDS)
        (asserts! (not (is-eq tx-sender to)) ERR-SELF-DELEGATION)
        (map-set member-details 
            { member: tx-sender }
            { reputation: (- from-rep amount) })
        (map-set member-details 
            { member: to }
            { reputation: (+ to-rep amount) })
        (ok true)))
