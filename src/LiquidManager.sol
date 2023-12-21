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
import {AutomationCompatibleInterface} from "./AutomationCompatibleInterface.sol";
import {KeeperRegistrar2_0Interface} from "./KeeperRegistrar2_0Interface.sol";
import {LinkTokenInterface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.7/interfaces/LinkTokenInterface.sol";
import '../lib/openzeppelin-contracts/contracts/utils/Strings.sol';

contract LiquidManager is IERC721Receiver, AutomationCompatibleInterface {
    NonfungiblePositionManager public constant nonfungiblePositionManager =
        NonfungiblePositionManager(0x1238536071E1c677A632429e3655c799b22cDA52);
    KeeperRegistrar2_0Interface public constant keeperRegistrar =
        KeeperRegistrar2_0Interface(0xb0E49c5D0d05cbc241d68c05BC5BA1d1B7B72976);
    LinkTokenInterface public constant link =
        LinkTokenInterface(0x779877A7B0D9E8603169DdbD7836e478b4624789);

    

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
    event NewPositionMinted(
        address owner,
        address token0,
        address token1,
        uint256 amount,
        uint256 timestamp
    ); // uint14 closetick сразу расчитать закрытие для бэка

    Position public position;

    mapping(uint256 => Deposit) public deposits;
    mapping(uint256 => int24) public strikes;
    mapping(uint256 => uint256) public jobs;

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
        emit NewPositionMinted(
            deposits[tokenId].owner,
            deposits[tokenId].token0,
            deposits[tokenId].token1,
            deposits[tokenId].liquidity,
            block.timestamp
        ); //может расчитать сразу для бэка closetick);
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
        job(tokenId, _token1, _token2, _poolFee);
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
            // true - put, false - call
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
                tick, //Lower Tick
                strike // Upper Tick
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
                strike, //Lower Tick
                tick //Upper Tick
            );
        }
    }

    function _collectAllFees(
        uint256 tokenId
    ) internal returns (uint256 amount0, uint256 amount1) {
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

    function _checkPositionForClosure(
        uint256 tokenId,
        address token0,
        address token1,
        uint24 fee
    ) public returns (bool result) {
        takePoolInfo(token0, token1, fee);
        if (
            (msg.sender == deposits[tokenId].owner) ||
            (position == Position.BUY && _currentTick <= strikes[tokenId]) ||
            (position == Position.SELL && _currentTick >= strikes[tokenId])
        ) {
            return true;
        }
    }

    function decreaseLiquidity(
        uint256 tokenId,
        address token0,
        address token1,
        uint24 fee
    ) public returns (uint256 amount0, uint256 amount1) {
        require(deposits[tokenId].liquidity != 0, "Need deposits");
        require(
            _checkPositionForClosure(tokenId, token0, token1, fee),
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

        _collectAllFees(tokenId);
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

    function getTickfromFrontPrice(
        uint160 _price
    ) external pure returns (int24) {
        uint160 sqrtPriceX96 = sqrt(_price) * 2 ** 96;
        // _sqrtPriceX96 расчитать на фронте или добавить корень uint160 sqrtPriceX96 = sqrt(_price)* 2**96;
        return TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    function sqrt(uint256 a) internal pure returns (uint160) {
        if (a == 0) {
            return 0;
        }
        uint256 result = 1 << (log2(a) >> 1);
        result = (result + a / result) >> 1;
        result = (result + a / result) >> 1;
        result = (result + a / result) >> 1;
        result = (result + a / result) >> 1;
        result = (result + a / result) >> 1;
        result = (result + a / result) >> 1;
        result = (result + a / result) >> 1;
        return uint160(result < a / result ? result : a / result);
    }

    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        if (value >> 128 > 0) {
            value >>= 128;
            result += 128;
        }
        if (value >> 64 > 0) {
            value >>= 64;
            result += 64;
        }
        if (value >> 32 > 0) {
            value >>= 32;
            result += 32;
        }
        if (value >> 16 > 0) {
            value >>= 16;
            result += 16;
        }
        if (value >> 8 > 0) {
            value >>= 8;
            result += 8;
        }
        if (value >> 4 > 0) {
            value >>= 4;
            result += 4;
        }
        if (value >> 2 > 0) {
            value >>= 2;
            result += 2;
        }
        if (value >> 1 > 0) {
            result += 1;
        }

        return result;
    }

    function jobRegistration(
        KeeperRegistrar2_0Interface.RegistrationParams memory params
    ) internal returns (uint256 upkeepID) {
        link.approve(address(keeperRegistrar), params.amount);
        upkeepID = keeperRegistrar.registerUpkeep(params);
        if (upkeepID != 0) {
            return upkeepID;
        } else {
            revert("auto-approve-disabled");
        }
    }

    function job(
        uint256 tokenId,
        address token0,
        address token1,
        uint24 fee
    ) internal {
        require(link.balanceOf(address(this)) >= 0.1 ether, "Not enough LINK");

        uint256 upkeepID = 0;

        KeeperRegistrar2_0Interface.RegistrationParams
            memory params = KeeperRegistrar2_0Interface.RegistrationParams({
                name: string(Strings.toString(uint256(tokenId))),
                encryptedEmail: abi.encode("0x"),
                upkeepContract: address(this),
                gasLimit: 500000,
                adminAddress: 0x3B66e7a2C8147EA2f5FCf39613492774F361A0DF,
                triggerType: 0,
                checkData: abi.encode(tokenId, token0, token1, fee),
                triggerConfig: abi.encode("0x"),
                offchainConfig: abi.encode("0x"),
                amount: 100000000000000000
            });

        upkeepID = jobRegistration(params);

        jobs[tokenId] = upkeepID;
    }

    function checkUpkeep(
        bytes calldata checkData
    ) external override returns (bool upkeepNeeded, bytes memory performData) {
        (uint256 tokenId, address token0, address token1, uint24 fee) = abi
            .decode(checkData, (uint256, address, address, uint24));
        (upkeepNeeded) = _checkPositionForClosure(tokenId, token0, token1, fee);
        return (upkeepNeeded, checkData);
    }

    function performUpkeep(bytes calldata performData) external override {
        (uint256 tokenId, address token0, address token1, uint24 fee) = abi
            .decode(performData, (uint256, address, address, uint24));
        bool upkeepNeeded = _checkPositionForClosure(
            tokenId,
            token0,
            token1,
            fee
        );
        if (upkeepNeeded) {
            decreaseLiquidity(tokenId, token0, token1, fee);
        }
    }
}
