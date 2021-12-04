// SPDX-License-Identifier: GPL-v3
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../EasyFarmToken.sol";

import "../interface/IEasyFarmStrategy.sol";
import "../interface/Mdex/IMdexPool.sol";
import "../interface/ISwapRouter.sol";

contract StrategyForMdexLp is Ownable, IEasyFarmStrategy {
    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    address public core;
    address public eft;
    address public mdex;
    address public pool;

    uint256 public swapThreshold;
    uint256 public claimThreshold;

    address public router0;
    address public router1;
    address[] public path0;
    address[] public path1;

    mapping(address => uint256) public pidOfLp;

    constructor(
        address _core,
        address _eft,
        address _mdex,
        address _pool,
        uint256 _swapThreshold,
        uint256 _claimThreshold,
        address _router0,
        address[] memory _path0,
        address _router1,
        address[] memory _path1
    ) {
        require(_path0.length > 0 && _path1.length > 0, "path length err");
        require(_path0[0] == mdex && _path0[_path0.length - 1] == _path1[0] && _path1[_path1.length - 1] == eft, "path token err");
        core = _core;
        eft = _eft;
        mdex = _mdex;
        pool = _pool;
        swapThreshold = _swapThreshold;
        claimThreshold = _claimThreshold;
        router0 = _router0;
        path0 = _path0;
        router1 = _router1;
        path1 = _path1;
        doApprove();
    }

    modifier onlyCore() {
        require(msg.sender == core, "permission denied");
        _;
    }

    receive() external payable {}

    function deposit(address _tokenAddr) external override onlyCore {
        uint256 bal = IERC20(_tokenAddr).balanceOf(address(this));
        if (bal > 0) {
            IERC20(_tokenAddr).safeIncreaseAllowance(pool, bal);
            IMdexPool(pool).deposit(pidOfLp[_tokenAddr], bal);
            doSwap();
        }
    }

    function withdraw(address _tokenAddr, uint256 _amount) external override onlyCore {
        IMdexPool(pool).withdraw(pidOfLp[_tokenAddr], _amount);
        IERC20(_tokenAddr).safeTransfer(core, _amount);
        doSwap();
    }

    function withdrawAll(address _tokenAddr) external override onlyCore {
        (uint256 amount, ,) = IMdexPool(pool).userInfo(pidOfLp[_tokenAddr], address(this));
        IMdexPool(pool).withdraw(pidOfLp[_tokenAddr], amount);
        IERC20(_tokenAddr).safeTransfer(core, amount);
        doSwap();
    }

    function emergencyWithdraw(address _tokenAddr) external override onlyCore {
        IMdexPool(pool).emergencyWithdraw(pidOfLp[_tokenAddr]);
        uint256 bal = IERC20(_tokenAddr).balanceOf(address(this));
        IERC20(_tokenAddr).safeTransfer(core, bal);
    }

    function claim(address _tokenAddr) public override {
        (uint256 pending, ) = IMdexPool(pool).pending(pidOfLp[_tokenAddr], address(this));
        if(pending > claimThreshold){
            IMdexPool(pool).deposit(pidOfLp[_tokenAddr], 0);
            doSwap();
        }
    }

    function doSwap() public {
        uint256 input0 = IERC20(mdex).balanceOf(address(this));
        if (input0 > swapThreshold) {
            ISwapRouter(router0).swapExactTokensForTokens(input0, 0, path0, address(this), block.timestamp.add(500));
            uint256 input1 = IERC20(path1[0]).balanceOf(address(this));
            ISwapRouter(router1).swapExactTokensForTokens(input1, 0, path1, address(this), block.timestamp.add(500));
            burnEFT();
        }
    }

    function burnEFT() public {
        uint256 eftBal = EasyFarmToken(eft).balanceOf(address(this));
        if (eftBal > 0) {
            EasyFarmToken(eft).burn(eftBal);
        }
    }

    function doApprove() public {
        IERC20(path0[0]).safeApprove(router0, 0);
        IERC20(path0[0]).safeApprove(router0, type(uint256).max);
        IERC20(path1[0]).safeApprove(router1, 0);
        IERC20(path1[0]).safeApprove(router1, type(uint256).max);
    }

    function setPidOfLp(address _tokenAddr, uint256 _pid) external onlyOwner {
        pidOfLp[_tokenAddr] = _pid;
    }

    function setEFT(address _eft) external onlyOwner {
        eft = _eft;
        path1[path1.length - 1] = eft;
    }

    function setCore(address _core) external onlyOwner {
        core = _core;
    }

    function setMdex(address _mdex) external onlyOwner {
        mdex = _mdex;
        path0[0] = mdex;
    }

    function setPool(address _pool) external onlyOwner {
        pool = _pool;
    }

    function setSwapThreshold(uint256 _swapThreshold) external onlyOwner {
        swapThreshold = _swapThreshold;
    }

    function setClaimThreshold(uint256 _claimThreshold) external onlyOwner {
        claimThreshold = _claimThreshold;
    }

    function setSwaps(address _router0, address[] memory _path0, address _router1, address[] memory _path1) external onlyOwner {
        require(_path0.length > 0 && _path1.length > 0, "path length err");
        require(_path0[0] == mdex && _path0[_path0.length - 1] == _path1[0] && _path1[_path1.length - 1] == eft, "path token err");
        router0 = _router0;
        path0 = _path0;
        router1 = _router1;
        path1 = _path1;
        doApprove();
    }
}
