// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract CoinFlip is VRFConsumerBaseV2, Ownable {
    VRFCoordinatorV2Interface COORDINATOR;
    IERC20 private _tokenContract;

    address public BURNER_ADDRESS = 0x0000000000000000000000000000000000000000;
    uint256 public BURNED_AMOUNT = 0;

    uint64 private s_subscriptionId;
    address private vrfCoordinator = 0x2eD832Ba664535e5886b75D64C46EB9a228C2610;
    address private linkTokenAddress = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;
    bytes32 private keyHash = 0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61;
    uint32 private callbackGasLimit = 100000;
    uint16 private requestConfirmations = 3;

    address s_owner;

    struct CoinFlipStruct {
        uint256 ID;
        address betStarter;
        uint256 bet;
        uint256 reward;
        uint256 totalGain;
        uint8 choice;
        uint256 winTax;
        uint256 loseBurnTax;
    }

    mapping(uint256  => CoinFlipStruct) public requestIdToFlipStructs;
    mapping(uint256  => uint256) public requestIdToResult;

    uint256 public randomNumber;
    uint256 public requestId;



    uint256 public winTax = 80; // 8% will go to burner address, rest to winner
    uint256 public loseBurnTax = 800; // 80% will go to burner address, rest to treasury
    uint256 private coinFlipIDCounter = 1;
    event CoinFlipped(
      uint256 indexed coinFlipID,
      uint256 bet,
      uint256 reward,
      address indexed starter,
      address winner,
      bool isWin,
      uint8 choice,
      uint256 result,
      uint256 timestamp
    );

    constructor(uint64 subscriptionId, address tokenAddress, address burnerContract) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
        _tokenContract = IERC20(tokenAddress);
        BURNER_ADDRESS=address(burnerContract);
    }

  // Choice = 1 | 0 => 1 = Head, 0 = Tail
  function coinFlip(uint256 amountCHRO, uint8 choice) public {
        address theBetStarter = msg.sender;
        uint256 reward = amountCHRO * (2 * 1000 - winTax) / 1000;
        uint256 coinFlipID = coinFlipIDCounter;

        // CHECK TOKEN BALANCE
        require(_tokenContract.balanceOf(theBetStarter) >= amountCHRO, "Not enough balance");
        require(
            _tokenContract.allowance(theBetStarter, address(this))
            >= amountCHRO,
            "Not enough allowance"
        );

        // CHECK TREASURY BALANCE
        require(_tokenContract.balanceOf(address(this)) >= reward, "Not enough treasury");

        requestId = COORDINATOR.requestRandomWords(
          keyHash,
          s_subscriptionId,
          requestConfirmations,
          callbackGasLimit,
          1
        );

        // TF TO THIS ADDRESS FIRST, to prevent user draining their balance after flipping coin, since VRF results are async
        _tokenContract.transferFrom(msg.sender, address(this), amountCHRO);

        requestIdToFlipStructs[requestId] = CoinFlipStruct(
          coinFlipID,
          msg.sender,
          amountCHRO,
          reward,
          amountCHRO + reward,
          choice,
          winTax,
          loseBurnTax
        );

        coinFlipIDCounter += 1;
    }


    function fulfillRandomWords(
      uint256 _requestId, /* requestId */
      uint256[] memory randomWords
    ) internal override {
      requestIdToResult[_requestId] = randomWords[0];
      uint256 _randomNumber = randomWords[0];
      checkFlip(_randomNumber, _requestId);
    }

    function checkFlip(uint256 _randomNumber, uint256 _requestId) internal {
      // CHECK FLIP

        CoinFlipStruct memory c = requestIdToFlipStructs[_requestId];

        uint256 result = _randomNumber % 2; // will be either 1 or 0
        bool isWin = result == c.choice;

        if(isWin){
            // BURN BY WIN TAX
            _burnTax((c.bet * c.winTax / 1000));

            // TF REWARD
            _tokenContract.transfer(c.betStarter, c.totalGain);
            emit CoinFlipped(c.ID, c.bet, c.reward, c.betStarter, c.betStarter, isWin, c.choice, result, block.timestamp);
        } else {
            // BURN BY LOSE TAX
            _burnTax((c.bet * c.loseBurnTax / 1000));

            emit CoinFlipped(c.ID, c.bet, c.reward, c.betStarter, address(this), isWin, c.choice, result, block.timestamp);
        }
    }

    function _burnTax(uint256 amount) public{
      _tokenContract.transfer(address(BURNER_ADDRESS), amount);
      BURNED_AMOUNT += amount;
    }

    // ADMIN FUNCTIONS ===========================================
    function setWinTax(uint256 _winTax) public onlyOwner{
        winTax = _winTax;
    }

    function setLoseBurnTax(uint256 _loseBurnTax) public onlyOwner{
        loseBurnTax = _loseBurnTax;
    }

    function setTokenContract(address _tokenAddress) public onlyOwner{
        _tokenContract = IERC20(_tokenAddress);
    }
}