// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "../lib/v3-core/contracts/libraries/TickMath.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "../lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import "../lib/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "../lib/v3-periphery/contracts/base/LiquidityManagement.sol";
import "../lib/v3-periphery/contracts/libraries/PoolAddress.sol";
import "../lib/v3-periphery/contracts/NonfungiblePositionManager.sol";
import {UniswapV3Pool} from "../lib/v3-core/contracts/UniswapV3Pool.sol";
import "../lib/v3-core/contracts/interfaces/IERC20Minimal.sol";

contract LiquidManager is IERC721Receiver {
    NonfungiblePositionManager public constant nonfungiblePositionManager =
        NonfungiblePositionManager(0x1238536071E1c677A632429e3655c799b22cDA52);

    int24 public _currentTick;
    int24 public _tickSpacing;
    address public pool;
    int24 strike;
    int24 tick;

    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    enum Position {
        BUY,
        SELL
    }

    Position public position;

    mapping(uint256 => Deposit) public deposits;
    mapping(uint256 => int24) public strikes;

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        require(
            msg.sender == address(nonfungiblePositionManager),
            "not a univ3 nft"
        );
        _createDeposit(operator, tokenId);
        return this.onERC721Received.selector;
    }

    function _createDeposit(address owner, uint256 tokenId) internal {
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,

        ) = nonfungiblePositionManager.positions(tokenId);
        // set the owner and data for position
        deposits[tokenId] = Deposit({
            owner: owner,
            liquidity: liquidity,
            token0: token0,
            token1: token1
        });
        strikes[tokenId] = strike;
    }

    function mintNewPosition(
        address _token1,
        address _token2,
        uint256 _amount0ToMint,
        uint256 _amount1ToMint,
        uint24 _poolFee,
        int24 _lowerTick,
        int24 _upperTick
    )
        public
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        TransferHelper.safeTransferFrom(
            _token1,
            msg.sender,
            address(this),
            _amount0ToMint
        );
        TransferHelper.safeTransferFrom(
            _token2,
            msg.sender,
            address(this),
            _amount1ToMint
        );

        TransferHelper.safeApprove(
            _token1,
            address(nonfungiblePositionManager),
            _amount0ToMint
        );
        TransferHelper.safeApprove(
            _token2,
            address(nonfungiblePositionManager),
            _amount1ToMint
        );

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: _token1,
                token1: _token2,
                fee: _poolFee,
                tickLower: _lowerTick,
                tickUpper: _upperTick,
                amount0Desired: _amount0ToMint,
                amount1Desired: _amount1ToMint,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager
            .mint(params);

        _createDeposit(msg.sender, tokenId);

        if (amount0 < _amount0ToMint) {
            TransferHelper.safeApprove(
                _token1,
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund0 = _amount0ToMint - amount0;
            TransferHelper.safeTransfer(_token1, msg.sender, refund0);
        }

        if (amount1 < _amount1ToMint) {
            TransferHelper.safeApprove(
                _token2,
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund1 = _amount1ToMint - amount1;
            TransferHelper.safeTransfer(_token2, msg.sender, refund1);
        }
    }

    function putOrCall(
        bool _putOrCall,
        address _token1,
        address _token2,
        uint256 _amount0ToMint,
        uint256 _amount1ToMint,
        uint24 _poolFee,
        int24 _price
    ) public {
        takePoolInfo(_token1, _token2, _poolFee);
        strike = _price;
        if (_putOrCall) {
            // true - call, false - put
            position = Position.BUY;
            tick =
                ((_currentTick + _tickSpacing) / _tickSpacing) *
                _tickSpacing;
            mintNewPosition(
                _token1,
                _token2,
                _amount0ToMint,
                _amount1ToMint,
                _poolFee,
                tick,
                strike
            );
        } else {
            tick =
                ((_currentTick - _tickSpacing) / _tickSpacing) *
                _tickSpacing;
            position = Position.SELL;
            mintNewPosition(
                _token1,
                _token2,
                _amount0ToMint,
                _amount1ToMint,
                _poolFee,
                strike,
                tick
            );
        }
    }

    function collectAllFees(
        uint256 tokenId
    ) public returns (uint256 amount0, uint256 amount1) {
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0, amount1) = nonfungiblePositionManager.collect(params);

        _sendToOwner(tokenId, amount0, amount1);
    }

    function checkPositionForClosure(
        uint256 tokenId,
        address token0,
        address token1,
        uint24 fee
    ) internal returns (bool result) {
        takePoolInfo(token0, token1, fee);
        if ((msg.sender == deposits[tokenId].owner) ||
            (position == Position.BUY && strikes[tokenId] >= _currentTick) ||
            (position == Position.SELL && strike <= _currentTick)
        ) {
            return true;
        }
    }

    function _decreaseLiquidity(
        uint256 tokenId,
        address token0,
        address token1,
        uint24 fee
    ) public returns (uint256 amount0, uint256 amount1) {
        require(
                checkPositionForClosure(tokenId, token0, token1, fee),
            "Not the owner or position is not opened for termination"
        );

        uint128 liquidity = deposits[tokenId].liquidity;

        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(
            params
        );

        collectAllFees(tokenId);
    }

    function _sendToOwner(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1
    ) internal {
        // get owner of contract
        address owner = deposits[tokenId].owner;

        address token0 = deposits[tokenId].token0;
        address token1 = deposits[tokenId].token1;
        // send collected fees to owner
        TransferHelper.safeTransfer(token0, owner, amount0);
        TransferHelper.safeTransfer(token1, owner, amount1);
    }

    function retrieveNFT(uint256 tokenId) external {
        require(msg.sender == deposits[tokenId].owner, "Not the owner");

        nonfungiblePositionManager.safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );

        delete deposits[tokenId];
    }

    function takePoolInfo(address token0, address token1, uint24 fee) public {
        address factory = 0x0227628f3F023bb0B980b67D528571c95c6DaC1c;

        PoolAddress.PoolKey memory key = PoolAddress.getPoolKey(
            token0,
            token1,
            fee
        );

        pool = PoolAddress.computeAddress(factory, key);

        _tickSpacing = IUniswapV3PoolImmutables(pool).tickSpacing();
        (, tick, , , , , ) = IUniswapV3Pool(pool).slot0();
        _currentTick = tick;
    }
}
