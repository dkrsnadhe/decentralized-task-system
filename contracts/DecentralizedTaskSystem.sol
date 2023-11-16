// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
    Dummy Timestamp: 1700000000
**/

contract DecentralizedTaskSystem {
    uint public id;
    uint public reportId;

    constructor() {
        id = 0;
        reportId = 0;
    }

    enum Status {
        NotStarted,
        Pending,
        Success
    }

    event CreateTask(
        uint _deadline,
        uint _reward,
        uint _time,
        string _title,
        address indexed _creator,
        address indexed _assignee,
        Status _status
    );

    event AssignmentTask(
        uint _tasksId,
        uint _time,
        string _tasksTitle,
        address indexed _assignee,
        Status status
    );

    event VerificationTask(
        uint _taskId,
        uint _time,
        uint _rewardPay,
        Status status
    );

    event CreateReport(
        uint _reportId,
        uint _time,
        address indexed _target,
        address indexed _reported,
        string _reason
    );

    event VerificationReport(
        uint _reportId,
        uint _time,
        uint _quantity,
        address indexed _target,
        address indexed _reported
    );

    struct Task {
        uint deadline;
        uint reward;
        string title;
        string descriptions;
        address creator;
        address assignee;
        Status status;
    }

    struct Report {
        uint quantity;
        address target;
        address reported;
        string reason;
    }

    mapping(uint => Task) public tasks;
    mapping(address => int) public reputation;
    mapping(uint => Report) public reports;
    mapping(address => bool) public members;
    mapping(address => bool) public banned;
    mapping(address => mapping(uint => bool)) public reportedAddress;

    error AddressZero();
    modifier addressZero() {
        if (msg.sender == address(0)) {
            revert AddressZero();
        }
        _;
    }

    error MinPay();
    modifier minPay() {
        if (msg.value <= 0 ether) {
            revert MinPay();
        }
        _;
    }

    error MustHoldToken();
    modifier mustHoldToken() {
        if (msg.sender.balance <= 0 ether) {
            revert MustHoldToken();
        }
        _;
    }

    error CreatorNotAllowed();
    error DeadlinePassed();
    error NotCreator();
    error InsufficientPayment();
    error ReportedAddress();
    error TaskStatusNotMatch();
    error NotMember();
    error HasMadeReport();
    error BadReputation();
    error HasBeenBanned();
    error NotEnoughBalance();

    receive() external payable {}

    fallback() external payable {}

    function createTask(
        uint _deadline,
        string calldata _title,
        string calldata _descriptions
    ) external payable addressZero mustHoldToken minPay {
        if (reputation[msg.sender] < -5) {
            revert BadReputation();
        }

        if (banned[msg.sender]) {
            revert HasBeenBanned();
        }

        id++;

        tasks[id] = Task({
            deadline: _deadline,
            reward: msg.value,
            title: _title,
            descriptions: _descriptions,
            creator: msg.sender,
            assignee: address(0),
            status: Status.NotStarted
        });

        (bool success, ) = address(this).call{value: msg.value}("");
        require(success, "Transaction Failed!");

        members[msg.sender] = true;

        emit CreateTask(
            _deadline,
            msg.value,
            block.timestamp,
            _title,
            msg.sender,
            address(0),
            Status.NotStarted
        );
    }

    function assignmentTask(
        uint _id
    ) external payable addressZero mustHoldToken {
        if (tasks[_id].deadline < block.timestamp) {
            revert DeadlinePassed();
        }

        if (msg.sender == tasks[_id].creator) {
            revert CreatorNotAllowed();
        }

        if (tasks[_id].status != Status.NotStarted) {
            revert TaskStatusNotMatch();
        }

        if (reputation[msg.sender] < -5) {
            revert BadReputation();
        }

        if (banned[msg.sender]) {
            revert HasBeenBanned();
        }

        if (msg.value != (tasks[_id].reward / 2)) {
            revert NotEnoughBalance();
        }

        (bool success, ) = address(this).call{value: msg.value}("");
        require(success, "Transaction Failed!");

        tasks[_id].assignee = msg.sender;
        tasks[_id].status = Status.Pending;

        members[msg.sender] = true;

        emit AssignmentTask(
            _id,
            block.timestamp,
            tasks[_id].title,
            msg.sender,
            Status.Pending
        );
    }

    function verificationTask(uint _id) external payable addressZero {
        if (msg.sender != tasks[_id].creator) {
            revert NotCreator();
        }

        if (tasks[_id].status != Status.Pending) {
            revert TaskStatusNotMatch();
        }

        if (!members[msg.sender]) {
            revert NotMember();
        }

        if (reputation[msg.sender] < -5) {
            revert BadReputation();
        }

        if (banned[msg.sender]) {
            revert HasBeenBanned();
        }

        (bool success, ) = tasks[_id].assignee.call{value: tasks[_id].reward}(
            ""
        );
        require(success, "transaction failed");

        address(this).balance - tasks[_id].reward;

        tasks[_id].status = Status.Success;
        tasks[_id].reward = 0 ether;

        reputation[tasks[_id].assignee]++;

        emit VerificationTask(_id, block.timestamp, msg.value, Status.Success);
    }

    function createReport(
        address _target,
        string calldata _reason
    ) external addressZero {
        if (!members[msg.sender]) {
            revert NotMember();
        }

        if (reputation[msg.sender] < -5) {
            revert BadReputation();
        }

        if (banned[msg.sender]) {
            revert HasBeenBanned();
        }

        reportId++;

        reports[reportId] = Report({
            quantity: 1,
            target: _target,
            reported: msg.sender,
            reason: _reason
        });

        reportedAddress[msg.sender][reportId] = true;

        emit CreateReport(
            reportId,
            block.timestamp,
            _target,
            msg.sender,
            _reason
        );
    }

    function verificationReport(uint _reportId) external addressZero {
        if (msg.sender == reports[_reportId].target) {
            revert ReportedAddress();
        }

        if (!members[msg.sender]) {
            revert NotMember();
        }

        if (reportedAddress[msg.sender][_reportId]) {
            revert HasMadeReport();
        }

        if (reputation[msg.sender] < -5) {
            revert BadReputation();
        }

        if (banned[msg.sender]) {
            revert HasBeenBanned();
        }

        reports[_reportId].quantity++;

        reportedAddress[msg.sender][_reportId] = true;

        reputation[reports[_reportId].target]--;

        if (reports[_reportId].quantity > 10) {
            banned[reports[_reportId].target] = true;
            members[reports[_reportId].target] = false;
        }

        emit VerificationReport(
            _reportId,
            block.timestamp,
            reports[_reportId].quantity,
            reports[_reportId].target,
            msg.sender
        );
    }
}
