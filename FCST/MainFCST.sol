// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./Addressaccount.sol";


abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


interface IERC20 {

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

struct ReleaseRules {
    uint256 fixedAmount;
    uint256 start;
 //   uint256 duration;
    uint256 percentUnlock;
    uint256 origAmount;
    uint256 unlockedAmount;
    uint256 maxPeriod;
    bool    isPeriod;
}

contract ERC20 is Context, IERC20, IERC20Metadata, Addressaccount{
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    // add for vesting 
    mapping(address => ReleaseRules[]) private _vestings;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    bool public isFee = true;
    uint256 public feeRate = 1;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        
        return _balances[account] + leftVesting(account);
    }

    function getMonth(uint256 start, uint256 max) public view returns (uint256) {
        if(block.timestamp < start) return 0;
        uint256 duration = block.timestamp - start;
        uint256 m1 = 30 days;
        uint256 dm = duration / m1 +1;
        return dm > max ? max : dm;
    }

    function leftVesting(address account) internal view returns (uint256) {
        ReleaseRules[] memory rules = _vestings[account];
        //uint256 leftAmount = 0;
        uint256 unlockedAmount;
        uint256 origAmount;
        for(uint256 i = 0; i < rules.length; i ++) {
            //if(block.timestamp < rules[i].start) continue;
            if(!rules[i].isPeriod) {
                origAmount += rules[i].fixedAmount;
            } else {
                origAmount += rules[i].origAmount * rules[i].percentUnlock * rules[i].maxPeriod / 100;
            }
            
            unlockedAmount += rules[i].unlockedAmount;
        }
        return origAmount - unlockedAmount;
    }

    function availableBalance(address account) public view returns (uint256) {
        if(account != address(0)) {
            ReleaseRules[] storage rules =  _vestings[account];
            uint256 unlockingAmount = 0;
            uint256 unlockedAmount = 0;
            for(uint256 i = 0; i < rules.length; i ++) {
                if(block.timestamp > rules[i].start) {
                    unlockedAmount += rules[i].unlockedAmount;
                    if(rules[i].isPeriod) {
                        uint256 dm = getMonth(rules[i].start, rules[i].maxPeriod);
                        uint256 currentUnlockAmount = dm * rules[i].origAmount * rules[i].percentUnlock / 100;
                        unlockingAmount += currentUnlockAmount;
                    } else {
                        unlockingAmount += rules[i].fixedAmount;
                    }
                }
            }
            return _balances[account] + unlockingAmount - unlockedAmount;
        }
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }


    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) updateBalance(from) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        uint256 feeAmount = 0;
        if(isFee) {
            feeAmount =  amount * feeRate / 100; 
        }
        
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount - feeAmount;
        _balances[feeAddr] += feeAmount;
        

        emit Transfer(from, to, amount - feeAmount);
        emit Transfer(from, feeAddr, feeAmount);


        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }


    function _mintVesting(address account, uint256 amount, uint256 percent, uint256 start, uint256 maxPeriod, bool isPeriod) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        uint256 fixedAmount = 0;
        if(!isPeriod) fixedAmount = amount;

        ReleaseRules memory rule =  ReleaseRules(fixedAmount, start, percent, amount, 0, maxPeriod, isPeriod);
        _vestings[account].push(rule);

        _totalSupply += fixedAmount + amount * percent / 100 * maxPeriod;
        //_balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    modifier updateBalance(address account) {
        if(account != address(0)) {
            ReleaseRules[] storage rules =  _vestings[account];
            uint256 unlockingAmount = 0;
            uint256 unlockedAmount = 0;
            for(uint256 i = 0; i < rules.length; i ++) {
                if(block.timestamp > rules[i].start) {
                    unlockedAmount += rules[i].unlockedAmount;
                    if(rules[i].isPeriod) {
                        uint256 dm = getMonth(rules[i].start, rules[i].maxPeriod);
                        uint256 currentUnlockAmount = dm * rules[i].origAmount * rules[i].percentUnlock / 100;
                        if(currentUnlockAmount > rules[i].unlockedAmount) {
                            rules[i].unlockedAmount = currentUnlockAmount;
                        }
                        unlockingAmount += currentUnlockAmount;
                    } else {
                        unlockingAmount += rules[i].fixedAmount;
                        if(rules[i].unlockedAmount < rules[i].fixedAmount) {
                            rules[i].unlockedAmount = rules[i].fixedAmount;
                        }
                        
                    }
                }
            }
            if(unlockingAmount > unlockedAmount) {
                _balances[account] += unlockingAmount - unlockedAmount;
            }
        }
        _;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

