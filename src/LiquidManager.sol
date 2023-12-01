// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import '../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '../lib/v3-core/contracts/libraries/TickMath.sol';
import '../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol';
import '../lib/v3-periphery/contracts/libraries/TransferHelper.sol';
import '../lib/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '../lib/v3-periphery/contracts/base/LiquidityManagement.sol';

contract LiquidityExamples is IERC721Receiver {
    // address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    // address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    int24 lowerTick;
    int24 upperTick;

    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    enum Position {
        BUY,
        SELL
    }

    enum AllowToClosePosition {
        CLOSE,
        OPEN
    }

    AllowToClosePosition public closeposition;

    Position public position;

    address pool;
    uint256 strike;

    mapping(uint256 => Deposit) public deposits;

    constructor(INonfungiblePositionManager _nonfungiblePositionManager) {
        nonfungiblePositionManager = _nonfungiblePositionManager;
    }

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {

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


        deposits[tokenId] = Deposit({
            owner: owner,
            liquidity: liquidity,
            token0: token0,
            token1: token1
        });
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
        internal
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
        uint256 _price,
        uint24 currentTick
    ) public {
        strike = _price;
        if (_putOrCall) {
            // true - call, false - put
            lowerTick = currentTick - 1; //надо подумать
            position = Position.BUY;
            mintNewPosition(
                _token1,
                _token2,
                _amount0ToMint,
                _amount1ToMint,
                _poolFee,
                lowerTick,
                _price //надо подумать
            );
        } else {
            upperTick = currentTick + 1; //надо подумать
            position = Position.SELL;
            mintNewPosition(
                _token1,
                _token2,
                _amount0ToMint,
                _amount1ToMint,
                _poolFee,
                _price, //надо подумать
                upperTick
            );
        }
    }



    function collectAllFees(
        uint256 tokenId
    ) external returns (uint256 amount0, uint256 amount1) {

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

    function checkPositionForClosure(uint _strike, uint24 _currentTick) internal {
        if((position == Position.BUY && _strike <= _currentTick) || (position == Position.SELL && _strike >= _currentTick)) {
        closeposition = AllowToClosePosition.OPEN;
        }
    }

    function _decreaseLiquidity(
        uint256 tokenId
    ) internal returns (uint256 amount0, uint256 amount1, uint _strike, uint24 _currentTick) {
        checkPositionForClosure(_strike,  _currentTick);
        require(
            (msg.sender == deposits[tokenId].owner, "Not the owner") || (closeposition = AllowToClosePosition.OPEN)
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

        _sendToOwner(tokenId, amount0, amount1);
    }

    // function increaseLiquidityCurrentRange(
    //     uint256 tokenId,
    //     uint256 amountAdd0,
    //     uint256 amountAdd1
    // ) external returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
    //     TransferHelper.safeTransferFrom(
    //         deposits[tokenId].token0,
    //         msg.sender,
    //         address(this),
    //         amountAdd0
    //     );
    //     TransferHelper.safeTransferFrom(
    //         deposits[tokenId].token1,
    //         msg.sender,
    //         address(this),
    //         amountAdd1
    //     );

    //     TransferHelper.safeApprove(
    //         deposits[tokenId].token0,
    //         address(nonfungiblePositionManager),
    //         amountAdd0
    //     );
    //     TransferHelper.safeApprove(
    //         deposits[tokenId].token1,
    //         address(nonfungiblePositionManager),
    //         amountAdd1
    //     );

    //     INonfungiblePositionManager.IncreaseLiquidityParams
    //         memory params = INonfungiblePositionManager
    //             .IncreaseLiquidityParams({
    //                 tokenId: tokenId,
    //                 amount0Desired: amountAdd0,
    //                 amount1Desired: amountAdd1,
    //                 amount0Min: 0,
    //                 amount1Min: 0,
    //                 deadline: block.timestamp
    //             });

    //     (liquidity, amount0, amount1) = nonfungiblePositionManager
    //         .increaseLiquidity(params);
    // }

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


    function takepoolInfo(
        address token0,
        address token1,
        uint24 fee
        )
        public
        pure
        returns (uint160 sqrtPriceX96, int24 currentTick, address pool)
    {
        address factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

        PoolKey memory key = nonfungiblePositionManager.PoolAddress.getPoolKey(
            token0,
            token1,
            fee
        );

        pool = nonfungiblePositionManager.PoolAddress.computeAddress(factory, key);
        (sqrtPriceX96, currentTick, , , , , ) = IUniswapV3Pool(pool).slot0();
    }
}
