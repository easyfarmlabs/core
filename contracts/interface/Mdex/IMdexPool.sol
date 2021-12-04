// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IMdexPool {
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256, uint256);
    function pending(uint256 _pid, address _user) external view returns (uint256, uint256); // return: mdex, token
    function emergencyWithdraw(uint256 _pid) external;
}