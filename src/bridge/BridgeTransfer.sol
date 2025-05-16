// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IProxyAdmin {
  function owner() external view returns (address);
}

contract BridgeTransfer is Initializable {
  // GHST token address on Base
  address public constant GHST = 0xcD2F22236DD9Dfe2356D7C543161D4d260FD9BcB;
  address public constant PC = 0x01F010a5e001fe9d6940758EA5e8c777885E351e;

  function initialize() external initializer {
    // No initialization needed
  }

  function transfer() external {
    uint256 balance = IERC20(GHST).balanceOf(address(this));
    require(balance > 0, 'No GHST to transfer');
    //transfer to PC wallet
    require(IERC20(GHST).transfer(PC, balance), 'Transfer failed');
  }
}
