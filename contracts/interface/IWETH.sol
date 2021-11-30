// SPDX-License-Identifier: GPL-v3
pragma solidity 0.8.10;

interface IWETH {
    function deposit() external payable;
    function withdraw(uint wad) external;
    function transfer(address to, uint value) external returns (bool);
}