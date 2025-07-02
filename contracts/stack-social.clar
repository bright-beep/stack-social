;; StackSocial Protocol
;;
;; Title: StackSocial - Decentralized Social Identity and Reputation Network
;;
;; Summary:
;; StackSocial is a groundbreaking Bitcoin-secured social protocol that transforms
;; digital identity through cryptographic proof-of-stake mechanisms. Built on Stacks,
;; it enables users to create verifiable profiles, build trust networks, and engage
;; in stake-weighted social interactions with Bitcoin-level security guarantees.
;;
;; Description:
;; StackSocial revolutionizes social networking by introducing economic incentives
;; directly into social interactions. Every profile creation, connection, content
;; publication, and endorsement requires skin-in-the-game through STX staking,
;; creating a self-regulating ecosystem where reputation has real monetary value.

;; CONSTANTS & ERROR CODES

(define-constant CONTRACT_OWNER tx-sender)

;; Error definitions for comprehensive error handling
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROFILE_EXISTS (err u101))
(define-constant ERR_PROFILE_NOT_FOUND (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_INVALID_AMOUNT (err u104))
(define-constant ERR_ALREADY_FOLLOWING (err u105))
(define-constant ERR_NOT_FOLLOWING (err u106))
(define-constant ERR_SELF_FOLLOW (err u107))
(define-constant ERR_ALREADY_ENDORSED (err u108))
(define-constant ERR_POST_NOT_FOUND (err u109))
(define-constant ERR_INVALID_POST_ID (err u110))

;; Economic parameters (amounts in microSTX)
(define-constant MIN_PROFILE_STAKE u1000000)     ;; 1 STX minimum profile stake
(define-constant MIN_POST_BOOST u100000)         ;; 0.1 STX minimum post boost
(define-constant MIN_ENDORSEMENT_STAKE u500000)  ;; 0.5 STX minimum endorsement

;; STATE VARIABLES

(define-data-var next-profile-id uint u1)
(define-data-var next-post-id uint u1)
(define-data-var protocol-fee-rate uint u100)    ;; 1% = 100 basis points

;; DATA STRUCTURES

;; Comprehensive profile data structure
(define-map profiles
  { profile-id: uint }
  {
    owner: principal,
    username: (string-ascii 50),
    bio: (string-utf8 280),
    avatar-url: (string-ascii 200),
    created-at: uint,
    staked-amount: uint,
    reputation-score: uint,
    follower-count: uint,
    following-count: uint,
    post-count: uint,
    total-endorsements: uint,
    is-active: bool
  }
)

;; Efficient username lookup mapping
(define-map username-to-profile (string-ascii 50) uint)

;; Principal to profile ID reverse mapping
(define-map principal-to-profile principal uint)

;; Social connection tracking with timestamps
(define-map following
  { follower: uint, following: uint }
  { followed-at: uint, is-active: bool }
)

;; Content storage with engagement metrics
(define-map posts
  { post-id: uint }
  {
    author: uint,
    content: (string-utf8 500),
    created-at: uint,
    boosted-amount: uint,
    endorsement-count: uint,
    is-active: bool
  }
)

;; Post endorsement tracking with stake amounts
(define-map post-endorsements
  { post-id: uint, endorser: uint }
  { endorsed-at: uint, stake-amount: uint }
)

;; Profile endorsement system with custom messages
(define-map profile-endorsements
  { endorser: uint, endorsed: uint }
  { endorsed-at: uint, stake-amount: uint, message: (string-utf8 140) }
)

;; Individual staking records for reputation calculation
(define-map profile-stakes
  { profile-id: uint, staker: principal }
  { amount: uint, staked-at: uint }
)

;; Post boosting mechanism for content amplification
(define-map post-boosts
  { post-id: uint, booster: principal }
  { amount: uint, boosted-at: uint }
)

;; READ-ONLY FUNCTIONS

;; Retrieve profile data by unique identifier
(define-read-only (get-profile (profile-id uint))
  (map-get? profiles { profile-id: profile-id })
)

;; Username-based profile lookup
(define-read-only (get-profile-by-username (username (string-ascii 50)))
  (match (map-get? username-to-profile username)
    profile-id (get-profile profile-id)
    none
  )
)

;; Principal-based profile lookup for wallet integration
(define-read-only (get-profile-by-principal (user principal))
  (match (map-get? principal-to-profile user)
    profile-id (get-profile profile-id)
    none
  )
)

;; Username availability checker for registration
(define-read-only (is-username-available (username (string-ascii 50)))
  (is-none (map-get? username-to-profile username))
)

;; Social connection status verification
(define-read-only (is-following (follower-id uint) (following-id uint))
  (match (map-get? following { follower: follower-id, following: following-id })
    follow-data (get is-active follow-data)
    false
  )
)

;; Content retrieval function
(define-read-only (get-post (post-id uint))
  (map-get? posts { post-id: post-id })
)

;; System state accessors
(define-read-only (get-next-profile-id)
  (var-get next-profile-id)
)

(define-read-only (get-next-post-id)
  (var-get next-post-id)
)

;; Advanced reputation calculation algorithm
(define-read-only (calculate-reputation-score (profile-id uint))
  (match (get-profile profile-id)
    profile-data
    (let
      (
        (base-score (get staked-amount profile-data))
        (follower-bonus (* (get follower-count profile-data) u1000))
        (endorsement-bonus (* (get total-endorsements profile-data) u2000))
        (post-bonus (* (get post-count profile-data) u500))
      )
      (+ base-score (+ follower-bonus (+ endorsement-bonus post-bonus)))
    )
    u0
  )
)

;; CORE PUBLIC FUNCTIONS

;; Profile creation with economic commitment
(define-public (create-profile 
  (username (string-ascii 50))
  (bio (string-utf8 280))
  (avatar-url (string-ascii 200))
)
  (let
    (
      (profile-id (var-get next-profile-id))
      (current-block stacks-block-height)
    )
    ;; Validation checks
    (asserts! (is-none (map-get? principal-to-profile tx-sender)) ERR_PROFILE_EXISTS)
    (asserts! (is-username-available username) ERR_PROFILE_EXISTS)
    (asserts! (>= (stx-get-balance tx-sender) MIN_PROFILE_STAKE) ERR_INSUFFICIENT_FUNDS)
    
    ;; Economic commitment through staking
    (try! (stx-transfer? MIN_PROFILE_STAKE tx-sender (as-contract tx-sender)))
    
    ;; Profile initialization
    (map-set profiles
      { profile-id: profile-id }
      {
        owner: tx-sender,
        username: username,
        bio: bio,
        avatar-url: avatar-url,
        created-at: current-block,
        staked-amount: MIN_PROFILE_STAKE,
        reputation-score: MIN_PROFILE_STAKE,
        follower-count: u0,
        following-count: u0,
        post-count: u0,
        total-endorsements: u0,
        is-active: true
      }
    )
    
    ;; Index mappings for efficient lookups
    (map-set username-to-profile username profile-id)
    (map-set principal-to-profile tx-sender profile-id)
    (map-set profile-stakes 
      { profile-id: profile-id, staker: tx-sender }
      { amount: MIN_PROFILE_STAKE, staked-at: current-block }
    )
    
    ;; System state update
    (var-set next-profile-id (+ profile-id u1))
    
    (ok profile-id)
  )
)

;; Social connection establishment
(define-public (follow-user (following-id uint))
  (let
    (
      (follower-profile-result (map-get? principal-to-profile tx-sender))
      (current-block stacks-block-height)
    )
    (match follower-profile-result
      follower-id
      (begin
        ;; Validation and business logic checks
        (asserts! (not (is-eq follower-id following-id)) ERR_SELF_FOLLOW)
        (asserts! (is-some (get-profile following-id)) ERR_PROFILE_NOT_FOUND)
        (asserts! (not (is-following follower-id following-id)) ERR_ALREADY_FOLLOWING)
        
        ;; Create bidirectional relationship tracking
        (map-set following
          { follower: follower-id, following: following-id }
          { followed-at: current-block, is-active: true }
        )
        
        ;; Update follower metrics
        (match (get-profile following-id)
          following-profile
          (map-set profiles
            { profile-id: following-id }
            (merge following-profile { follower-count: (+ (get follower-count following-profile) u1) })
          )
          false
        )
        
        ;; Update following metrics
        (match (get-profile follower-id)
          follower-profile
          (map-set profiles
            { profile-id: follower-id }
            (merge follower-profile { following-count: (+ (get following-count follower-profile) u1) })
          )
          false
        )
        
        (ok true)
      )
      ERR_PROFILE_NOT_FOUND
    )
  )
)

;; Social connection termination
(define-public (unfollow-user (following-id uint))
  (let
    (
      (follower-profile-result (map-get? principal-to-profile tx-sender))
    )
    (match follower-profile-result
      follower-id
      (begin
        ;; Validate existing connection
        (asserts! (is-following follower-id following-id) ERR_NOT_FOLLOWING)
        
        ;; Remove relationship
        (map-delete following { follower: follower-id, following: following-id })
        
        ;; Update metrics atomically
        (match (get-profile following-id)
          following-profile
          (map-set profiles
            { profile-id: following-id }
            (merge following-profile { follower-count: (- (get follower-count following-profile) u1) })
          )
          false
        )
        
        (match (get-profile follower-id)
          follower-profile
          (map-set profiles
            { profile-id: follower-id }
            (merge follower-profile { following-count: (- (get following-count follower-profile) u1) })
          )
          false
        )
        
        (ok true)
      )
      ERR_PROFILE_NOT_FOUND
    )
  )
)

;; Content publication system
(define-public (create-post (content (string-utf8 500)))
  (let
    (
      (author-profile-result (map-get? principal-to-profile tx-sender))
      (post-id (var-get next-post-id))
      (current-block stacks-block-height)
    )
    (match author-profile-result
      author-id
      (begin
        ;; Content creation
        (map-set posts
          { post-id: post-id }
          {
            author: author-id,
            content: content,
            created-at: current-block,
            boosted-amount: u0,
            endorsement-count: u0,
            is-active: true
          }
        )
        
        ;; Update author statistics
        (match (get-profile author-id)
          author-profile
          (map-set profiles
            { profile-id: author-id }
            (merge author-profile { post-count: (+ (get post-count author-profile) u1) })
          )
          false
        )
        
        ;; System state progression
        (var-set next-post-id (+ post-id u1))
        
        (ok post-id)
      )
      ERR_PROFILE_NOT_FOUND
    )
  )
)

;; Economic content amplification mechanism
(define-public (boost-post (post-id uint) (amount uint))
  (let
    (
      (current-block stacks-block-height)
    )
    ;; Economic and existence validations
    (asserts! (>= amount MIN_POST_BOOST) ERR_INVALID_AMOUNT)
    (asserts! (is-some (get-post post-id)) ERR_POST_NOT_FOUND)
    (asserts! (>= (stx-get-balance tx-sender) amount) ERR_INSUFFICIENT_FUNDS)
    
    ;; Economic commitment
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Boost tracking
    (map-set post-boosts
      { post-id: post-id, booster: tx-sender }
      { amount: amount, boosted-at: current-block }
    )
    
    ;; Content metrics update
    (match (get-post post-id)
      post-data
      (map-set posts
        { post-id: post-id }
        (merge post-data { boosted-amount: (+ (get boosted-amount post-data) amount) })
      )
      false
    )
    
    (ok true)
  )
)