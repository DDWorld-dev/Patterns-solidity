// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract timeLock {
    address public owner;
    mapping (bytes32 => bool) queue;
    uint constant MIN_DELAY = 10;
    uint constant MAX_DELAY = 5 days;
    uint constant PERIOD = 2 days;
    string public message;
    uint public amount;
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public constant CONFIRMATIONS = 3;
   
    mapping(bytes32 => uint) public confirmationsTxAmount;
    mapping(bytes32 => mapping(address => bool)) public confirmations;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not an owner!");
        _;
    }
    constructor(address[] memory _owners){
         require(_owners.length >= CONFIRMATIONS, "not enough owners!");

        for(uint i = 0; i < _owners.length; i++) {
            address nextOwner = _owners[i];

            require(nextOwner != address(0), "zero address");
            require(!isOwner[nextOwner], "already owner!");

            isOwner[nextOwner] = true;
            owners.push(nextOwner);
        }
    }

    function add2Q(
        address _to,
        string calldata _func,
        bytes calldata _data,
        uint _value,
        uint _timestamp
    ) public onlyOwner returns(bytes32){

        require(_timestamp > block.timestamp + MIN_DELAY && _timestamp < block.timestamp + MAX_DELAY, "Faild");
        bytes32 id = keccak256(abi.encode(
            _to,
            _func,
            _data,
            _value,
            _timestamp
        ));
        require(!queue[id], "Faild!");
        queue[id] = true;
        return id;
    }

    function confirm(bytes32 id) external onlyOwner {
        require(queue[id], "not queued!");
        require(!confirmations[id][msg.sender], "already confirmed!");
        confirmationsTxAmount[id]++;
        confirmations[id][msg.sender] = true;
    }

    function extract(bytes32 id) public onlyOwner{
        require(queue[id], "Faild");
        delete queue[id];
        delete confirmationsTxAmount[id];
        for(uint i = 0; i < owners.length; i++) {
            delete confirmations[id][owners[i]];
        }
    }

    function exe(
        address _to,
        string calldata _func,
        bytes calldata _data,
        uint _value,
        uint _timestamp
    ) public payable onlyOwner{
        
         require(_timestamp < block.timestamp || _timestamp + PERIOD > block.timestamp, "Error period!");
       
        bytes32 id = keccak256(abi.encode(
            _to,
            _func,
            _data,
            _value,
            _timestamp
        ));
        
        require(queue[id], "not queued!");
        require(confirmationsTxAmount[id] >= CONFIRMATIONS, "not enough!");
        
        delete queue[id];
        delete confirmationsTxAmount[id];
        for(uint i = 0; i < owners.length; i++) {
            delete confirmations[id][owners[i]];
        }
        bytes memory data;
        if(bytes(_func).length > 0) {
            data = abi.encodePacked(
                bytes4(keccak256(bytes(_func))),
                _data
            );
        } else {
            data = _data;
        }

        (bool success, ) = _to.call{value: _value}(data);
        require(success, "error trans!");

    }
    //start testing timeLock
    function test(string calldata _msg) public payable{
        message = _msg;
        amount = msg.value;
    }

    function blockTimeStamp() public view returns(uint){
        return block.timestamp + 100;
    }

    function dataCreate(string calldata _msg) public pure returns(bytes memory){
        return abi.encode(_msg);
    }
}

