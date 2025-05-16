// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import 'forge-std/Script.sol';
import '../src/bridge/BridgeTransfer.sol';
import '../src/bridge/BridgeUpgrade.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../src/mocks/UpgradeExecutorMock.sol';
contract BridgeTransferScript is Script {
  // Base mainnet addresses
  address public constant BRIDGE_PROXY =
    0x9F904Fea0efF79708B37B99960e05900fE310A8E; // Replace with actual bridge proxy
  address public constant PROXY_ADMIN =
    0xaDD83738fd8a1cdCccab49e761F36ED1C93805FD; // Base's default proxy admin
  address public constant UPGRADE_EXECUTOR =
    0x95E613a501a0AaB5a1C5Cbe682B29d4d300EAc3B; // Base's upgrade executor
  address public constant GHST = 0xcD2F22236DD9Dfe2356D7C543161D4d260FD9BcB;

  function run() external {
    string memory baseRpc = vm.envString('BASE_RPC');

    //Create a local fork of base mainnet
    vm.createSelectFork(baseRpc);

    //PK of new proxy owner
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    // Deploy new implementation
    BridgeTransfer bridgeTransfer = new BridgeTransfer();
    console.log(
      'BridgeTransfer implementation deployed at:',
      address(bridgeTransfer)
    );

    // Deploy upgrade contract
    BridgeUpgrade bridgeUpgrade = new BridgeUpgrade();
    console.log('BridgeUpgrade deployed at:', address(bridgeUpgrade));

    IERC20 ghst = IERC20(GHST);

    uint256 initialBridgeBalance = ghst.balanceOf(BRIDGE_PROXY);
    console.log('Initial bridge GHST balance:', initialBridgeBalance);

    bytes memory transferCalldata = abi.encodeWithSelector(
      BridgeTransfer.transfer.selector
    );

    bytes memory upgradeCallData = abi.encodeWithSelector(
      BridgeUpgrade.upgradeAndCall.selector,
      BRIDGE_PROXY,
      address(bridgeTransfer),
      PROXY_ADMIN,
      transferCalldata
    );

    // Execute upgrade via UpgradeExecutor

    UpgradeExecutorMock(UPGRADE_EXECUTOR).execute(
      address(bridgeUpgrade),
      upgradeCallData
    );

    uint256 finalBridgeBalance = ghst.balanceOf(BRIDGE_PROXY);
    uint256 adminBalance = ghst.balanceOf(PROXY_ADMIN);
    console.log('Final bridge GHST balance:', finalBridgeBalance);
    console.log('Admin GHST balance:', adminBalance);

    vm.stopBroadcast();
  }
}
