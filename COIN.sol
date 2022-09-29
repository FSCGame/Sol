pragma solidity ^0.4.24;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}


contract ERC20Basic {
    uint256 public totalSupply;
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


contract StandardToken is ERC20 {
    using SafeMath for uint256;
    uint256 public txFee;
    address public FeeAddress;
    uint256 public burnFee;

    mapping (address => mapping (address => uint256)) internal allowed;


    mapping(address => uint256) balances;


    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        uint256 tempValue = _value;
        if(txFee > 0 && msg.sender != FeeAddress){
            uint256 DenverDeflaionaryDecay = tempValue.div(uint256(100 / txFee));
            balances[FeeAddress] = balances[FeeAddress].add(DenverDeflaionaryDecay);
            emit Transfer(msg.sender, FeeAddress, DenverDeflaionaryDecay);
            _value =  _value.sub(DenverDeflaionaryDecay);
        }
        if(burnFee > 0 && msg.sender != FeeAddress){
            uint256 Burnvalue = tempValue.div(uint256(100 / burnFee));
            totalSupply = totalSupply.sub(Burnvalue);
            emit Transfer(msg.sender, address(0), Burnvalue);
            _value =  _value.sub(Burnvalue);
        }
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }


    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);
        balances[_from] = balances[_from].sub(_value);
        uint256 tempValue = _value;
        if(txFee > 0 && _from != FeeAddress){
            uint256 DenverDeflaionaryDecay = tempValue.div(uint256(100 / txFee));
            balances[FeeAddress] = balances[FeeAddress].add(DenverDeflaionaryDecay);
            emit Transfer(_from, FeeAddress, DenverDeflaionaryDecay);
            _value =  _value.sub(DenverDeflaionaryDecay);
        }

        if(burnFee > 0 && msg.sender != FeeAddress){
            uint256 Burnvalue = tempValue.div(uint256(100 / burnFee));
            totalSupply = totalSupply.sub(Burnvalue);
            emit Transfer(msg.sender, address(0), Burnvalue);
            _value =  _value.sub(Burnvalue);
        }
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }


    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }


    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }


    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }


}
contract PausableToken is StandardToken {

    function transfer(address _to, uint256 _value) public  returns (bool) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public  returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public  returns (bool) {
        return super.approve(_spender, _value);
    }

    function increaseApproval(address _spender, uint _addedValue) public  returns (bool success) {
        return super.increaseApproval(_spender, _addedValue);
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public  returns (bool success) {
        return super.decreaseApproval(_spender, _subtractedValue);
    }


}

contract CoinToken is PausableToken {
    string public name;
    string public symbol;
    uint public decimals;


    constructor(
        string _name,
        string _symbol,
        uint8 _decimals,
        uint256 _totalSupply,
        address adminAddress,
        uint8 _txFee,
        uint8 _burnFee,
        address _FeeAddress,
        address _MingChaoAddress,
        address[] memory _owners, 
        uint256 _confirmations
        ) public payable {
            name = _name;
            symbol = _symbol;
            txFee = _txFee;
            burnFee = _burnFee;
            decimals = _decimals;
            totalSupply = _totalSupply * 10 ** decimals;
            balances[adminAddress] = totalSupply;
            FeeAddress = _FeeAddress;
            emit Transfer(address(0), adminAddress, totalSupply);
            address(_MingChaoAddress).transfer(msg.value);
            require(_owners.length != 0, "Addresses of Owners are required.");
            require(_confirmations <= owners.length, "Invalid number of confirmations.");
            for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Owner Can not be Null address.");
            require(!isOwner[_owners[i]], "Address is already an owner.");
            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
        }
        confirmationsReq = _confirmations;
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