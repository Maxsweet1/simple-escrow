// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SimpleEscrow
 * @notice Owner-controlled milestone-based escrow for managed payment services
 * @dev Designed for GTL Labs managed escrow business model
 */
contract SimpleEscrow is ReentrancyGuard {
    // ── STATE VARIABLES ──────────────────────────────────────────────────────────

    address public owner;
    IERC20 public immutable token; // USDC or other stablecoin

    uint256 public nextEscrowId;

    struct Milestone {
        string description; // "Land preparation completed"
        uint256 percent; // 25 (represents 25%)
        bool completed; // true when milestone is done
        uint256 completedAt; // timestamp when completed
    }

    struct EscrowContract {
        string title; // "Organic Wheat Production Contract"
        address farmer; // Who gets paid
        address depositor; // Who deposited the funds
        uint256 totalAmount; // Total USDC deposited
        Milestone[] milestones; // Array of milestones
        bool funded; // true when depositor has funded
        bool completed; // true when all funds released
        bool refunded; // true if refunded instead
        uint256 createdAt; // timestamp of creation
        uint256 completedAt; // timestamp when finished
    }

    mapping(uint256 => EscrowContract) public escrows;

    // ── EVENTS ───────────────────────────────────────────────────────────────────

    event EscrowCreated(
        uint256 indexed escrowId,
        string title,
        address indexed farmer,
        address indexed depositor,
        uint256 totalAmount
    );

    event EscrowFunded(uint256 indexed escrowId, uint256 amount);

    event MilestoneCompleted(
        uint256 indexed escrowId,
        uint256 milestoneIndex,
        string description
    );

    event FundsReleased(
        uint256 indexed escrowId,
        address indexed farmer,
        uint256 amount
    );

    event EscrowRefunded(
        uint256 indexed escrowId,
        address indexed depositor,
        uint256 amount
    );

    // ── MODIFIERS ────────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "SimpleEscrow: Not the owner");
        _;
    }

    modifier escrowExists(uint256 escrowId) {
        require(escrowId < nextEscrowId, "SimpleEscrow: Escrow does not exist");
        _;
    }

    // ── CONSTRUCTOR ──────────────────────────────────────────────────────────────

    constructor(address _token) {
        require(_token != address(0), "SimpleEscrow: Invalid token address");
        owner = msg.sender;
        token = IERC20(_token);
    }

    // ── OWNER FUNCTIONS (GTL Labs manages these) ─────────────────────────────────

    /**
     * @notice Create a new escrow contract (Owner only - GTL Labs creates these)
     * @param title Project title like "Organic Wheat Production Contract"
     * @param farmer Address who will receive payments
     * @param depositor Address who will fund the escrow
     * @param totalAmount Total USDC amount for the project
     * @param milestoneDescriptions Array of milestone descriptions
     * @param milestonePercents Array of percentages (must sum to 100)
     */
    function createEscrow(
        string calldata title,
        address farmer,
        address depositor,
        uint256 totalAmount,
        string[] calldata milestoneDescriptions,
        uint256[] calldata milestonePercents
    ) external onlyOwner returns (uint256 escrowId) {
        require(farmer != address(0), "SimpleEscrow: Invalid farmer address");
        require(
            depositor != address(0),
            "SimpleEscrow: Invalid depositor address"
        );
        require(totalAmount > 0, "SimpleEscrow: Amount must be greater than 0");
        require(bytes(title).length > 0, "SimpleEscrow: Title cannot be empty");
        require(
            milestoneDescriptions.length == milestonePercents.length,
            "SimpleEscrow: Mismatched milestone arrays"
        );
        require(
            milestoneDescriptions.length > 0,
            "SimpleEscrow: Must have milestones"
        );

        // Verify percentages sum to 100
        uint256 totalPercent;
        for (uint256 i = 0; i < milestonePercents.length; i++) {
            require(
                milestonePercents[i] > 0,
                "SimpleEscrow: Milestone percent must be > 0"
            );
            totalPercent += milestonePercents[i];
        }
        require(
            totalPercent == 100,
            "SimpleEscrow: Milestones must sum to 100%"
        );

        escrowId = nextEscrowId++;
        EscrowContract storage escrow = escrows[escrowId];

        escrow.title = title;
        escrow.farmer = farmer;
        escrow.depositor = depositor;
        escrow.totalAmount = totalAmount;
        escrow.createdAt = block.timestamp;

        // Add milestones
        for (uint256 i = 0; i < milestoneDescriptions.length; i++) {
            escrow.milestones.push(
                Milestone({
                    description: milestoneDescriptions[i],
                    percent: milestonePercents[i],
                    completed: false,
                    completedAt: 0
                })
            );
        }

        emit EscrowCreated(escrowId, title, farmer, depositor, totalAmount);
        return escrowId;
    }

    /**
     * @notice Mark a milestone as completed (Owner only - GTL Labs manages progress)
     * @param escrowId The escrow contract ID
     * @param milestoneIndex Which milestone to complete (0-based)
     */
    function completeMilestone(
        uint256 escrowId,
        uint256 milestoneIndex
    ) external onlyOwner escrowExists(escrowId) {
        EscrowContract storage escrow = escrows[escrowId];
        require(escrow.funded, "SimpleEscrow: Escrow not funded yet");
        require(!escrow.completed, "SimpleEscrow: Escrow already completed");
        require(!escrow.refunded, "SimpleEscrow: Escrow was refunded");
        require(
            milestoneIndex < escrow.milestones.length,
            "SimpleEscrow: Invalid milestone"
        );
        require(
            !escrow.milestones[milestoneIndex].completed,
            "SimpleEscrow: Milestone already completed"
        );

        escrow.milestones[milestoneIndex].completed = true;
        escrow.milestones[milestoneIndex].completedAt = block.timestamp;

        emit MilestoneCompleted(
            escrowId,
            milestoneIndex,
            escrow.milestones[milestoneIndex].description
        );
    }

    /**
     * @notice Release all remaining funds to farmer (Owner only - GTL Labs controls payments)
     * @dev Can only be called when ALL milestones are completed
     * @param escrowId The escrow contract ID
     */
    function releaseFunds(
        uint256 escrowId
    ) external onlyOwner escrowExists(escrowId) nonReentrant {
        EscrowContract storage escrow = escrows[escrowId];
        require(escrow.funded, "SimpleEscrow: Escrow not funded");
        require(!escrow.completed, "SimpleEscrow: Already completed");
        require(!escrow.refunded, "SimpleEscrow: Already refunded");

        // Verify ALL milestones are completed
        for (uint256 i = 0; i < escrow.milestones.length; i++) {
            require(
                escrow.milestones[i].completed,
                "SimpleEscrow: Not all milestones completed"
            );
        }

        escrow.completed = true;
        escrow.completedAt = block.timestamp;

        // Transfer all funds to farmer
        require(
            token.transfer(escrow.farmer, escrow.totalAmount),
            "SimpleEscrow: Transfer failed"
        );

        emit FundsReleased(escrowId, escrow.farmer, escrow.totalAmount);
    }

    /**
     * @notice Refund the depositor (Owner only - GTL Labs handles disputes)
     * @param escrowId The escrow contract ID
     */
    function refundEscrow(
        uint256 escrowId
    ) external onlyOwner escrowExists(escrowId) nonReentrant {
        EscrowContract storage escrow = escrows[escrowId];
        require(escrow.funded, "SimpleEscrow: Escrow not funded");
        require(!escrow.completed, "SimpleEscrow: Already completed");
        require(!escrow.refunded, "SimpleEscrow: Already refunded");

        escrow.refunded = true;
        escrow.completedAt = block.timestamp;

        // Return funds to depositor
        require(
            token.transfer(escrow.depositor, escrow.totalAmount),
            "SimpleEscrow: Refund failed"
        );

        emit EscrowRefunded(escrowId, escrow.depositor, escrow.totalAmount);
    }

    // ── PUBLIC FUNCTIONS (Clients can fund their escrows) ───────────────────────

    /**
     * @notice Fund an escrow contract (Depositor funds their own escrow)
     * @dev Depositor must approve this contract for totalAmount of tokens first
     * @param escrowId The escrow contract ID to fund
     */
    function fundEscrow(
        uint256 escrowId
    ) external escrowExists(escrowId) nonReentrant {
        EscrowContract storage escrow = escrows[escrowId];
        require(
            msg.sender == escrow.depositor,
            "SimpleEscrow: Only depositor can fund"
        );
        require(!escrow.funded, "SimpleEscrow: Already funded");
        require(!escrow.refunded, "SimpleEscrow: Cannot fund refunded escrow");

        escrow.funded = true;

        // Transfer tokens from depositor to this contract
        require(
            token.transferFrom(msg.sender, address(this), escrow.totalAmount),
            "SimpleEscrow: Funding transfer failed"
        );

        emit EscrowFunded(escrowId, escrow.totalAmount);
    }

    // ── VIEW FUNCTIONS ───────────────────────────────────────────────────────────

    /**
     * @notice Get basic escrow details
     */
    function getEscrow(
        uint256 escrowId
    )
        external
        view
        escrowExists(escrowId)
        returns (
            string memory title,
            address farmer,
            address depositor,
            uint256 totalAmount,
            bool funded,
            bool completed,
            bool refunded,
            uint256 createdAt,
            uint256 completedAt
        )
    {
        EscrowContract storage escrow = escrows[escrowId];
        return (
            escrow.title,
            escrow.farmer,
            escrow.depositor,
            escrow.totalAmount,
            escrow.funded,
            escrow.completed,
            escrow.refunded,
            escrow.createdAt,
            escrow.completedAt
        );
    }

    /**
     * @notice Get milestone details for an escrow
     */
    function getMilestone(
        uint256 escrowId,
        uint256 milestoneIndex
    )
        external
        view
        escrowExists(escrowId)
        returns (
            string memory description,
            uint256 percent,
            bool completed,
            uint256 completedAt
        )
    {
        EscrowContract storage escrow = escrows[escrowId];
        require(
            milestoneIndex < escrow.milestones.length,
            "SimpleEscrow: Invalid milestone index"
        );

        Milestone storage milestone = escrow.milestones[milestoneIndex];
        return (
            milestone.description,
            milestone.percent,
            milestone.completed,
            milestone.completedAt
        );
    }

    /**
     * @notice Get number of milestones for an escrow
     */
    function getMilestoneCount(
        uint256 escrowId
    ) external view escrowExists(escrowId) returns (uint256) {
        return escrows[escrowId].milestones.length;
    }

    /**
     * @notice Calculate progress percentage for an escrow
     */
    function getProgress(
        uint256 escrowId
    ) external view escrowExists(escrowId) returns (uint256 progressPercent) {
        EscrowContract storage escrow = escrows[escrowId];

        for (uint256 i = 0; i < escrow.milestones.length; i++) {
            if (escrow.milestones[i].completed) {
                progressPercent += escrow.milestones[i].percent;
            }
        }

        return progressPercent;
    }

    /**
     * @notice Check if all milestones are completed
     */
    function allMilestonesCompleted(
        uint256 escrowId
    ) external view escrowExists(escrowId) returns (bool) {
        EscrowContract storage escrow = escrows[escrowId];

        for (uint256 i = 0; i < escrow.milestones.length; i++) {
            if (!escrow.milestones[i].completed) {
                return false;
            }
        }

        return true;
    }

    /**
     * @notice Get total number of escrows created
     */
    function getTotalEscrows() external view returns (uint256) {
        return nextEscrowId;
    }
}
