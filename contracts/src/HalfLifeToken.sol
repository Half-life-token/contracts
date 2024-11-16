// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {VRFConsumerBaseV2Plus} from "chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract HalfLife is ERC20, VRFConsumerBaseV2Plus {

    error NOT_ENOUGH_ALLOWANCE();
    error TRANSFER_FAILED();
    error GAME_STARTED();
    error OVER_MAX_TOKEN_POOL_SIZE();
    error RANDOMNESS_NOT_SENT();
    error ONLY_OWNER();
    error USERS_CANNOT_PROVIDE_LIQUIDTY();
    error GAME_IS_NOT_OVER();
    error NOT_WINNER();

    /**********************************************************/
    // Chainlink VRF Variables                                     
    /**********************************************************/
    event RequestSent(uint256 requestId, address sender);

    struct RequestStatus {
        bool fulfilled;
        bool exists; 
        uint256[] randomWords;
    }

    mapping(uint256 => RequestStatus) public s_requests;
    bool private requestSent = false;

    uint256 public s_subscriptionId = 25608016536000951774293845819229934175992854276553215023064642835696496121759;

    uint256[] public requestIds;
    uint256 public lastRequestId;

    // Current base
    bytes32 public keyHash = 0xdc2f87677b01473c763cb0aee938ed3341512f6057324a584e5944e786144d70;
    uint32 public callbackGasLimit = 100000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;
    address private vrfCoordinator = 0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634;

    /**********************************************************/
    // Half Life Variables                                     
    /**********************************************************/

    event RandomessFullfilled();
    event BuyPeriodEnded();
    event GameEnd();
    event RoundEnded();
    event RemoveUniswapLiquidity();

    uint256 private constant c_PRICE_PER_TOKEN = 1*(10**4); //$0.01
    uint256 private constant c_TOTAL_TOKEN_POOL = 100000; //100,000
    uint256 private constant c_BUY_PERIOD = 1 days;

    ERC20 immutable i_USDC;
    uint256 immutable i_blockStart;
    address immutable i_owner;

    uint256 private s_totalTokenPoolRemaining = 100000;
    bool private gameStarted = false;
    address[] private s_holders;
    mapping(address => bool) private s_isHolder;
    address private s_uniswapV3Pool;
    mapping(address => uint256) private s_holderIndices;
    mapping(address => uint256) private s_liquidityProvider;
    bool private s_gameOver = false;



    modifier onlyServer() {
        if(msg.sender != i_owner){
            revert ONLY_OWNER();
        }
        _;
    }


    modifier GameNotStarted() {
        if(gameStarted) {
            revert GAME_STARTED();
        }
        _;
    }

    constructor(address _usdc) ERC20("HalfLife", "HLF") VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_USDC = ERC20(_usdc);
        i_blockStart = block.number;
        i_owner = msg.sender;
        _mint(msg.sender, 10000);
        s_totalTokenPoolRemaining - 10000;
    }

    function setPoolAddress(address _uniswapPool) external onlyServer {
        s_uniswapV3Pool = _uniswapPool;
    }

    function buy(uint256 _tokensToBuy) external GameNotStarted {
        if(i_USDC.allowance(msg.sender, address(this)) < (c_PRICE_PER_TOKEN * _tokensToBuy)){
            revert NOT_ENOUGH_ALLOWANCE();
        }

        bool success = i_USDC.transferFrom(msg.sender, address(this), (c_PRICE_PER_TOKEN * _tokensToBuy));

        if(!success){
            revert TRANSFER_FAILED();
        }

        if(s_totalTokenPoolRemaining - _tokensToBuy < 0){
            revert OVER_MAX_TOKEN_POOL_SIZE();
        }

        _mint(msg.sender, _tokensToBuy);

        s_totalTokenPoolRemaining -= _tokensToBuy;

        if(!s_isHolder[msg.sender]){
            s_isHolder[msg.sender] = true;
            s_holderIndices[msg.sender] = s_holders.length;
            s_holders.push(msg.sender);
        }
        
        if(s_totalTokenPoolRemaining == 0 || s_holders.length > 100 || i_blockStart + c_BUY_PERIOD < block.number) {
            emit BuyPeriodEnded();
        }


    }

    function transfer(address to, uint256 value) public override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);

        if(balanceOf(owner) == 0){
            s_isHolder[owner] = false;
            uint256 indexToRemove = s_holderIndices[owner];
            s_holders[indexToRemove] = s_holders[s_holders.length - 1];
            s_holderIndices[s_holders[indexToRemove]] = indexToRemove;
            s_holders.pop();
            delete s_holderIndices[owner];
        }

        if(to == s_uniswapV3Pool){
            revert USERS_CANNOT_PROVIDE_LIQUIDTY();
        }

        return true;
    }

    function half() external onlyServer {
        if(!requestSent){
            revert RANDOMNESS_NOT_SENT();
        }
        
        uint256 numberToHalf = totalSupply() / 2;
        uint256 randomValue = s_requests[requestIds[requestIds.length - 1]].randomWords[0];
        
        if(totalSupply() <= 3){
            if(totalSupply() == 2 || totalSupply() == 3) {
                _handleEndgame(randomValue);
            } else {
                _handleNormalHalving(numberToHalf, randomValue);
            }
        }

        emit RoundEnded();
    }

    function _handleEndgame(uint256 randomValue) internal {
        if(totalSupply() == 3) {
            _burnRandomHolders(randomValue, 2);
            s_gameOver = true;
            emit GameEnd();
        } else if(totalSupply() == 2) {
            _burnRandomHolders(randomValue, 1);
            s_gameOver = true;
            emit GameEnd();
        }
    }

    function _handleNormalHalving(uint256 numberToHalf, uint256 randomValue) internal {
        bytes memory randomBytes = abi.encodePacked(randomValue);
        uint8 lastByte = uint8(randomBytes[randomBytes.length - 1]) &1;
        uint256 addressIterator = 0;

        for(uint x; x < numberToHalf; x++){
            if(addressIterator == s_holders.length){
                if(numberToHalf - x < s_holders.length){
                    _burnRandomHolders(randomValue, numberToHalf - x);
                    break;
                }
                addressIterator = 0;
            }

            address participant = s_holders[addressIterator];
            if(_shouldBurnToken(participant, randomValue, lastByte)) {
                _burnParticipantToken(participant);
            }
            addressIterator++;
        }
    }

    function _shouldBurnToken(address participant, uint256 randomValue, uint8 lastByte) internal pure returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(participant, randomValue));
        uint8 lastByteHash = uint8(hash[hash.length - 1]) &1;
        return lastByteHash == lastByte;
    }

    function _burnParticipantToken(address participant) internal {
        if(participant == s_uniswapV3Pool) {
            emit RemoveUniswapLiquidity();
        } else {
            _burn(participant, 1);
        }

        if(balanceOf(participant) < 1){
            _removeHolder(participant);
        }
    }

    function _burnRandomHolders(uint256 randomValue, uint256 count) internal {
        for(uint i = 0; i < count; i++) {
            uint256 index = randomValue % s_holders.length;
            _burnParticipantToken(s_holders[index]);
            randomValue = uint256(keccak256(abi.encode(randomValue)));
        }
    }

    function _removeHolder(address holder) internal {
        uint256 indexToRemove = s_holderIndices[holder];
        s_holders[indexToRemove] = s_holders[s_holders.length - 1];
        s_holderIndices[s_holders[indexToRemove]] = indexToRemove;
        s_holders.pop();
        delete s_holderIndices[holder];
        s_isHolder[holder] = false;
    }

    function cashOut() external {
        if(!s_gameOver){
            revert GAME_IS_NOT_OVER();
        }

        if(balanceOf(msg.sender) < 1){
            revert NOT_WINNER();
        }

        bool success = i_USDC.transfer(msg.sender, i_USDC.balanceOf(address(this)));

        if(!success){
            revert TRANSFER_FAILED();
        }
    }



    /**********************************************************/
    // Chainlink VRF Functions                                    
    /**********************************************************/


    function requestRandomWords() internal {
        uint256 requestId;
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: true
                    })
                )
            })
        );

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });

        requestIds.push(requestId);
        lastRequestId = requestId;
        requestSent = true;
        emit RequestSent(requestId, msg.sender);
    }

    function requestRandomWordsForServer() external onlyServer {
        uint256 requestId;
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: true
                    })
                )
            })
        );

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });

        requestIds.push(requestId);
        lastRequestId = requestId;
        requestSent = true;
        emit RequestSent(requestId, msg.sender);
    }


    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] calldata _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        emit RandomessFullfilled();
    }

}