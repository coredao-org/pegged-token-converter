//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PeggedTokenConverter
 * @author CoreDAO
 * @notice A bidirectional ERC20 token converter.
 * @dev This converter:
 *      - Allows owner to deposit tokens
 *      - Enables users to convert tokens at 1:1 ratio
 *      - Allows owner to withdraw tokens
 */
contract PeggedTokenConverter is
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;

    IERC20 public tokenA;
    IERC20 public tokenB;
    bool public bidirectional;

    event Deposit(address token, uint256 amount);
    event Withdraw(address token, uint256 amount);
    event Convert(address user, address inputToken, uint256 amount);
    event ToggleBidirectional(bool currStatus);
    
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the converter
     * @dev Sets up the converter's owner, input token, and output token
     * @param _owner The owner of the converter
     * @param _tokenA Token A contract address
     * @param _tokenB Token B contract address
     */
    function initialize(address _owner, address _tokenA, address _tokenB) external initializer {
        __Ownable_init(_owner);
        require(_tokenA != _tokenB, "Must be different tokens");
        require(ERC20(_tokenA).decimals() == ERC20(_tokenB).decimals(), "Different decimal count");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    /**
     * @dev Supports the conversion of tokens at a 1:1 ratio
     * @param _token The input token address
     * @param _amount The amount to be converted
     */
    function convert(address _token, uint256 _amount) public {
        require(_token == address(tokenA) || _token == address(tokenB), "Invalid token type");
        require(_amount > 0, "No zero convert");
        if(!bidirectional && _token != address(tokenA)) {
            revert("Conversions paused");
        }

        IERC20 inputToken;
        IERC20 outputToken;
        if(_token == address(tokenA)) {
            inputToken = tokenA;
            outputToken = tokenB;
        } else {
            inputToken = tokenB;
            outputToken = tokenA;
        }

        require(outputToken.balanceOf(address(this)) >= _amount, "Insufficient contract balance");
        inputToken.safeTransferFrom(msg.sender, address(this), _amount);
        outputToken.safeTransfer(msg.sender, _amount);
        emit Convert(msg.sender, _token, _amount);
    }

    // ------------------------- Admin control -------------------------
    /**
     * @dev Enables owner to deposit tokens to the contract
     * @param _token The token address
     * @param _amount The amount to deposit
     */
    function deposit(address _token, uint256 _amount) external onlyOwner {
        require(_token == address(tokenA) || _token == address(tokenB), "Invalid token type");
        require(_amount > 0, "No zero deposit");
        IERC20(_token).safeTransferFrom(owner(), address(this), _amount);
        emit Deposit(address(_token), _amount);
    }

    /**
     * @dev Enables owner to withdraw tokens from the contract
     * @param _token The token address
     * @param _amount The amount to be withdrawn
     */
    function withdraw(address _token, uint256 _amount) external onlyOwner {
        require(_token == address(tokenA) || _token == address(tokenB), "Invalid token type");
        require(IERC20(_token).balanceOf(address(this)) >= _amount, "Insufficient contract balance");
        require(_amount > 0, "No zero withdraw");
        IERC20(_token).safeTransfer(owner(), _amount);
        emit Withdraw(_token, _amount);
    }

    /**
     * @dev Enables owner to easily withdraw maximum available tokens
     * @param _token The token address
     */
    function maxWithdraw(address _token) external onlyOwner {
        require(_token == address(tokenA) || _token == address(tokenB), "Invalid token type");
        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(owner(), amount);
        emit Withdraw(_token, amount);
    }

    /**
     * @dev Enables owner to toggle bidirectional mode
     */
    function toggleBidirectional() external onlyOwner {
        bool current = bidirectional;
        bidirectional = !current;
        emit ToggleBidirectional(bidirectional);
    }

    // ------------------------- Viewers -------------------------
    /**
     * @dev Returns the maximum amount of tokens the owner can currently withdraw
     * @param _token The address of the token
     * @return The max amount of tokens available for withdrawal
     */
    function maxOwnerWithdraw(address _token) public view returns(uint256) {
        require(_token == address(tokenA) || _token == address(tokenB), "Invalid token type");
        return IERC20(_token).balanceOf(address(this));
    }

    /**
     * @dev Returns the maximum amount of tokens that can currently be converted
     * @param _token The address of the token
     * @return The max amount of tokens available for conversion
     */
    function maxConvert(address _token) public view returns(uint256) {
        require(_token == address(tokenA) || _token == address(tokenB), "Invalid token type");
        if(_token == address(tokenA)) { 
            return tokenB.balanceOf(address(this));
        }
        return tokenA.balanceOf(address(this));
    }
}
