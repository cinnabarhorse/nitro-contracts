// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import 'forge-std/Script.sol';
import '../src/bridge/BridgeTransfer.sol';
// We don't need BridgeUpgrade.sol for this approach
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

interface IUpgradeExecutor {
    // This is the interface for 0x95E613a501a0AaB5a1C5Cbe682B29d4d300EAc3B
    function executeCall(address target, bytes memory targetCallData) external payable;
}

interface IRollup {
    function owner() external view returns (address);
}

interface IBridge {
    function rollup() external view returns (IRollup);
}

// Hypothetical interface for the contract that owns ProxyAdmin (0x95E...)
// This contract allows authorized executors to make it call other contracts.
interface IProxyAdminOwnerController {
    function executeAsSelf(address target, bytes calldata callData) external payable;
}

contract TestBridgeTransfer is Script {
  // Base mainnet addresses
  address public constant BRIDGE_PROXY =
    0x9F904Fea0efF79708B37B99960e05900fE310A8E;
  address public constant PROXY_ADMIN = // Address of the ProxyAdmin contract
    0xaDD83738fd8a1cdCccab49e761F36ED1C93805FD;
  
  // CORRECTED: UPGRADE_EXECUTOR is 0x95E... (which owns ProxyAdmin)
  // Your EOA (0x01F...) has been granted a role on this UPGRADE_EXECUTOR
  address public constant UPGRADE_EXECUTOR = 
    0x95E613a501a0AaB5a1C5Cbe682B29d4d300EAc3B;

  address public constant GHST = 0xcD2F22236DD9Dfe2356D7C543161D4d260FD9BcB;
  // PC is the destination for the transferred tokens in BridgeTransfer.sol
  // This is also your EOA which will run the script.
  address public constant PC_AND_SCRIPT_RUNNER_EOA = 0x01F010a5e001fe9d6940758EA5e8c777885E351e;

  function run() external {
    console.log('Test: Starting test');
    console.log('Test: Bridge Proxy:', BRIDGE_PROXY);
    console.log('Test: Proxy Admin:', PROXY_ADMIN);
    console.log('Test: UPGRADE_EXECUTOR (target of our EOA call):', UPGRADE_EXECUTOR);
    console.log('Test: PC Destination / Script Runner EOA:', PC_AND_SCRIPT_RUNNER_EOA);

  

    // Ensure the EOA running the script is PC_AND_SCRIPT_RUNNER_EOA
    // In a real Forge script, vm.startBroadcast() uses DefaultSender (0x1804...) or vm.envUint("PRIVATE_KEY")
    // For this to work as intended, this script should be run with vm.startBroadcast(YOUR_EOA_PRIVATE_KEY)
    // where YOUR_EOA_PRIVATE_KEY corresponds to PC_AND_SCRIPT_RUNNER_EOA
    // require(msg.sender == PC_AND_SCRIPT_RUNNER_EOA, "Script must be run by PC_AND_SCRIPT_RUNNER_EOA");

    vm.startBroadcast(PC_AND_SCRIPT_RUNNER_EOA); // All subsequent calls are from PC_AND_SCRIPT_RUNNER_EOA (0x01F...)

      // vm.prank(PC_AND_SCRIPT_RUNNER_EOA);

    BridgeTransfer bridgeTransfer = new BridgeTransfer();
    console.log(
      'Test: BridgeTransfer implementation deployed at:',
      address(bridgeTransfer)
    );

    IERC20 ghst = IERC20(GHST);
    uint256 initialBridgeBalance = ghst.balanceOf(BRIDGE_PROXY);
    uint256 initialPCBalance = ghst.balanceOf(PC_AND_SCRIPT_RUNNER_EOA);
    console.log('Test: Initial bridge GHST balance:', initialBridgeBalance);
    console.log('Test: Initial PC GHST balance:', initialPCBalance);

    address currentImpl = ProxyAdmin(PROXY_ADMIN).getProxyImplementation(
      TransparentUpgradeableProxy(payable(BRIDGE_PROXY))
    );
    console.log('Test: Current implementation:', currentImpl);

    bytes memory transferCalldata = abi.encodeWithSelector(
      BridgeTransfer.transfer.selector
    );

    // Step 1: Prepare calldata for ProxyAdmin.upgradeAndCall()
    bytes memory proxyAdminUpgradeCalldata = abi.encodeWithSelector(
      ProxyAdmin.upgradeAndCall.selector,
      TransparentUpgradeableProxy(payable(BRIDGE_PROXY)),
      address(bridgeTransfer),
      transferCalldata
    );

    // Step 2: Your EOA (0x01F...) calls UPGRADE_EXECUTOR (0x95E...) 
    // to tell it to execute the call to PROXY_ADMIN.
    console.log('Test: Your EOA calling UPGRADE_EXECUTOR to execute ProxyAdmin.upgradeAndCall');
    try IUpgradeExecutor(UPGRADE_EXECUTOR).executeCall(
      PROXY_ADMIN, 
      proxyAdminUpgradeCalldata
    ) {
      console.log('Test: Call to UPGRADE_EXECUTOR successful, ProxyAdmin upgrade should be triggered');
    } catch Error(string memory reason) {
      console.log('Test: Call to UPGRADE_EXECUTOR failed:', reason);
      revert(reason);
    } catch {
      console.log('Test: Call to UPGRADE_EXECUTOR failed with unknown error');
      revert('Call to UPGRADE_EXECUTOR failed');
    }

    address newImpl = ProxyAdmin(PROXY_ADMIN).getProxyImplementation(
      TransparentUpgradeableProxy(payable(BRIDGE_PROXY))
    );
    console.log('Test: New implementation:', newImpl);
    if (newImpl == address(bridgeTransfer)) {
      console.log('Test: Implementation successfully updated');
    } else {
      console.log('Test: WARNING - Implementation was NOT updated. Expected:', address(bridgeTransfer), 'Got:', newImpl);
    }

    uint256 finalBridgeBalance = ghst.balanceOf(BRIDGE_PROXY);
    uint256 pcBalance = ghst.balanceOf(PC_AND_SCRIPT_RUNNER_EOA);
    console.log('Test: Final bridge GHST balance:', finalBridgeBalance);
    console.log('Test: PC GHST balance:', pcBalance);
    console.log('Test: Tokens transferred to PC:', pcBalance - initialPCBalance);

    vm.stopBroadcast();
    console.log('Test: Test completed');

    console.log('');
    console.log('=== IMPORTANT PRODUCTION INSTRUCTIONS ===');
    console.log('1. Deploy BridgeTransfer implementation: ', address(bridgeTransfer));
    console.log('2. Transfer calldata (BridgeTransfer.transfer):');
    console.log(toHexString(transferCalldata));
    console.log('3. ProxyAdmin.upgradeAndCall calldata:');
    console.log(toHexString(proxyAdminUpgradeCalldata));
    console.log('4. Your EOA (0x01F010a5e001fe9d6940758EA5e8c777885E351e) calls UPGRADE_EXECUTOR (0x95E613a501a0AaB5a1C5Cbe682B29d4d300EAc3B) function executeCall with:');
    console.log('   - Target (for executeCall): ', PROXY_ADMIN);
    console.log('   - Calldata (for executeCall, which is proxyAdminUpgradeCalldata): ', toHexString(proxyAdminUpgradeCalldata));
    console.log('=== Ensure your EOA has the correct role on UPGRADE_EXECUTOR ===');
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
