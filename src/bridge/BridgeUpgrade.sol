// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import 'forge-std/Script.sol';

contract BridgeUpgrade {
  function upgradeAndCall(
    address proxy,
    address newImplementation,
    address proxyAdmin,
    bytes calldata data
  ) external {
    console.log('BridgeUpgrade: Starting upgrade');
    console.log('BridgeUpgrade: proxy:', proxy);
    console.log('BridgeUpgrade: newImplementation:', newImplementation);
    console.log('BridgeUpgrade: proxyAdmin:', proxyAdmin);
    console.log('BridgeUpgrade: data length:', data.length);
    console.log('BridgeUpgrade: msg.sender:', msg.sender);

    // Get current implementation
    address currentImpl = ProxyAdmin(proxyAdmin).getProxyImplementation(
      TransparentUpgradeableProxy(payable(proxy))
    );
    console.log('BridgeUpgrade: Current implementation:', currentImpl);

    // Since we're being executed via delegatecall from the UpgradeExecutor,
    // we are running in the executor's context and should have its permissions
    // This means we can directly call the ProxyAdmin
    console.log('BridgeUpgrade: Directly calling ProxyAdmin.upgradeAndCall');

    try
      ProxyAdmin(proxyAdmin).upgradeAndCall(
        TransparentUpgradeableProxy(payable(proxy)),
        newImplementation,
        data
      )
    {
      console.log('BridgeUpgrade: Upgrade successful');
    } catch Error(string memory reason) {
      console.log('BridgeUpgrade: Upgrade failed with reason:', reason);
      revert(reason);
    } catch {
      console.log('BridgeUpgrade: Upgrade failed with unknown error');
      revert('BridgeUpgrade: Upgrade failed');
    }

    // Verify new implementation
    address newImpl = ProxyAdmin(proxyAdmin).getProxyImplementation(
      TransparentUpgradeableProxy(payable(proxy))
    );
    console.log('BridgeUpgrade: New implementation:', newImpl);
    require(
      newImpl == newImplementation,
      'BridgeUpgrade: Implementation not updated'
    );
    console.log('BridgeUpgrade: Upgrade completed');
  }
}
