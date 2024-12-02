//SPDX License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title Raffle
 * @author Kim Ranzani
 * @notice this contract is for creating a sample raffle contract for cyfrin updraft foundry-fondamentals course
 * @dev Implements Chainlink VRF V2.5 for random number generation and Chainlink Automation for contract automation
 */
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console2} from "forge-std/Script.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    /* errors */
    error Raffle__NotEnoughFeesToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLenght, uint256 raffleState);

    /*Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }
    /* state variables */

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;

    uint256 private immutable i_interval; //@dev lottery duration in seconds
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /*events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough fee sent!");
        // instead of storing the string in the require statement, we can use a custom error message which is cheaper (from solidity ^0.8.4)
        // we have to use a specific version of solidity here but keep in mind that from solidity v.0.8.26 you can use the custom error inside require
        // require(msg.value >= i_entranceFee,Raffle__NotEnoughFee(i_entranceFee, msg.value));
        // this is still less gass efficient than using the conditional statement below and needs to be compiled with IR pipeline via Yul
        // https://soliditylang.org/blog/2024/05/21/solidity-0.8.26-release-announcement/
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughFeesToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function checkUpkeep(bytes memory /*checkData*/ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /*performData*/ )
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256, /*_requestId*/ uint256[] calldata _randomWords) internal override {
        uint256 winnerIndex = _randomWords[0] % s_players.length;
        address payable recentWinner = s_players[winnerIndex];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(recentWinner);
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            console2.log("Transfer failed", success);
            revert Raffle__TransferFailed();
        }
        console2.log("OUT", success);
    }

    /**
     * getter functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function gerRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayersLength() external view returns (uint256) {
        return s_players.length;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
