// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

// Factory Worker status
struct Worker {
    uint tokenId;
    bool working;
    uint refBlock;
    uint lifetimeWorkedHours;
}