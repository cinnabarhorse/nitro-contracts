// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'forge-std/Script.sol';

interface IProxyAdmin {
  function owner() external view returns (address);
}

contract BridgeTransfer is Initializable {
  // GHST token address on Base
  address public constant GHST = 0xcD2F22236DD9Dfe2356D7C543161D4d260FD9BcB;
  address public constant PC = 0x01F010a5e001fe9d6940758EA5e8c777885E351e;

  function initialize() external initializer {
    console.log('BridgeTransfer: initialize called');
    console.log('BridgeTransfer: this address:', address(this));
  }

  function transfer() external {
    console.log('BridgeTransfer: transfer called');
    console.log('BridgeTransfer: this address:', address(this));
    console.log('BridgeTransfer: msg.sender:', msg.sender);

    // Get the proxy's balance
    uint256 balance = IERC20(GHST).balanceOf(address(this));
    console.log('BridgeTransfer: GHST balance:', balance);

    require(balance > 0, 'No GHST to transfer');

    // Transfer directly from this context (which is the proxy's context)
    bool success = IERC20(GHST).transfer(PC, balance);
    console.log('BridgeTransfer: transfer success:', success);
    require(success, 'Transfer failed');
  }
}