contract FsctToken is ERC20 {
    constructor(address[] memory _owners, uint256 _confirmations) ERC20("FantasySportsClub Token", "FSCT") {

        require(_owners.length != 0, "Addresses of Owners are required.");
        require(_confirmations <= owners.length, "Invalid number of confirmations.");
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Owner Can not be Null address.");
            require(!isOwner[_owners[i]], "Address is already an owner.");
            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
        }
        confirmationsReq = _confirmations;

    
        uint256 totalSupply = 10e8 * 1e18;
        uint256 sixmonths = block.timestamp + 180 days;
        _mint(seedRoundOne, totalSupply * 5/ 100 * 4/ 100);
        _mintVesting(seedRoundOne, totalSupply * 5/ 100, 4, sixmonths, 24, true);
		
		 
        _mint(seedRoundTwo, totalSupply * 5/ 100 * 4/ 100);
        _mintVesting(seedRoundTwo, totalSupply * 5/ 100, 4, sixmonths, 24, true);
		

        _mint(privateSaleOne, totalSupply * 5/ 100 * 4/ 100);
        _mintVesting(privateSaleOne, totalSupply * 5/ 100, 4, sixmonths, 24, true);
		
		_mint(privateSaleTwo, totalSupply * 5/ 100 * 4/ 100);
        _mintVesting(privateSaleTwo, totalSupply * 5/ 100, 4, sixmonths, 24, true);

        _mint(IDO, totalSupply * 2 / 100);
        uint256 oneMonths = 30 days + block.timestamp;
		
        _mint(developmentOne, totalSupply * 5/ 100 * 2/ 100);
        _mintVesting(developmentOne, totalSupply * 5/ 100 * 2 / 100, 0, oneMonths, 0, false);
        _mintVesting(developmentOne, totalSupply * 5/ 100, 4, sixmonths, 24, true);
		
		
		 _mint(developmentTwo, totalSupply * 5/ 100 * 2/ 100);
        _mintVesting(developmentTwo, totalSupply * 5/ 100 * 2 / 100, 0, oneMonths, 0, false);
        _mintVesting(developmentTwo, totalSupply * 5/ 100, 4, sixmonths, 24, true);

		 _mint(developmentThree, totalSupply * 5/ 100 * 2/ 100);
        _mintVesting(developmentThree, totalSupply * 5/ 100 * 2 / 100, 0, oneMonths, 0, false);
        _mintVesting(developmentThree, totalSupply * 5/ 100, 4, sixmonths, 24, true);


        _mint(operation, totalSupply * 5/ 100 * 10 / 100);
        _mintVesting(operation, totalSupply * 5/ 100 * 18 / 100, 0, oneMonths, 0, false);
        _mintVesting(operation, totalSupply * 5/ 100, 3, sixmonths, 24, true);

        _mint(partnership, totalSupply * 5/ 100 * 10 / 100);
        _mintVesting(partnership, totalSupply * 5/ 100 * 18 / 100, 0, oneMonths, 0, false);
        _mintVesting(partnership, totalSupply * 5/ 100, 3, sixmonths, 24, true);


        //_mint(stakingPool, totalSupply * 20/ 100 * 10 / 100);
        _mintVesting(stakingPool, totalSupply * 20/ 100 , 3, block.timestamp, 12, true);
        _mintVesting(stakingPool, totalSupply * 20/ 100 , 2, 365 days +block.timestamp, 12, true);
        _mintVesting(stakingPool, totalSupply * 20/ 100 , 1, 365 days + 365 days +block.timestamp, 40, true);
        
        _mintVesting(gamePool, totalSupply * 30/ 100 , 3, block.timestamp, 12, true);
        _mintVesting(gamePool, totalSupply * 30/ 100 , 2, 365 days +block.timestamp, 12, true);
        _mintVesting(gamePool, totalSupply * 30/ 100 , 1, 365 days + 365 days +block.timestamp, 40, true);

        _mintVesting(liqAddr, totalSupply * 3/ 100 * 4 / 100, 0, oneMonths, 0, false);
        _mintVesting(liqAddr, totalSupply * 3/ 100, 4, sixmonths, 24, true);
    }

    uint256 intervaltime = 48 * 60 * 60;

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public confirmationsReq;
    mapping(uint256 => mapping(address => bool)) public confirms;
	
    struct Transaction {
        address requester;
        address to;
        uint256 amount;
        bytes data;
        uint8 signatureCount;
        bool executed;
        uint256 creationtime;
    }
	
    Transaction[] public transactions;
 
    modifier Owner() {
        require(isOwner[msg.sender], "Not authorized owner");
        _;
    }
	
    modifier txnExists(uint256 _txn) {
        require(_txn < transactions.length, "Transaction does not exist.");
        _;
    }
	
    modifier txnNConfirmed(uint256 _txn) {
        require(confirms[_txn][msg.sender] = false, "Transaction already confirmed.");
        _;
    }
	
    modifier txnNExecuted(uint256 _txn) {
        require(!transactions[_txn].executed, "Transaction already executed.");
        _;
    }
 
    event submitTransaction(address indexed owner, uint256 indexed txnIndex, address indexed to, uint256 amount, bytes data);
    event confirmTransaction(address indexed owner, uint256 indexed txnIndex);
    event revokeTransaction(address indexed owner, uint256 indexed txnIndex);
    event executeTransaction(address indexed owner, uint256 indexed txnIndex);
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
 
    function deposit() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
 
    function Submit(address _receiver, uint256 _amount, bytes memory _data) public Owner {
        uint256 txn = transactions.length;
        transactions.push(
            Transaction({
                requester: msg.sender,
                to: _receiver,
                amount: _amount,
                data: _data,
                signatureCount: 1,
                executed: false,
                creationtime : block.timestamp
            })
        );
        confirms[txn][msg.sender] = true;
        emit submitTransaction(msg.sender, txn, _receiver, _amount, _data);
    }
 
    function confirm(uint256 _txn) public Owner txnExists(_txn) txnNConfirmed(_txn) txnNExecuted(_txn) {
        Transaction storage transaction = transactions[_txn];
        transaction.signatureCount += 1;
        confirms[_txn][msg.sender] = true;
        emit confirmTransaction(msg.sender, _txn);
    }
 
    function revoke(uint256 _txn) public Owner txnExists(_txn) {
        Transaction storage transaction = transactions[_txn];
        require(confirms[_txn][msg.sender] = true, "Transaction not previously confirmed.");
        transaction.signatureCount -= 1;
        confirms[_txn][msg.sender] = false;
        emit revokeTransaction(msg.sender, _txn);
    }
 
    function execute(uint256 _txn) public Owner txnExists(_txn) txnNExecuted(_txn) {
        Transaction storage transaction = transactions[_txn];
        require(transaction.signatureCount >= confirmationsReq, "Minimum consensus not yet reached to execute." );
        require(transaction.creationtime + intervaltime >= block.timestamp,"This transaction was also created over 48 hours ago");
        (bool success, ) = transaction.to.call{value: transaction.amount}(transaction.data);
        require(success, "Transaction did not execute.");
        transaction.executed = true;
        emit executeTransaction(msg.sender, _txn);
    }
 
    function getTransaction(uint256 _txn) public view
        returns (
            address requester,
            address to,
            uint256 amount,
            bytes memory data,
            uint8 signatureCount,
            bool executed,
            uint256 creationtime
        )
    {
        Transaction storage transaction = transactions[_txn];
        return (
            transaction.requester,
            transaction.to,
            transaction.amount,
            transaction.data,
            transaction.signatureCount,
            transaction.executed,
            block.timestamp - transaction.creationtime
        );
    }
 
    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

}