// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is CodeConstants, Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 public entranceFee;
    uint256 public interval;
    address public vrfCoordinator;
    bytes32 public keyHash;
    uint256 public subscriptionId;
    uint32 public callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        keyHash = config.keyHash;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
    }

    function testRaffleInitializesInOpenState() public view {
        assertEq(uint256(raffle.gerRaffleState()), uint256(Raffle.RaffleState.OPEN));
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/

    function testRaffleRevertsWhenNotEnoughFeesToEnterRaffle() public {
        //Arrange
        vm.prank(PLAYER);
        //Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughFeesToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        //Assert
        assertEq(address(raffle.getPlayer(0)), PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECKUPKEEP
    //////////////////////////////////////////////////////////////*/

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsFalseIsRaffleIsNotOpen() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfThereAreNoPlayers() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                          CHECK UPKEEP NEEDED
    //////////////////////////////////////////////////////////////*/

    function testCheckUpkeepNeededReturnsTrueIfTimeHasPassed() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert
        assert(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                          CHECK PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act / Assert

        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfUpkeepNotNeeded() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        //vm.expectRevert(Raffle.Raffle__UpkeepNotNeeded.selector);
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, 0, 0, 0)); //revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // 0 = open, 1 = calculating
    }

    /*//////////////////////////////////////////////////////////////
                           FULFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequest)
        public
        raffleEntered
        skipFork
    {
        //Arrange/Act/Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequest, address(raffle));
    }

    function testFulfillrandomwordsPicksAWinnerResetsAndSendsMoney() public raffleEntered {
        // Arrange
        uint256 additionalEntrances = 3; // so 4 people total since the raffleEntered modifier has PLAYER enter the raffle first.
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            // this is a way to turn any uint into an address. this is like saying address(1)
            address newPlayer = address(uint160(i));
            // gives newPlayer ether and makes the next transaction come from NewPlayer. `hoax` is a cheatcode that combines vm.deal and vm.prank. Hoax only works with uint160s.
            hoax(newPlayer, 1 ether);
            // newPlayer enters raffle
            raffle.enterRaffle{value: entranceFee}();
        }
        // get the timestamp of when the contract was deployed
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        // record all logs(including event data) from the next call
        vm.recordLogs();
        // call performUpkeep
        raffle.performUpkeep("");
        // take the recordedLogs from `performUpkeep` and stick them into the entries array
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // entry 0  is for the VRF coordinator
        // entry 1 is for our event data
        // topic 0 is always resevered for
        // topic 1 is for our indexed parameter
        bytes32 requestId = entries[1].topics[1];
        // call fulfillRandomWords from the vrfCoordinator and we are inputting the requestId that we got from the logs when we called performUpkeep; and we are also inputting the raffle contract since its the consumer(fulfillRandomWords function takes parameters from the VRFCoordinatorV2_5Mock ).
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle)); // we typecast the requestId back into a uint256 since it was stored as bytes
        // Assert
        // saving the recent winner from the getter function in raffle.sol to a variable named recentWinner
        address recentWinner = raffle.getRecentWinner();
        // saving the raffleState from the getter function in raffle.sol to a variable type RaffleState named raffleState
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // saves the balance of the recentWinner to a variable named winnerBalance
        uint256 winnerBalance = recentWinner.balance; // `balance` is a solidity keyword
        // fulfillRandomWords updates the timestamp in raffle.sol, so by calling getLastTimeStamp here, we get the new timeStamp that was saved.
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        // since there is 4 people in this raffle, it muliplies the number of players times their entrance fee to get how much the prize is worth.
        uint256 prize = entranceFee * (additionalEntrances + 1);

        // Assert

        assert(recentWinner == expectedWinner);
        // assert that the raffle restarted
        assert(raffleState == Raffle.RaffleState.OPEN);
        // assert(uint256(raffleState) == 0); // This is the same as the line above since `OPEN` in index 0 of the enum in Raffle.sol.

        // assert that the winners received the funds/prize
        assert(winnerBalance == winnerStartingBalance + prize);

        assert(endingTimeStamp > startingTimeStamp);
    }

    function testFulfillRandomWordsTransferFailureBranch() public skipFork {
        // Arrange
        RevertOnReceive player = new RevertOnReceive();
        hoax(address(player), 1 ether);
        raffle.enterRaffle{value: 1 ether}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Perform upkeep to emit a requestId
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        vm.expectRevert();
        // Act
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        // Assert: The player's balance should remain unchanged
        assertEq(address(player).balance, 0 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function testGetEntranceFeeReturnsEntranceFee() public view {
        //Arrange
        //Act
        uint256 fee = raffle.getEntranceFee();
        //Assert
        assertEq(fee, entranceFee);
    }

    function testgetPlayersLengthReturnsNumberOfPlayers() public raffleEntered {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        //Act
        uint256 length = raffle.getPlayersLength();
        //Assert
        assertEq(length, 2);
    }
}

contract RevertOnReceive {
    receive() external payable {
        revert("Forced failure");
    }
}
