# SimpleEscrow

> Milestone-based escrow smart contract for secure agricultural and international trade payments

## Overview

SimpleEscrow is a Solidity smart contract designed for owner-controlled, milestone-based escrow services. Built specifically for agricultural supply chains and international trade, it enables transparent, automated payments that release only when agreed-upon milestones are completed.

## Key Features

- **🌱 Milestone-Based Payments** - Release funds incrementally as work progresses
- **🛡️ Owner-Controlled** - Service provider manages milestone completion and fund releases
- **⚡ Instant Settlements** - Automated payment release upon milestone completion
- **🌍 International Ready** - Built for cross-border agricultural trade
- **🔒 Secure** - Reentrancy protection and comprehensive validation
- **💰 ERC20 Compatible** - Works with stablecoins like USDC

## Use Cases

### Agricultural Supply Chains
- **Fair Trade Verification** - Ensure farmers receive payment upon delivery of quality products
- **Sustainable Agriculture** - Release incentive payments when environmental practices are verified
- **International Sourcing** - Secure payments for importers working with overseas suppliers

### Business Applications
- **Service Contracts** - Professional services with milestone-based deliverables
- **Manufacturing** - Progress payments for custom production orders
- **International Trade** - Secure escrow for cross-border transactions

## How It Works

```solidity
1. Create Escrow → Define milestones and payment percentages
2. Fund Escrow → Depositor transfers funds to contract
3. Complete Milestones → Owner marks milestones as completed
4. Release Funds → Automatic payment to beneficiary when all milestones done
```

## Contract Architecture

```
SimpleEscrow
├── createEscrow()     - Set up new escrow with custom milestones
├── fundEscrow()       - Depositor funds the escrow contract
├── completeMilestone() - Owner marks milestone as achieved
├── releaseFunds()     - Release all funds when milestones complete
└── View Functions     - Check escrow status, milestones, progress
```

## Deployment

### Sepolia Testnet
- **Contract Address:** `0x04604f558c8ce9ab4ed2eb2efed2f71172d9e1e2`
- **USDC Token:** `0xa0b86a33e6417c0ce8ffcf6cd85e97f0cef3c14f`
- **Explorer:** [View on Etherscan](https://sepolia.etherscan.io/address/0x04604f558c8ce9ab4ed2eb2efed2f71172d9e1e2)

### Local Development

```bash
# Clone repository
git clone https://github.com/yourusername/simple-escrow.git
cd simple-escrow

# Install dependencies
forge install

# Compile contracts
forge build

# Run tests
forge test

# Deploy to testnet
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
```

## Example Usage

```solidity
// Create escrow for agricultural contract
string[] memory milestones = ["Harvest Complete", "Quality Verified", "Shipped"];
uint256[] memory percentages = [40, 30, 30];

uint256 escrowId = escrow.createEscrow(
    "Organic Coffee Purchase",
    farmerAddress,
    buyerAddress,
    1000 * 10**6, // 1000 USDC
    milestones,
    percentages
);

// Buyer funds the escrow
escrow.fundEscrow(escrowId);

// Complete milestones as work progresses
escrow.completeMilestone(escrowId, 0); // Harvest complete
escrow.completeMilestone(escrowId, 1); // Quality verified
escrow.completeMilestone(escrowId, 2); // Shipped

// Release funds to farmer
escrow.releaseFunds(escrowId);
```

## Real-World Application

This contract powers **Nutridos Food**, a US-based dehydrated fruit import business working with Colombian suppliers. The escrow system:

- Replaces expensive remittance services (Remitly) with 1.5% fees vs 5-8%
- Provides transparent milestone tracking for international suppliers
- Ensures quality standards are met before payment release
- Builds trust between US importers and international farmers

## Security Features

- **Reentrancy Guard** - Prevents reentrancy attacks
- **Owner Access Control** - Only contract owner can manage milestones
- **Input Validation** - Comprehensive parameter checking
- **Percentage Validation** - Milestones must sum to exactly 100%
- **State Management** - Prevents double-spending and invalid operations

## API Reference

### Core Functions

#### `createEscrow()`
Creates a new escrow contract with custom milestones.

**Parameters:**
- `title` - Human-readable project description
- `farmer` - Address receiving payments
- `depositor` - Address funding the escrow
- `totalAmount` - Total escrow amount in token units
- `milestoneDescriptions` - Array of milestone descriptions
- `milestonePercents` - Array of percentages (must sum to 100)

#### `fundEscrow(uint256 escrowId)`
Funds an existing escrow. Must be called by the depositor.

#### `completeMilestone(uint256 escrowId, uint256 milestoneIndex)`
Marks a milestone as completed. Owner only.

#### `releaseFunds(uint256 escrowId)`
Releases all funds to farmer when all milestones are complete. Owner only.

### View Functions

- `getEscrow(uint256 escrowId)` - Get escrow details
- `getMilestone(uint256 escrowId, uint256 index)` - Get milestone info
- `getProgress(uint256 escrowId)` - Calculate completion percentage
- `allMilestonesCompleted(uint256 escrowId)` - Check if ready for release

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

We welcome contributions! Please see our [contributing guidelines](CONTRIBUTING.md) for details.

## Contact

**GTL Labs**
- Website: https://maxsweet1.github.io/gtl-labs-site/
- Email: gtlowe@hotmail.com
- Simple Demo: https://maxsweet1.github.io/simple-escrow/
- Advanced Demo: https://maxsweet1.github.io/proofharvest-demo/

---

Built with ❤️ for transparent agricultural trade
