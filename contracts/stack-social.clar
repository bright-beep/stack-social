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