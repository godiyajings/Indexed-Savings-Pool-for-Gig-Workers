# 💰 Indexed Savings Pool for Gig Workers

An automated micro-savings smart contract built on Stacks that helps gig workers build savings habits with goal-based locks and pooled yield distribution.

## 🎯 Features

- **Goal-Based Savings**: Create savings goals with target amounts and lock durations
- **Automated Micro-Savings**: Regular deposits that build saving habits
- **Time-Locked Security**: Funds locked until goals are met or time expires
- **Pooled Interest**: Earn interest from pooled yields distributed proportionally
- **Multiple Goals**: Support up to 10 concurrent savings goals per user

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet with STX tokens

### Installation
```bash
git clone <repository-url>
cd Indexed-Savings-Pool-for-Gig-Workers
clarinet check
```

## 📖 Usage Guide

### 🎯 Creating a Savings Goal
```clarity
(contract-call? .indexed-savings-pool-for-gig-workers create-savings-goal u1000000 u144) ;; 1 STX goal, 144 blocks lock
```

### 💵 Making Deposits
```clarity
(contract-call? .indexed-savings-pool-for-gig-workers deposit-to-goal u1 u100000) ;; Deposit 0.1 STX to goal #1
```

### 💸 Withdrawing Funds
```clarity
(contract-call? .indexed-savings-pool-for-gig-workers withdraw-from-goal u1) ;; Withdraw from goal #1
```

### 📊 Checking Goal Status
```clarity
(contract-call? .indexed-savings-pool-for-gig-workers get-goal-status u1) ;; Check progress of goal #1
```

## 📋 Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `create-savings-goal` | Create a new savings goal | `target-amount`, `lock-duration` |
| `deposit-to-goal` | Deposit STX to a specific goal | `goal-id`, `amount` |
| `withdraw-from-goal` | Withdraw from completed/unlocked goal | `goal-id` |
| `add-pool-yield` | Add yield to interest pool (owner only) | `amount` |

### Read-Only Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `get-goal` | Get goal details | `goal-id` |
| `get-user-goals` | Get user's goal IDs | `user` |
| `get-user-shares` | Get user's pool shares | `user` |
| `get-pool-stats` | Get pool statistics | none |
| `get-goal-status` | Get goal progress and status | `goal-id` |

## 🔧 How It Works

1. **Goal Creation**: Gig workers set savings targets with time locks
2. **Micro-Deposits**: Regular small deposits build towards goals
3. **Interest Calculation**: 0.5% interest calculated on deposits
4. **Pool Sharing**: Interest distributed based on contribution shares
5. **Unlocking**: Withdraw when goal is met OR time lock expires

## 💡 Example Workflow

```bash
# 1. Create a $100 savings goal locked for 1000 blocks
clarinet console
>>> (contract-call? .indexed-savings-pool-for-gig-workers create-savings-goal u10000000 u1000)

# 2. Make regular deposits
>>> (contract-call? .indexed-savings-pool-for-gig-workers deposit-to-goal u1 u1000000)

# 3. Check progress
>>> (contract-call? .indexed-savings-pool-for-gig-workers get-goal-status u1)

# 4. Withdraw when ready
>>> (contract-call? .indexed-savings-pool-for-gig-workers withdraw-from-goal u1)
```

## ⚠️ Important Notes

- Amounts are in micro-STX (1 STX = 1,000,000 micro-STX)
- Goals are locked until target is reached OR time expires
- Interest is calculated at 0.5% per deposit
- Maximum 10 goals per user
- Only goal owners can deposit/withdraw

## 🧪 Testing

```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

---

Built with ❤️ for gig workers everywhere 🚀
