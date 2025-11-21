
# ReputaDAO - DAO Governance Smart Contract (Clarity)

This project implements a fully on-chain, reputation-based DAO governance system written in **Clarity** for the **Stacks blockchain**. It includes proposal creation, voting, delegation, treasury management, membership staking, and reputation transfers.

---

## ⭐ Features

### **🗳 Proposal System**

* Create proposals with a title, description, and funding request
* Enforced minimum proposal amount
* Automatic voting expiration using block height
* Restricts invalid or malformed proposals

### **🧮 Voting**

* Members can vote **for** or **against**
* Prevents duplicate voting
* Prevents voting after expiry
* Allows vote delegation (without automatic weighted voting)

### **🏦 Treasury Management**

* DAO holds STX in a centralized treasury
* Members can **fund the DAO**
* Approved proposals can withdraw funds to their proposer
* Members may **withdraw staked amounts** if authorized

### **👥 Membership & Reputation**

* Join the DAO by staking a minimum STX amount
* Every join increases a member’s reputation
* Reputation is transferable between members
* DAO membership acts as an authorization mechanism

### **📊 Proposal Execution**

* A proposal is approved when:

  * Voting period has ended
  * Votes-for ≥ 70% of total votes
* The amount requested must be available in the treasury
* Successful execution transfers funds and marks the proposal as `done`

### **📚 Read-Only Views**

* Get proposal details
* Get treasury balance
* Get a member's reputation

---

## 🏛 Data Model

### **Maps**

| Map              | Purpose                                           |
| ---------------- | ------------------------------------------------- |
| `proposals`      | Stores proposal metadata and vote counts          |
| `votes`          | Tracks whether a member voted on a given proposal |
| `member-details` | Stores DAO member reputation values               |

### **Data Vars**

* `proposal-count` – auto-increments proposal IDs
* `dao-treasury` – total STX stored in the DAO

### **Key Constants**

* `VOTING_PERIOD` – 1440 blocks (~10 days)
* `MIN_PROPOSAL_AMOUNT` – minimum request amount
* `REQUIRED_APPROVAL_PERCENTAGE` – 70%

---

## 🧱 Public Functions Overview

### Proposal Lifecycle

| Function           | Description                          |
| ------------------ | ------------------------------------ |
| `submit-proposal`  | Create a new governance proposal     |
| `cast-vote`        | Vote for or against a proposal       |
| `execute-proposal` | Execute a proposal if approved       |
| `cancel-proposal`  | Proposer may void an active proposal |

### Membership

| Function              | Description                                      |
| --------------------- | ------------------------------------------------ |
| `join-dao`            | Stake STX to become a member and gain reputation |
| `increase-reputation` | Increase another member’s reputation             |
| `transfer-reputation` | Move your reputation to another member           |

### Treasury

| Function         | Description                           |
| ---------------- | ------------------------------------- |
| `fund-dao`       | Deposit STX into the DAO treasury     |
| `withdraw-stake` | Withdraw available funds from the DAO |

### Delegation

| Function        | Description                                    |
| --------------- | ---------------------------------------------- |
| `delegate-vote` | Lock your vote and assign it to another member |

---

## 🔒 Authorization Logic

Many actions require DAO membership.
Membership is validated through:

```clarity
(is-dao-member tx-sender)
```

A user becomes a member by calling:

```clarity
(join-dao stake-amount)
```

---

## 🚀 Deployment & Usage

1. Deploy the contract on Stacks
2. Fund your wallet with STX
3. Call `join-dao` to become a member
4. Submit proposals via `submit-proposal`
5. Vote during the active voting period
6. Execute proposals after they expire and meet approval threshold

---

## 🐞 Error Codes

| Error                           | Meaning                             |
| ------------------------------- | ----------------------------------- |
| `ERR-NOT-AUTHORIZED`            | Caller lacks permission             |
| `ERR-INVALID-PROPOSAL`          | Proposal does not meet requirements |
| `ERR-ALREADY-VOTED`             | Duplicate vote attempt              |
| `ERR-PROPOSAL-EXPIRED`          | Voting after deadline               |
| `ERR-INSUFFICIENT-FUNDS`        | Treasury insufficient               |
| `ERR-ZERO-AMOUNT`               | Amount must be positive             |
| `ERR-INVALID-STATUS`            | Proposal not in valid state         |
| `ERR-SELF-DELEGATION`           | Cannot delegate to yourself         |
| `ERR-INVALID-TITLE/DESC-LENGTH` | Title/description is empty          |

---

## 🧪 Testing Checklist

* [ ] Membership creation & staking
* [ ] Proposal creation validation
* [ ] Voting before/after expiry
* [ ] Delegation behavior
* [ ] Proposal execution logic
* [ ] Treasury balance updates
* [ ] Reputation transfers
* [ ] Withdrawals & cancellation logic

---

## 📝 License

MIT or your preferred open-source license.

---
