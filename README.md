# BRICBridge

A sophisticated synthetic assets smart contract that creates synthetic exposure to traditional assets from BRIC countries (Brazil, Russia, India, and China) through a composite index. Built on the Stacks blockchain using Clarity smart contract language.

## 🌍 Overview

BRICBridge enables users to mint synthetic tokens (SYN-BRIC) that represent exposure to a composite of traditional assets from BRIC countries. The system is collateralized by STX tokens, providing a decentralized way to gain exposure to emerging market assets without directly holding the underlying instruments.

## ✨ Features

- **Synthetic Asset Minting**: Create SYN-BRIC tokens backed by STX collateral
- **Overcollateralized System**: Maintains 150% collateralization ratio for stability
- **Liquidation Mechanism**: Automated liquidation of undercollateralized positions
- **Oracle Integration**: Dynamic price feeds for BRIC composite pricing
- **Position Management**: Multiple positions per user with unique identifiers
- **SIP-010 Compliance**: Fully compatible with Stacks fungible token standard
- **Access Control**: Role-based permissions for oracles and contract administration
- **Emergency Controls**: Pausable contract functionality for security

## 🔧 Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity 2.0
- **Token Standard**: SIP-010 Fungible Token
- **Collateral Asset**: STX
- **Collateralization Ratio**: 150% (15000 basis points)
- **Liquidation Threshold**: 120% (12000 basis points)
- **Liquidation Penalty**: 5% (500 basis points)
- **Token Symbol**: SYN-BRIC
- **Token Decimals**: 6

## 📦 Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v1.5.0 or higher
- [Node.js](https://nodejs.org/) v16 or higher
- [npm](https://www.npmjs.com/) or [yarn](https://yarnpkg.com/)

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd BRICBridge
```

2. Install dependencies:
```bash
cd BRICBridge_contract
npm install
```

3. Run tests:
```bash
npm test
```

4. Check contract syntax:
```bash
clarinet check
```

## 🚀 Usage Examples

### Deploying the Contract

```bash
clarinet deploy --testnet
```

### Basic Operations

#### Minting Synthetic Tokens

```clarity
;; Mint SYN-BRIC tokens by depositing 1000 STX as collateral
(contract-call? .BRICBridge mint-synthetic u1000000000)
```

#### Burning Synthetic Tokens

```clarity
;; Burn synthetic tokens and retrieve collateral for position #1
(contract-call? .BRICBridge burn-synthetic u1)
```

#### Checking Position Status

```clarity
;; Get position details for user and position ID
(contract-call? .BRICBridge get-position 'SP1234... u1)

;; Check collateral ratio
(contract-call? .BRICBridge get-collateral-ratio 'SP1234... u1)
```

## 📋 Contract Functions Documentation

### Public Functions

#### Core Operations

| Function | Description | Parameters | Returns |
|----------|-------------|------------|---------|
| `initialize` | Initialize contract (owner only) | None | `(response bool uint)` |
| `mint-synthetic` | Mint SYN-BRIC tokens with STX collateral | `collateral-amount: uint` | `(response uint uint)` |
| `burn-synthetic` | Burn synthetic tokens and withdraw collateral | `position-id: uint` | `(response bool uint)` |
| `liquidate-position` | Liquidate undercollateralized position | `user: principal, position-id: uint` | `(response bool uint)` |

#### Oracle Functions

| Function | Description | Parameters | Returns |
|----------|-------------|------------|---------|
| `update-bric-price` | Update BRIC composite price | `new-price: uint` | `(response bool uint)` |
| `add-oracle` | Add authorized oracle (owner only) | `oracle: principal` | `(response bool uint)` |
| `remove-oracle` | Remove authorized oracle (owner only) | `oracle: principal` | `(response bool uint)` |

#### Administrative Functions

| Function | Description | Parameters | Returns |
|----------|-------------|------------|---------|
| `set-contract-paused` | Pause/unpause contract (owner only) | `paused: bool` | `(response bool uint)` |

### Read-Only Functions

#### Token Information

| Function | Description | Returns |
|----------|-------------|---------|
| `get-name` | Get token name | `(response string-ascii uint)` |
| `get-symbol` | Get token symbol | `(response string-ascii uint)` |
| `get-decimals` | Get token decimals | `(response uint uint)` |
| `get-total-supply` | Get total token supply | `(response uint uint)` |
| `get-balance` | Get user token balance | `(response uint uint)` |

#### Position Information

| Function | Description | Parameters | Returns |
|----------|-------------|------------|---------|
| `get-position` | Get position details | `user: principal, position-id: uint` | `(optional {...})` |
| `get-collateral-ratio` | Calculate position collateral ratio | `user: principal, position-id: uint` | `(response uint uint)` |
| `is-position-liquidatable` | Check if position can be liquidated | `user: principal, position-id: uint` | `(response bool uint)` |
| `get-user-position-count` | Get user's total positions | `user: principal` | `uint` |

#### System Information

| Function | Description | Returns |
|----------|-------------|---------|
| `get-bric-price` | Get current BRIC price | `uint` |
| `get-total-collateral` | Get total locked collateral | `uint` |
| `get-total-synthetic-supply` | Get total synthetic token supply | `uint` |
| `is-authorized-oracle` | Check if address is authorized oracle | `bool` |
| `is-contract-paused` | Check if contract is paused | `bool` |
| `get-contract-owner` | Get contract owner address | `principal` |

## 🌐 Deployment Guide

### Testnet Deployment

1. Configure testnet settings in `settings/Testnet.toml`
2. Deploy using Clarinet:
```bash
clarinet deploy --testnet
```

### Mainnet Deployment

1. Configure mainnet settings in `settings/Mainnet.toml`
2. Ensure thorough testing on testnet
3. Deploy using Clarinet:
```bash
clarinet deploy --mainnet
```

### Post-Deployment Steps

1. Initialize the contract:
```clarity
(contract-call? .BRICBridge initialize)
```

2. Add authorized oracles:
```clarity
(contract-call? .BRICBridge add-oracle 'SP1234...)
```

3. Set initial BRIC price if needed:
```clarity
(contract-call? .BRICBridge update-bric-price u100000000)
```

## 🔒 Security Considerations

### Audit Recommendations

- **Oracle Security**: Ensure price oracles are secure and tamper-resistant
- **Liquidation Bot**: Deploy automated liquidation bots to maintain system health
- **Collateral Monitoring**: Continuously monitor collateralization ratios
- **Emergency Procedures**: Establish procedures for contract pausing in emergencies

### Risk Factors

- **Oracle Risk**: Dependency on external price feeds
- **Liquidation Risk**: Positions may face liquidation during market volatility
- **Smart Contract Risk**: Potential bugs or vulnerabilities in contract code
- **Market Risk**: Exposure to BRIC composite asset price movements

### Best Practices

- Maintain collateralization ratios well above the minimum threshold
- Monitor positions regularly for liquidation risk
- Use multiple oracle sources when available
- Implement gradual position sizing strategies

## 🧪 Testing

Run the test suite:

```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:report

# Watch for changes and run tests
npm run test:watch
```

## 📄 License

ISC License

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## 📞 Support

For questions, issues, or contributions, please create an issue in the repository or contact the development team.

---

**Disclaimer**: This software is provided "as is" without warranty. Users should conduct their own security audits and understand the risks before deploying to mainnet or using with significant funds.