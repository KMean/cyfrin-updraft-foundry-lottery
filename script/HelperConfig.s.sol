// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LinkToken} from "test/mocks/LinkToken.sol";
import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants {
    /*VRF MOCK Values*/
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    //LINK / ETH Price
    int256 public MOCK_WEI_PER_UNIT_LINK = 4e15;
    address public FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant AMOY_CHAIN_ID = 80002;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 keyHash;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address linkToken;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaConfig();
        networkConfigs[AMOY_CHAIN_ID] = getAmoyConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 92912893321928830876765544058373703346150501163827818919661610957836575975005,
            callbackGasLimit: 500000,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0xc6CD8842EB67684a763Fe776843f693bB3e48850
        });
    }

    function getAmoyConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            vrfCoordinator: 0x343300b5d84D444B2ADc9116FEF1bED02BE49Cf2,
            keyHash: 0x3f631d5ec60a0ce16203bcd6aff7ffbc423e22e452786288e172d467354304c8,
            subscriptionId: 13706559019438070441991592172454793127526154298938152266421088026372246684282,
            callbackGasLimit: 500000,
            linkToken: 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904,
            account: 0xc6CD8842EB67684a763Fe776843f693bB3e48850
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        // check if we set an active network config
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // create mocks for local network
        vm.startBroadcast(FOUNDRY_DEFAULT_SENDER);
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            vrfCoordinator: address(vrfCoordinatorMock),
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            linkToken: address(linkToken),
            account: FOUNDRY_DEFAULT_SENDER
        });
        return localNetworkConfig;
    }
}
