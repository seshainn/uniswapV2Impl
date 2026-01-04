// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    IUniswapV2Pair
} from "@uniswapCore/contracts/interfaces/IUniswapV2Pair.sol";

contract UniswapV2FlashSwap {
    error UniswapV2FlashSwap__InvalidToken();
    error UniswapV2FlashSwap__NotPair();
    error UniswapV2FlashSwap__NotSender();

    IUniswapV2Pair private immutable pair;
    address private immutable token0;
    address private immutable token1;

    //pair address is passed to constructor at deployment
    constructor(address _pair) {
        pair = IUniswapV2Pair(_pair);
        token0 = pair.token0();
        token1 = pair.token1();
    }

    //address of the token and amount of token to borrow
    function flashSwap(address token, uint256 amount) external {
        if (token != token0 && token != token1) {
            revert UniswapV2FlashSwap__InvalidToken();
        }
        //set amount0Out or amount1Out to amount based on token
        (uint256 amount0Out, uint256 amount1Out) = token == token0
            ? (amount, uint256(0))
            : (uint256(0), amount);

        bytes memory data = abi.encode(token, msg.sender);

        pair.swap({
            amount0Out: amount0Out,
            amount1Out: amount1Out,
            to: address(this),
            data: data
        });
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        if (msg.sender != address(pair)) {
            revert UniswapV2FlashSwap__NotPair();
        }
        if (sender != address(this)) {
            revert UniswapV2FlashSwap__NotSender();
        }
        (address token, address caller) = abi.decode(data, (address, address));
        uint256 amount = token == token0 ? amount0 : amount1;
        uint256 fee = ((amount * 3) / 997) + 1;
        uint256 amountToRepay = amount + fee;

        IERC20(token).transferFrom(caller, address(this), fee);
        IERC20(token).transfer(address(pair), amountToRepay);
    }
}
