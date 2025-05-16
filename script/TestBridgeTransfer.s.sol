// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import 'forge-std/Script.sol';
import '../src/bridge/BridgeTransfer.sol'; 
// No longer importing BridgeUpgradeHelper.sol
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

// Interface for the UPGRADE_EXECUTOR contract (0x95E...)
interface IUpgradeExecutor {
    function executeCall(address target, bytes memory targetCallData) external payable;
}

contract TestBridgeTransfer is Script {
  // Base mainnet addresses
  address public constant BRIDGE_PROXY =
    0x9F904Fea0efF79708B37B99960e05900fE310A8E;
  address public constant PROXY_ADMIN = 
    0xaDD83738fd8a1cdCccab49e761F36ED1C93805FD;
  address public constant UPGRADE_EXECUTOR = // This is the 0x95E... contract
    0x95E613a501a0AaB5a1C5Cbe682B29d4d300EAc3B;
  address public constant GHST = 0xcD2F22236DD9Dfe2356D7C543161D4d260FD9BcB;
  address public constant PC_AND_SCRIPT_RUNNER_EOA = // Your EOA, which has EXECUTOR_ROLE on UPGRADE_EXECUTOR
    0x01F010a5e001fe9d6940758EA5e8c777885E351e;

  function run() external {
 
    // Ensure the EOA running the script is PC_AND_SCRIPT_RUNNER_EOA
    // This is important because this EOA must have the EXECUTOR_ROLE on UPGRADE_EXECUTOR
    // require(msg.sender == PC_AND_SCRIPT_RUNNER_EOA, "Script must be run by PC_AND_SCRIPT_RUNNER_EOA");

    vm.startBroadcast(PC_AND_SCRIPT_RUNNER_EOA); // All subsequent calls are from PC_AND_SCRIPT_RUNNER_EOA

    // 1. Deploy the new BridgeTransfer implementation contract
    BridgeTransfer newBridgeTransferImplementation = new BridgeTransfer();
    address newImplementationAddress = address(newBridgeTransferImplementation);
    console.log(
      'Test: New BridgeTransfer implementation deployed at:',
      newImplementationAddress
    );

    IERC20 ghst = IERC20(GHST);
    uint256 initialBridgeBalance = ghst.balanceOf(BRIDGE_PROXY);
    uint256 initialPCBalance = ghst.balanceOf(PC_AND_SCRIPT_RUNNER_EOA);
    console.log('Test: Initial bridge GHST balance:', initialBridgeBalance);
    console.log('Test: Initial PC GHST balance:', initialPCBalance);

    address currentImplBefore = ProxyAdmin(PROXY_ADMIN).getProxyImplementation(
      TransparentUpgradeableProxy(payable(BRIDGE_PROXY))
    );
    console.log('Test: Current BridgeProxy implementation (before):', currentImplBefore);

    // 2. Prepare calldata for BridgeTransfer.transfer() (this will be part of upgradeAndCall)
    bytes memory transferCalldata = abi.encodeWithSelector(
      BridgeTransfer.transfer.selector
    );
    console.log('Test: Prepared BridgeTransfer.transfer() calldata:', toHexString(transferCalldata));

    // 3. Prepare calldata for ProxyAdmin.upgradeAndCall()
    // This is the data that UPGRADE_EXECUTOR will send to PROXY_ADMIN
    bytes memory proxyAdminUpgradeCalldata = abi.encodeWithSelector(
      ProxyAdmin.upgradeAndCall.selector,
      TransparentUpgradeableProxy(payable(BRIDGE_PROXY)), // The proxy to upgrade
      newImplementationAddress,                         // The new implementation
      transferCalldata                                  // The data for the subsequent call (BridgeTransfer.transfer)
    );
    console.log('Test: Prepared ProxyAdmin.upgradeAndCall() calldata:', toHexString(proxyAdminUpgradeCalldata));

    // 4. Your EOA (PC_AND_SCRIPT_RUNNER_EOA) calls executeCall on UPGRADE_EXECUTOR
    console.log('Test: EOA calling UPGRADE_EXECUTOR.executeCall targeting PROXY_ADMIN...');
    try IUpgradeExecutor(UPGRADE_EXECUTOR).executeCall(
        PROXY_ADMIN,                // Target for UPGRADE_EXECUTOR to call
        proxyAdminUpgradeCalldata   // Data for the call to PROXY_ADMIN
    ) {
      console.log('Test: UPGRADE_EXECUTOR.executeCall successful');
    } catch Error(string memory reason) {
      console.log('Test: UPGRADE_EXECUTOR.executeCall failed:', reason);
      revert(reason);
    } catch (bytes memory lowLevelData) {
        string memory reason = "Test: UPGRADE_EXECUTOR.executeCall failed with low-level data";
        if (lowLevelData.length >= 4) { 
            bytes4 selector;
            assembly {
                selector := mload(add(lowLevelData, 0x20))
            }
            if (selector == bytes4(keccak256("Error(string)"))) {
                if (lowLevelData.length >= 68) { 
                    bytes memory revertData = new bytes(lowLevelData.length - 4);
                    for (uint i = 0; i < revertData.length; i++) {
                        revertData[i] = lowLevelData[i + 4];
                    }
                    reason = abi.decode(revertData, (string)); 
                }
            }
        }
        console.log(reason);
        revert(reason);
    }

    address currentImplAfter = ProxyAdmin(PROXY_ADMIN).getProxyImplementation(
      TransparentUpgradeableProxy(payable(BRIDGE_PROXY))
    );
    console.log('Test: Current BridgeProxy implementation (after):', currentImplAfter);
    
    if (currentImplAfter == newImplementationAddress) {
        console.log('Test: Implementation successfully updated to:', newImplementationAddress);
    } else {
        console.log('Test: WARNING - Implementation was NOT updated correctly! Expected:', newImplementationAddress, 'Got:', currentImplAfter);
    }

    uint256 finalBridgeBalance = ghst.balanceOf(BRIDGE_PROXY);
    uint256 pcBalance = ghst.balanceOf(PC_AND_SCRIPT_RUNNER_EOA);
    console.log('Test: Final bridge GHST balance:', finalBridgeBalance);
    console.log('Test: PC GHST balance:', pcBalance);
    console.log('Test: Tokens transferred to PC:', pcBalance - initialPCBalance);

    vm.stopBroadcast();
    console.log('Test: Test completed');
    
    console.log('\n=== PRODUCTION INSTRUCTIONS ===');
    console.log('1. Deploy new BridgeTransfer contract. New Implementation Address:', newImplementationAddress);
    console.log('2. Calldata for BridgeTransfer.transfer():', toHexString(transferCalldata));
    console.log('3. Calldata for ProxyAdmin.upgradeAndCall(proxy, newImplementation, transferCalldata):', toHexString(proxyAdminUpgradeCalldata));
    console.log('4. FROM YOUR EOA (', PC_AND_SCRIPT_RUNNER_EOA, ') which has EXECUTOR_ROLE:');
    console.log('   Call UPGRADE_EXECUTOR (', UPGRADE_EXECUTOR, ') method executeCall with:');
    console.log('     target: ', PROXY_ADMIN);
    console.log('     targetCallData: ', toHexString(proxyAdminUpgradeCalldata));
  }

  function toHexString(bytes memory data) private pure returns (string memory) {
    bytes memory alphabet = "0123456789abcdef";
    bytes memory str = new bytes(2 + data.length * 2);
    str[0] = '0';
    str[1] = 'x';
    for (uint i = 0; i < data.length; i++) {
      str[2 + i * 2] = alphabet[uint8(data[i] >> 4)];
      str[2 + i * 2 + 1] = alphabet[uint8(data[i] & 0x0f)];
    }
    return string(str);
  }
}
