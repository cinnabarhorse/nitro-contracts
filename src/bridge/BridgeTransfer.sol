// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract BridgeTransfer is Initializable {
  // GHST token address on Base
  address public constant GHST = 0xcD2F22236DD9Dfe2356D7C543161D4d260FD9BcB;
  // PC_DESTINATION is where the tokens will be sent. This is your EOA.
  address public constant PC_DESTINATION =
    0x01F010a5e001fe9d6940758EA5e8c777885E351e;

  event BridgeTransferInitialized(address indexed contractAddress);
  event TokenTransferAttempted(
    address indexed from,
    address indexed to,
    uint256 amount
  );
  event TokenTransferSuccessful(
    address indexed from,
    address indexed to,
    uint256 amount
  );
  event TokenTransferFailed(
    address indexed from,
    address indexed to,
    uint256 amount,
    string reason
  );

  // solhint-disable-next-line no-empty-blocks
  function initialize() external initializer {
    emit BridgeTransferInitialized(address(this));
  }

  function transfer() external {
    uint256 balance = IERC20(GHST).balanceOf(address(this));
    emit TokenTransferAttempted(address(this), PC_DESTINATION, balance);

    if (balance == 0) {
      emit TokenTransferFailed(
        address(this),
        PC_DESTINATION,
        0,
        'No GHST to transfer'
      );
      revert('BridgeTransfer: No GHST to transfer');
    }

    bool success = IERC20(GHST).transfer(PC_DESTINATION, balance);

    if (success) {
      emit TokenTransferSuccessful(address(this), PC_DESTINATION, balance);
    } else {
      // Note: ERC20 transfer itself doesn't usually return a reason string on failure.
      // The require below will trigger if success is false.
      emit TokenTransferFailed(
        address(this),
        PC_DESTINATION,
        balance,
        'ERC20 transfer call failed'
      );
    }
    require(success, 'BridgeTransfer: ERC20 transfer failed');
  }
}
