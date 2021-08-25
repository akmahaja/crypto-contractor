// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Freelancer {
    /* 
    *   1. Clients propose work.
    *   2. Freelancers accept work, and propose a plan of work.
    *   3. Clients accept the plan of work, and fund the contract.
    *   4. Freelancers start the work.
    *   5. Clients approve the approved work.
    *   6. Freelancers withdraw funds.
    */

    // potentially include proposal, accepted, started statuses later
    enum Status { funded, finished }

    enum Vote { approved, declined, undecided }

    struct Entity {
        // "payable" vs. "non-payable" addresses are defined at in Solidity at compile time.
        // You can use .transfer(...) and .send(...) on address payable, but not address.
        address payable addr;
        Vote vote;
    }

    struct Work {
        Entity freelancer;
        Entity client;
        // client's description of work
        string description;
        // total payout for the work
        uint256 value;
        // status of the work
        Status status;

    }

    uint256 private totalContracts;

    mapping(uint256 => Work) public contracts;
    mapping(address => uint256) public freelanderToContractId;
    mapping(address => uint256) public clientToContractId;

    event workFunded(Work work);
    event transferFunds();

    constructor() {
        totalContracts = 0;
    }

    modifier onlyFreelancer(uint256 _id) {
        require(msg.sender == contracts[_id].freelancer.addr);
        _;
    }

    modifier onlyClient(uint256 _id) {
        require(msg.sender == contracts[_id].client.addr);
        _;
    }

    modifier checkWorkStatus(uint256 _id, Status _status) {
        require(contracts[_id].status == _status);
        _;
    }

    // "_" differentiates between function arguments and global variables
    modifier sufficientFunds(uint256 _value, uint256 _payment) {
        require(_payment == _value);
        _;
    }

    function fundWork(string memory _description, uint256 _value, address payable _freelancer) 
        public
        payable
        sufficientFunds(_value, msg.value)
    {
        Entity memory entityFreelancer = Entity(_freelancer, Vote.undecided);
        Entity memory entityClient = Entity(payable(msg.sender), Vote.undecided);
        contracts[totalContracts] = Work(entityFreelancer, entityClient, _description, _value, Status.funded);
        freelanderToContractId[_freelancer] = totalContracts;
        clientToContractId[msg.sender] = totalContracts;

        emit workFunded(contracts[totalContracts]);
        totalContracts++;
    }

    function clientApproveWork(uint256 _id, Vote vote) 
        public
        onlyClient(_id)
        checkWorkStatus(_id, Status.funded)
    {
        Work memory agreement = contracts[_id];
        agreement.client.vote = vote;

        if (agreement.client.vote == Vote.approved) {
            agreement.freelancer.addr.transfer(agreement.value);
            emit transferFunds();
        } else if (agreement.client.vote == Vote.declined && agreement.freelancer.vote == Vote.declined) {
            agreement.client.addr.transfer(agreement.value);
            emit transferFunds();
        }
    }

    function freelancerApproveWork(uint256 _id, Vote vote) 
        public
        onlyFreelancer(_id)
        checkWorkStatus(_id, Status.funded)
    {
        Work memory agreement = contracts[_id];
        agreement.client.vote = vote;
        agreement.freelancer.vote = vote;

        if (agreement.client.vote == Vote.approved && agreement.freelancer.vote == Vote.approved) {
            agreement.freelancer.addr.transfer(agreement.value);
            emit transferFunds();

        } else if (agreement.freelancer.vote == Vote.declined) {
            agreement.client.addr.transfer(agreement.value);
            emit transferFunds();
        }
    }
}