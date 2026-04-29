// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title mRc Token
 * @dev Optimized for maximum security, fixed supply, and decentralized ownership.
 */

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface IERC20Errors {
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) { return msg.sender; }
}

abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) { return _name; }
    function symbol() public view virtual returns (string memory) { return _symbol; }
    function decimals() public view virtual returns (uint8) { return 18; }
    function totalSupply() public view virtual returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view virtual returns (uint256) { return _balances[account]; }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        _transfer(_msgSender(), to, value);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public virtual returns (bool) {
        _approve(_msgSender(), spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        _spendAllowance(from, _msgSender(), value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) revert ERC20InvalidSender(address(0));
        if (to == address(0)) revert ERC20InvalidReceiver(address(0));
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) revert ERC20InsufficientBalance(from, fromBalance, value);
            unchecked { _balances[from] = fromBalance - value; }
        }

        if (to == address(0)) {
            unchecked { _totalSupply -= value; }
        } else {
            unchecked { _balances[to] += value; }
        }
        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) revert ERC20InvalidReceiver(address(0));
        _update(address(0), account, value);
    }

    function _approve(address owner, address spender, uint256 value) internal virtual {
        if (owner == address(0)) revert ERC20InvalidSender(address(0));
        if (spender == address(0)) revert ERC20InvalidReceiver(address(0));
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            unchecked { _approve(owner, spender, currentAllowance - value); }
        }
    }
}

abstract contract Ownable is Context {
    address private _owner;
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        if (owner() != _msgSender()) revert OwnableUnauthorizedAccount(_msgSender());
        _;
    }

    function owner() public view virtual returns (address) { return _owner; }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract mRc is ERC20, Ownable {
    // 200 Trillion tokens with 18 decimals
    uint256 public constant MAX_SUPPLY = 200_000_000_000_000 * 10**18;
    uint256 public constant DEV_FEE = 10; // 0.1%

    address public immutable devWallet;
    bool public ownershipLocked;

    mapping(address => bool) public isExcluded;

    error ZeroAddressDetected();
    error OwnershipSafetyLockActive();

    constructor(address _owner, address _devWallet)
        ERC20("mRc", "MRC")
        Ownable(_owner)
    {
        if (_owner == address(0) || _devWallet == address(0)) revert ZeroAddressDetected();
        
        devWallet = _devWallet;
        isExcluded[_owner] = true;
        isExcluded[address(this)] = true;
        isExcluded[_devWallet] = true;

        _mint(_owner, MAX_SUPPLY);
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from == address(0) || to == address(0) || isExcluded[from] || isExcluded[to]) {
            super._update(from, to, amount);
            return;
        }

        uint256 fee = (amount * DEV_FEE) / 10000;
        uint256 sendAmount = amount - fee;

        if (fee > 0) {
            super._update(from, devWallet, fee);
        }

        super._update(from, to, sendAmount);
    }

    function setExcluded(address user, bool value) external onlyOwner {
        if (user == address(0)) revert ZeroAddressDetected();
        isExcluded[user] = value;
    }

    function lockOwnership() external onlyOwner {
        ownershipLocked = true;
    }

    function renounceOwnership() public override onlyOwner {
        if (!ownershipLocked) revert OwnershipSafetyLockActive();
        super.renounceOwnership();
    }
}
