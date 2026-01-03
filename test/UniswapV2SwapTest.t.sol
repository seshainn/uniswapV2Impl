// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../src/constants.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IWETH} from "@uniswapPeriphery/contracts/interfaces/IWETH.sol";
import {
    IUniswapV2Router02
} from "@uniswapPeriphery/contracts/interfaces/IUniswapV2Router02.sol";
import {
    IUniswapV2Factory
} from "@uniswapCore/contracts/interfaces/IUniswapV2Factory.sol";
import {
    IUniswapV2Pair
} from "@uniswapCore/contracts/interfaces/IUniswapV2Pair.sol";

contract UniswapV2SwapTest is Test {
    IWETH private constant weth = IWETH(constants.WETH);
    IERC20 private constant dai = IERC20(constants.DAI);
    IERC20 private constant mkr = IERC20(constants.MKR);
    IUniswapV2Router02 private constant router =
        IUniswapV2Router02(constants.UNISWAP_V2_ROUTER_02);
    IUniswapV2Factory private constant factory =
        IUniswapV2Factory(constants.UNISWAP_V2_FACTORY);
    address private constant user = address(100);

    function setUp() public {
        //give 100 eth to user
        deal(user, 100 * 1e18);
        vm.startPrank(user);
        //convert eth to weth
        weth.deposit{value: 100 * 1e18}();
        //approve router to spend upto max weth from user
        IERC20(address(weth)).approve(address(router), type(uint256).max);
        vm.stopPrank();

        //give dai to user
        deal(constants.DAI, user, 1000000 * 1e18);
        vm.startPrank(user);
        //aprove router to spend upto max dai from user
        dai.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }
    // getAmountsOut() returns the estimated output token amounts for a given input token amount and swap path,
    // based on the current Uniswap V2 pool reserves.
    // The last value in the returned array is the final output amount.
    function test_getAmountsOut() public {
        address[] memory path = new address[](3);
        path[0] = constants.WETH;
        path[1] = constants.DAI;
        path[2] = constants.MKR;
        uint256 amountIn = 1e18;
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);
        console2.log("WETH", amounts[0]);
        console2.log("DAI", amounts[1]);
        console2.log("MKR", amounts[2]);
    }
    // getAmountsIn() returns the estimated input token amounts needed for a given output token amount and swap path,
    // based on the current Uniswap V2 pool reserves.
    // The first value in the returned array is the required input amount.
    function test_getAmountsIn() public {
        address[] memory path = new address[](3);
        path[0] = constants.WETH;
        path[1] = constants.DAI;
        path[2] = constants.MKR;
        uint256 amountOut = 1e10;
        uint256[] memory amounts = router.getAmountsIn(amountOut, path);
        console2.log("WETH", amounts[0]);
        console2.log("DAI", amounts[1]);
        console2.log("MKR", amounts[2]);
    }
    //swapExactTokensForTokens(): swaps exact amount of input token (amountIn) for at least amountOutMin of the final output token,
    //along the specified swap path. The user receives only the final output token.
    //The function returns an array of actual amounts used at each hop.
    //deadline is a transaction expiry time (Unix timestamp). e.g. deadline = block.timestamp + 300; // valid for 5 minutes
    function test_swapExactTokensForTokens() public {
        address[] memory path = new address[](3);
        path[0] = constants.WETH;
        path[1] = constants.DAI;
        path[2] = constants.MKR;
        uint256 amountIn = 1e18;
        uint256 amountOutMin = 1;
        vm.prank(user);
        uint256[] memory amounts = router.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            path: path,
            to: user,
            deadline: block.timestamp
        });
        console2.log("WETH", amounts[0]);
        console2.log("DAI", amounts[1]);
        console2.log("MKR", amounts[2]);
        assertGe(mkr.balanceOf(user), amountOutMin, "MKR balance of User");
    }
    //swapTokensForExactTokens(): Swaps up to a maximum amount of input tokens (amountInMax) to receive an exact amount of output tokens (amountOut),
    //along the specified swap path. The user receives only the final output token.
    //The function returns an array of actual amounts used at each hop.
    //deadline is a transaction expiry time (Unix timestamp). e.g. deadline = block.timestamp + 300; // valid for 5 minutes
    function test_swapTokensForExactTokens() public {
        address[] memory path = new address[](3);
        path[0] = constants.WETH;
        path[1] = constants.DAI;
        path[2] = constants.MKR;
        uint256 amountOut = 0.1 * 1e18;
        uint256 amountInMax = 1e18;
        vm.prank(user);
        uint256[] memory amounts = router.swapTokensForExactTokens({
            amountOut: amountOut,
            amountInMax: amountInMax,
            path: path,
            to: user,
            deadline: block.timestamp
        });
        console2.log("WETH", amounts[0]);
        console2.log("DAI", amounts[1]);
        console2.log("MKR", amounts[2]);
        assertEq(mkr.balanceOf(user), amountOut, "MKR balance of User");
    }
    function test_createPair() public {
        //Deploy a new ERC20 TestToken with an initial supply of 1e18.
        TestToken token = new TestToken(1e18);
        //Call Uniswap V2 Factory to create a new liquidity pair.
        //Deploy a new UniswapV2Pair contract if it doesn’t already exist.
        //The pair address is deterministic (based on token addresses).
        //Token order does not matter.
        address pair = factory.createPair(address(token), constants.WETH);

        //Read the two tokens stored in the pair contract.
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        //verification test
        bool hasTestToken = token0 == address(token) ||
            token1 == address(token);
        bool hasWETH = token0 == constants.WETH || token1 == constants.WETH;
        assertTrue(hasTestToken);
        assertTrue(hasWETH);
    }
    //addLiquidity(): contribute both tokens to the pool
    //arguments:
    //amountADesired, amountBDesired: Maximum amounts you are willing to deposit; Router uses some or all to preserve pool ratio.
    //amountAMin, amountBMin: Minimum amounts you are willing to actually deposit
    //to: address that receives LP tokens; can be msg.sender or any other address
    //function returns the actual amounts deposited and the LP tokens minted.
    function test_addLiquidity() public {
        vm.prank(user);
        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity({
            tokenA: constants.DAI,
            tokenB: constants.WETH,
            amountADesired: 1e6 * 1e18,
            amountBDesired: 100 * 1e18,
            amountAMin: 1,
            amountBMin: 1,
            to: user,
            deadline: block.timestamp
        });

        console2.log("DAI", amountA);
        console2.log("WETH", amountB);
        console2.log("LP", liquidity);

        address pairAddress = factory.getPair(constants.DAI, constants.WETH);
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);

        assertGt(pair.balanceOf(user), 0, "LP = 0");
    }
    function test_removeLiquidity() public {
        vm.startPrank(user);
        (, , uint liquidity) = router.addLiquidity({
            tokenA: constants.DAI,
            tokenB: constants.WETH,
            amountADesired: 1e6 * 1e18,
            amountBDesired: 100 * 1e18,
            amountAMin: 1,
            amountBMin: 1,
            to: user,
            deadline: block.timestamp
        });

        address pairAddress = factory.getPair(constants.DAI, constants.WETH);
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);

        //remove liquidity logic starts here: approve router to spend LP tokens of user; call removeLiquidity()
        pair.approve(address(router), liquidity);

        //the LP tokens are burned by the pair contract,
        //and both underlying tokens are transferred back to the user,
        //while the user’s LP balance is reduced accordingly.
        (uint amountA, uint amountB) = router.removeLiquidity({
            tokenA: constants.DAI,
            tokenB: constants.WETH,
            liquidity: liquidity,
            amountAMin: 1,
            amountBMin: 1,
            to: user,
            deadline: block.timestamp
        });
        vm.stopPrank();

        console2.log("DAI", amountA);
        console2.log("WETH", amountB);

        assertEq(pair.balanceOf(user), 0, "LP not 0");
    }
}

contract TestToken is ERC20 {
    constructor(uint256 _initSupply) ERC20("TESTTOKEN", "TT") {
        _mint(msg.sender, _initSupply);
    }
}
