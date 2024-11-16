// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

contract HalfLife is ERC20, Ownable {

    error NOT_ENOUGH_ALLOWANCE();
    error TRANSFER_FAILED();
    error GAME_STARTED();
    error OVER_MAX_TOKEN_POOL_SIZE();

    uint256 private constant c_PRICE_PER_TOKEN = 1*(10**5); //$0.1
    uint256 private constant c_TOTAL_TOKEN_POOL = 100000; //100,000

    ERC20 immutable i_USDC;

    uint256 s_lotteryPool;
    uint256 s_totalTokenPoolRemaining = 100000;
    bool gameStarted = false;

    modifier GameNotStarted() {
        if(gameStarted) {
            revert GAME_STARTED();
        }
        _;
    }

    constructor(address _usdc) ERC20("HalfLife", "HLF") Ownable(msg.sender) {
        i_USDC = ERC20(_usdc);
        //mint to wallet for liquidity add
        // subtract from total token pool 
    }

    function buy(uint256 _tokensToBuy) external payable GameNotStarted {
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
    }



    //Owner Functions
    function startGame() external onlyOwner GameNotStarted {
        gameStarted = true;
    }



}