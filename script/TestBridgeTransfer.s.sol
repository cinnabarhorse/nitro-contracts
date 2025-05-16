// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import 'forge-std/Script.sol';
import '../src/bridge/BridgeTransfer.sol';
import '../src/bridge/BridgeUpgrade.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

interface IUpgradeExecutor {
  function execute(
    address upgrade,
    bytes memory upgradeCallData
  ) external payable;
  function executeCall(
    address target,
    bytes memory targetCallData
  ) external payable;
}

contract TestBridgeTransfer is Script {
  // Base mainnet addresses
  address public constant BRIDGE_PROXY =
    0x9F904Fea0efF79708B37B99960e05900fE310A8E; // Replace with actual bridge proxy
  address public constant PROXY_ADMIN =
    0xaDD83738fd8a1cdCccab49e761F36ED1C93805FD; // Base's default proxy admin
  address public constant UPGRADE_EXECUTOR =
    0x01F010a5e001fe9d6940758EA5e8c777885E351e; // Base's upgrade executor
  address public constant GHST = 0xcD2F22236DD9Dfe2356D7C543161D4d260FD9BcB;
  // PC address from BridgeTransfer contract
  address public constant PC = 0x01F010a5e001fe9d6940758EA5e8c777885E351e;

  function run() external {
    console.log('Test: Starting test');
    console.log('Test: Bridge Proxy:', BRIDGE_PROXY);
    console.log('Test: Proxy Admin:', PROXY_ADMIN);
    console.log('Test: Upgrade Executor:', UPGRADE_EXECUTOR);
    console.log('Test: PC Destination:', PC);

    vm.startBroadcast();

    // Deploy new implementation
    BridgeTransfer bridgeTransfer = new BridgeTransfer();
    console.log(
      'Test: BridgeTransfer implementation deployed at:',
      address(bridgeTransfer)
    );

    // Deploy upgrade contract
    BridgeUpgrade bridgeUpgrade = new BridgeUpgrade();
    console.log('Test: BridgeUpgrade deployed at:', address(bridgeUpgrade));

    IERC20 ghst = IERC20(GHST);

    uint256 initialBridgeBalance = ghst.balanceOf(BRIDGE_PROXY);
    console.log('Test: Initial bridge GHST balance:', initialBridgeBalance);

    uint256 initialPCBalance = ghst.balanceOf(PC);
    console.log('Test: Initial PC GHST balance:', initialPCBalance);

    // Get current implementation
    address currentImpl = ProxyAdmin(PROXY_ADMIN).getProxyImplementation(
      TransparentUpgradeableProxy(payable(BRIDGE_PROXY))
    );
    console.log('Test: Current implementation:', currentImpl);

    // Get owner of proxy admin
    address proxyAdminOwner = ProxyAdmin(PROXY_ADMIN).owner();
    console.log('Test: ProxyAdmin owner:', proxyAdminOwner);

    // Impersonate the proxy admin owner to perform the upgrade
    vm.stopBroadcast();
    vm.startPrank(proxyAdminOwner);

    // Prepare transfer calldata
    bytes memory transferCalldata = abi.encodeWithSelector(
      BridgeTransfer.transfer.selector
    );

    // Perform the upgrade directly through ProxyAdmin
    console.log('Test: Executing upgrade directly');
    try
      ProxyAdmin(PROXY_ADMIN).upgradeAndCall(
        TransparentUpgradeableProxy(payable(BRIDGE_PROXY)),
        address(bridgeTransfer),
        transferCalldata
      )
    {
      console.log('Test: Upgrade successful');
    } catch Error(string memory reason) {
      console.log('Test: Upgrade failed with reason:', reason);
      revert(reason);
    } catch {
      console.log('Test: Upgrade failed with unknown error');
      revert('Upgrade failed with unknown error');
    }

    // Verify new implementation
    address newImpl = ProxyAdmin(PROXY_ADMIN).getProxyImplementation(
      TransparentUpgradeableProxy(payable(BRIDGE_PROXY))
    );
    console.log('Test: New implementation:', newImpl);
    console.log('Test: Expected implementation:', address(bridgeTransfer));
    require(newImpl == address(bridgeTransfer), 'Implementation not updated');

    uint256 finalBridgeBalance = ghst.balanceOf(BRIDGE_PROXY);
    uint256 pcBalance = ghst.balanceOf(PC);
    console.log('Test: Final bridge GHST balance:', finalBridgeBalance);
    console.log('Test: PC GHST balance:', pcBalance);

    // Calculate tokens transferred
    uint256 tokensTransferred = pcBalance - initialPCBalance;
    console.log('Test: Tokens transferred to PC:', tokensTransferred);

    vm.stopPrank();
    console.log('Test: Test completed');
  }
}
