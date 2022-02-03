// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet{
    address[] public owners;
    uint public numConfirmationRequired;

    mapping (address => bool) public isOwner;

    event Deposited(address depositor, uint value);
    event TxSubmitted(address indexed owner, uint indexed txId);
    event TxApproved(address indexed owner, uint indexed txId);
    event TxExecuted(address indexed owner, uint indexed txId);

    struct Transaction{
        address to;
        uint value;
        address owner;
        uint numConfirmation;
        bool isExecuted;
    }

    Transaction[] public txList;

    mapping(uint => mapping(address => bool)) public txApproval;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "only Owner");
        _;
    }

    modifier notExecuted(uint txId) {
        require(!txList[txId].isExecuted, "tx is executed");
        _;
    }

    modifier txExists(uint txId) {
        require(txId < txList.length, "tx does not exist");
        _;
    }

    constructor(address[] memory _owners, uint _numConfirmationRequired)   {
        require(_numConfirmationRequired > 0, "numConfirmationRequired <=0");
        require(_owners.length > 0, "no owners");
        require(_owners.length >= _numConfirmationRequired, "numConfirmationRequired > owners count");

        numConfirmationRequired = _numConfirmationRequired;

        for (uint x; x< _owners.length; x++){
            require(_owners[x] != address(0), "null owner");
            require(!isOwner[_owners[x]], "duplicate owner");
            owners.push(_owners[x]);
            isOwner[_owners[x]] = true;
        }
    }

    receive() external payable{
        emit Deposited(msg.sender, msg.value);
    }

    function submitTx(address _to, uint _value) onlyOwner external {
        Transaction memory trx = Transaction({
            to : _to,
            value : _value,
            owner : msg.sender,
            numConfirmation : 0,
            isExecuted : false
        });

        txList.push(trx);
        emit TxSubmitted(msg.sender, txList.length -1);
    }

    function approve(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        txApproval[_txId][msg.sender] = true;
        txList[_txId].numConfirmation = txList[_txId].numConfirmation + 1; 
        emit TxApproved(msg.sender, _txId);
    }

    function execute(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        require(txList[_txId].numConfirmation == numConfirmationRequired, "more confirmations required");
        (bool sent, ) = txList[_txId].to.call{value : txList[_txId].value}("");
        require(sent, "transfer failed");
        txList[_txId].isExecuted = true;
        emit TxExecuted(msg.sender, _txId);
    }
}