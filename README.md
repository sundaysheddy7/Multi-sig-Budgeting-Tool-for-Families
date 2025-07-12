# Multi-sig Budgeting Tool for Families

A decentralized family budgeting solution built on Stacks blockchain that enables secure multi-signature control over shared funds.

## ✨ Features

- 🔐 Multi-signature wallet functionality
- 👥 Family member management
- 💸 Proposal creation and voting system
- ⏱️ Time-bound proposal execution
- 📊 Transparent transaction tracking

## 🚀 Getting Started

### Prerequisites

- Clarinet
- Stacks wallet
- STX tokens for transactions

### Contract Functions

#### Core Functions

- `initialize`: Set up the contract with required signatures and proposal duration
- `add-family-member`: Add new family members to the wallet
- `remove-family-member`: Remove existing family members
- `create-proposal`: Create new spending proposals
- `vote-on-proposal`: Vote on existing proposals
- `execute-proposal`: Execute approved proposals

#### Read-Only Functions

- `is-member`: Check if an address is a family member
- `get-proposal`: Get proposal details
- `get-member-count`: Get total number of family members

## 💡 Usage Example

1. Initialize the contract
2. Add family members
3. Create spending proposals
4. Family members vote on proposals
5. Execute approved proposals

## 🔒 Security

- Multi-signature requirement ensures collective decision making
- Time-bound proposals prevent stale transactions
- Only authorized family members can participate
```
