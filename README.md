# 🆔 Sovr - Self-Sovereign Identity Contract

## 🌟 Overview

Sovr is a decentralized identity management smart contract built on Stacks blockchain that enables users to create and manage their own digital identities without relying on centralized authorities. Users have complete control over their identity data and can selectively share information with trusted parties.

## ✨ Features

- 🔐 **Self-Sovereign Identity Creation** - Users create and own their decentralized identities
- 📝 **Attribute Management** - Store and manage identity attributes with privacy controls
- ✅ **Verification System** - Trusted verifiers can issue and revoke identity claims
- 🔒 **Privacy Controls** - Users control visibility of their identity attributes
- 🏛️ **Trusted Verifier Network** - Contract owner manages trusted verification entities
- 📊 **Identity Analytics** - Track identity creation and verification metrics

## 🚀 Quick Start

### Creating an Identity

```clarity
(contract-call? .sovr create-identity "did:stx:your-unique-identifier")
```

### Setting Attributes

```clarity
;; Public attribute
(contract-call? .sovr set-attribute "name" "John Doe" true)

;; Private attribute
(contract-call? .sovr set-attribute "email" "john@example.com" false)
```

### Managing Verifications

```clarity
;; Issue verification (as trusted verifier)
(contract-call? .sovr issue-verification 'SP123...ABC "age-verification" "over-18" (some u1000000))

;; Revoke verification
(contract-call? .sovr revoke-verification 'SP123...ABC "age-verification")
```

## 📋 Core Functions

### 🔧 Public Functions

| Function | Description |
|----------|-------------|
| `create-identity` | Create a new decentralized identity |
| `update-identity-status` | Activate/deactivate your identity |
| `set-attribute` | Add or update identity attributes |
| `remove-attribute` | Remove identity attributes |
| `add-trusted-verifier` | Add trusted verifier (owner only) |
| `remove-trusted-verifier` | Remove trusted verifier (owner only) |
| `issue-verification` | Issue identity verification claim |
| `revoke-verification` | Revoke existing verification |

### 👀 Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-identity` | Retrieve identity information |
| `get-attribute` | Get identity attribute (respects privacy) |
| `get-verification` | Check verification status |
| `is-trusted-verifier` | Verify if address is trusted verifier |
| `get-identity-count` | Get total number of identities |
| `verify-identity-ownership` | Check if address owns an identity |

## 🔐 Privacy & Security

- ✅ **User-Controlled**: Only identity owners can modify their data
- 🔒 **Privacy Settings**: Attributes can be public or private
- 🛡️ **Verification Trust**: Only trusted verifiers can issue claims
- ⏰ **Expiration Support**: Verifications can have expiration dates
- 🚫 **Revocation**: Verifications can be revoked by issuers

## 🎯 Use Cases

- 📱 **Digital Identity Wallets**
- 🏢 **Corporate Identity Verification**
- 🎓 **Educational Credential Management**
- 🏥 **Healthcare Identity Systems**
- 🌐 **Web3 Authentication**
- 🏛️ **Government Digital ID**

## 🛠️ Development

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy
```

## 📄 Error Codes

| Code | Description |
|------|-------------|
| `u100` | Unauthorized access |
| `u101` | Identity already exists |
| `u102` | Identity not found |
| `u103` | Invalid attribute |
| `u104` | Verification already exists |
| `u105` | Verification not found |
| `u106` | Invalid verifier |

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## 📜 License

This project is open source and available under the MIT License.


