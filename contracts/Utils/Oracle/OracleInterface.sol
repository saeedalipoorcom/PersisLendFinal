//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface OracleInterface {
    function getLatestPrice() external view returns (int256);
}
