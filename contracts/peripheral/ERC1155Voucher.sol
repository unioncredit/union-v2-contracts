//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IUserManager} from "../interfaces/IUserManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

/// @author Union
/// @title ERC1155Voucher
/// @dev Voucher contract that takes ERC1155 deposits and gives a vouch
contract ERC1155Voucher is Ownable, IERC1155Receiver {
    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */

    // @notice UserManager contract address
    address public immutable USER_MANAGER;

    // @notice UserManager staking token eg (DAI)
    address public immutable STAKING_TOKEN;

    /// @notice Amount of claimable trust
    uint256 public trustAmount;

    /// @notice Token address to isValid
    mapping(address => bool) public isValidToken;

    /* -------------------------------------------------------------------
      Events 
    ------------------------------------------------------------------- */

    /// @notice Fired when a vouch is claimed
    /// @param sender Msg sender
    event VouchClaimed(address sender);

    /// @notice Set trust amount
    /// @param amount Trust amount
    event SetTrustAmount(uint256 amount);

    /// @notice Exit
    /// @param amount Amount unstaked
    event Exit(uint256 amount);

    /// @notice Set is valid
    /// @param token Address of token
    /// @param isValid Is the token valid
    event SetIsValidToken(address token, bool isValid);

    /* -------------------------------------------------------------------
      Constructor 
    ------------------------------------------------------------------- */

    /// @param _userManager UserManager address
    /// @param _trustAmount Amount of trust to give
    constructor(address _userManager, uint256 _trustAmount) {
        address stakingToken = IUserManager(_userManager).stakingToken();

        IERC20(stakingToken).approve(_userManager, 0);
        IERC20(stakingToken).approve(_userManager, type(uint256).max);

        STAKING_TOKEN = stakingToken;
        USER_MANAGER = _userManager;
        trustAmount = _trustAmount;
    }

    /* -------------------------------------------------------------------
      Setters 
    ------------------------------------------------------------------- */

    /// @notice Set the max amount claimable for a token
    /// @param amount The trust amount
    function setTrustAmount(uint256 amount) external onlyOwner {
        trustAmount = amount;
        emit SetTrustAmount(amount);
    }

    /// @notice Set if a token is valid
    /// @param token Address of token
    /// @param isValid is the token valid
    function setIsValid(address token, bool isValid) external onlyOwner {
        isValidToken[token] = isValid;
        emit SetIsValidToken(token, isValid);
    }

    /* -------------------------------------------------------------------
      Claim Functions 
    ------------------------------------------------------------------- */

    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @dev Handles the receipt of a single ERC1155 token type. This function is
    /// @param operator The address which initiated the transfer (i.e. msg.sender)
    /// @param from The address which previously owned the token
    /// @param id The ID of the token being transferred
    /// @param value The amount of tokens being transferred
    /// @param data Additional data with no specified format
    /// @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        require(isValidToken[msg.sender], "!valid token");
        _vouchFor(from);
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    /// @dev Handles the receipt of a multiple ERC1155 token types.
    /// @param operator The address which initiated the batch transfer (i.e. msg.sender)
    /// @param from The address which previously owned the token
    /// @param ids An array containing ids of each token being transferred (order and length must match values array)
    /// @param values An array containing amounts of each token being transferred (order and length must match ids array)
    /// @param data Additional data with no specified format
    /// @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {
        _vouchFor(from);
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

    /// @notice Claim vouch from this contract
    /// @param acc Account to vouch for
    function _vouchFor(address acc) internal {
        IUserManager(USER_MANAGER).updateTrust(acc, uint96(trustAmount));
        emit VouchClaimed(acc);
    }

    /* -------------------------------------------------------------------
      Union Functions 
    ------------------------------------------------------------------- */

    /// @notice Stake into the UserManager contract
    function stake() external {
        uint256 balance = IERC20(STAKING_TOKEN).balanceOf(address(this));
        IUserManager(USER_MANAGER).stake(uint96(balance));
    }

    /// @notice Exit. Unstake the max unstakable from the userManager
    function exit() external onlyOwner {
        uint256 stakeAmount = IUserManager(USER_MANAGER).getStakerBalance(address(this));
        uint256 locked = IUserManager(USER_MANAGER).getTotalLockedStake(address(this));
        uint256 maxUnstake = stakeAmount - locked;
        IUserManager(USER_MANAGER).unstake(uint96(maxUnstake));
        emit Exit(maxUnstake);
    }

    /// @notice Transfer ERC20 tokens
    /// @param token Token address
    /// @param to Token receiver
    /// @param amount Amount of tokens to send
    function transferERC20(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }
}
