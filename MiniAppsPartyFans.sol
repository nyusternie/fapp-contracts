/*******************************************************************************
 *
 * Copyright (c) 2025 shomari.eth
 * SPDX-License-Identifier: MIT
 *
 * Mini Apps Party Fans
 *
 * A transparent method of tracking the community voting by qualified individuals.
 *
 * Version 1 (alpha)
 * Released 25.6.13
 *
 * https://miniapps.party/fans
 */
pragma solidity ^0.8.9;

import { Ownable } from "./interfaces/Ownable.sol";
import { IERC20 } from "./interfaces/IERC20.sol";
import { IMiniAppsPartyDb } from "./interfaces/IMiniAppsPartyDb.sol";

contract MiniAppsPartyFans is Ownable {
    /* Initialize predecessor contract. */
    address payable private _predecessor;

    /* Initialize successor contract. */
    address payable private _successor;

    /* Initialize revision number. */
    uint private _revision;

    /* Initialize Modenero Db contract. */
    IMiniAppsPartyDb private _miniAppsPartyDb;

    /* Set namespace. */
    // NOTE: Use of `namespace` is REQUIRED when generating ANY & ALL
    //       Mini Apps Party database keys; in order to prevent ANY accidental or
    //       malicious SQL-injection vulnerabilities / attacks.
    string private _namespace = "miniapps.party";

    /* Initialize chain id. */
    uint CHAIN_ID = 8453;

    /* Initialize USDC token. */
    IERC20 _usdcToken = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

    /* Minimum boost amount. */
    // NOTE: Assumed to be USDC.
    uint MIN_BOOST_AMOUNT = 1_000_000; // $1.00

    /* Initialize BDFL (aka shomari.eth warplet) address. */
    address bdflAddr = 0x84D677548B9BE8dE8096F10Ff7d6C3e6187d7196;

    /* Initialize fan club handler. */
    // clubid => FanClub
    // mapping(uint => FanClub) private _clubs;

    /* Initialize fans. */
    // clubid => (fan) address => Fan
    // mapping(uint => mapping(address => Fan)) private _fans;
    // clubid => (fan) address
    mapping(uint => address) private _fans;

    /* Initialize Fan Club schema. */
    struct FanClub {
        bytes32 appid;      // a unique identifier for each mini app (default: hostname)
        address owner;      // mini app owner
        uint payout;        // total payouts sent to mini app owner
        uint8 revision;     // revision (location) for the (latest) mini app data
        address[] fans;     // list of fans supporting (w/ a shoutout) the mini app
    }

    /* Initialize (fan) shoutout schema. */
    struct Fan {
        address id;
        uint love;
        string msg;
    }

    /* Initialize (emit) events. */
    event FanClubCreated(
        uint indexed appid
        // FanClub club
    );
    event Payout(
        uint indexed appid,
        uint amount
    );
    event Shoutout(
        uint indexed appid,
        address fan,
        uint love,
        string msg
    );
    event Withdraw(
        uint indexed appid,
        Fan fan,
        uint amount
    );

    /* Constructor */
    constructor() {
        /* Initialize Mini Apps Party (eternal) storage database contract. */
        // NOTE We hard-code the address here, since it should never change.
        _miniAppsPartyDb = IMiniAppsPartyDb(0x045a1e7D4274cB2704Fc1C8598777B3d450D4b49);

        /* Initialize (aname) hash. */
        bytes32 hash = keccak256(abi.encodePacked("aname.", _namespace));

        /* Set predecessor address. */
        _predecessor = payable(_miniAppsPartyDb.getAddress(hash));

        /* Verify predecessor address. */
        if (_predecessor != address(0)) {
            /* Retrieve the last revision number (if available). */
            uint lastRevision = MiniAppsPartyFans(_predecessor).getRevision();

            /* Set (current) revision number. */
            _revision = lastRevision + 1;
        }
    }

    fallback() external payable {
        /* Cancel this transaction. */
        revert("Oops! Direct payments are NOT permitted here.");
    }

    receive() external payable {
        /* Cancel this transaction. */
        revert("Oops! Direct payments are NOT permitted here.");
    }

    /**
     * @dev Only allow access to an authorized Mini Apps Party hosts.
     */
    modifier onlyAuthByPartyHosts() {
        /* Verify write access is only permitted to authorized hosts. */
        require(_miniAppsPartyDb.getBool(keccak256(
            abi.encodePacked(msg.sender, ".has.auth.for.", _namespace))) == true);

        _;      // function code is inserted here
    }

    /***************************************************************************
     *
     * ACTIONS
     *
     */

    /**
     * Manage Fan Club
     *
     * Allows the Party planner to "manually" update the fan club data.
     *
     * NOTE: This function can ONLY be executed by party hosts.
     */
    function manage(
        uint _appid
    ) external onlyAuthByPartyHosts returns (bool) {
        // TBD

        return true;
    }

    /**
     * Payouts
     *
     * Allows the platform to distribute rewards to the builders, fans, etc.
     *
     * NOTE: USDC amounts are stored in the Mini Apps Party (eternal) database.
     */
    function payouts(
        uint _appid,
        uint8 _maxFans
    ) external onlyAuthByPartyHosts returns (bool) {
        /* Initialize fan club. */
        FanClub storage club;// = _clubs[_appid];

// TODO Re-build properties w/ getters.

        /* Validate fan club owner. */
        if (club.owner == address(0x0)) {
            /* Delegate call to predecessor. */
            return MiniAppsPartyFans(_predecessor).payouts(_appid);
        }

uint payoutAmt = 0;
address receiver = 0x0;


        /* Validate payout amount. */
        require(club.pot >= (club.paid - payoutAmt),
            "Oops! You CANNOT payout more than the pot size.");

        /* Update paid amount. */
        // NOTE: Calculate before "action" is taken (prevent re-entry exploitation).
        club.paid = club.paid - payoutAmt;

        /* Transfer payout amount from contract to player. */
        require(_usdcToken.transfer(receiver, payoutAmt),
            "Oops! USDC transfer has failed!");

        /* Initialize asset id. */
        uint assetid;

        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, ".total.", assetid, ".chips.for.", receiver
        ));

        /* Retrieve value from Mini Apps Party database. */
        uint totalChips = _miniAppsPartyDb.getUint(hash);

        /* Update new total chips. */
        _miniAppsPartyDb.setUint(hash, totalChips + payoutAmt);

        return true;
    }

    /**
     * Shoutout
     *
     * Allows a user to easily boost their visibility within a Mini App;
     *
     * NOTE: Randomization occurs by utilzing the block hashes of the *NEXT*
     *       blocks produced by the miners.
     *
     * @param _appid A unique identifier for the Mini App. (default is hostname)
     * @param _love Amount of USDC required to enter the table.
     * @param _msg A message to be displayed in the app's Fanclub. (max: 100 characters)
     */
    function shoutout(
        uint _appid,
        uint _love,
        string _msg
    ) external returns (bool) {
        /* Validate LOVE amount. */
        require(_love >= MIN_BOOST_AMOUNT,
            "Oops! Amount of USDC is UNDER the minimum of 1.00.");

        /* Initialize fan club. */
        FanClub storage club;// = _clubs[_appid];

// TODO Re-build properties w/ getters.

        /* Validate table host. */
        if (club.owner == address(0x0)) {
            /* Delegate call to predecessor. */
            return MiniAppsPartyFans(_predecessor).shoutout(_appid, _love, _msg);
        }

        /* Transfer buy-in amount from player to table/contract. */
        // NOTE: MUST FIRST pre-authorize this contract with an allowance
        //       from the player's wallet.
        require(_usdcToken.transferFrom(msg.sender, address(this), _love),
            "Oops! You DO NOT have a sufficient balance to make a shoutout.");

        /* Add buy-in to pot. */
        // table.pot = table.pot + table.buyin;

        /* Assign player (id/address) to the next seat. */
        // table.seated.push(msg.sender);

        /* Create player (object). */
        Fan memory fan = Fan(
            msg.sender,
            _love,
            _msg
        );

        /* Add to players. */
        _fans[_appid][msg.sender] = fan;

        /* Broadcast (fan) shoutout. */
        emit Shoutout(_appid, fan, _love, _msg);
    }

    /**
     * Upgrade
     *
     * Allows the Party contract (specifically the treasury) to be migrated—entirely
     * to the official UPGRADE Party contract (as speicified in `_successor`).
     *
     * NOTE: This function can ONLY be executed by party hosts,
     *       AFTER a successor has been assigned.
     */
    function upgrade() external onlyAuthByPartyHosts returns (bool) {
        /* Validate contract successor. */
        require(_successor != address(0x0),
            "Oops! You MUST assign a successor BEFORE upgrading this contract.");

        /* Retrieve USDC balance. */
        uint balance = _usdcToken.balanceOf(address(this));

        /* Validate Party balance. */
        require(balance > 0,
            "Oops! You MUST have a POSITIVE balance to upgrade this Party contract.");

        /* Transfer payout amount from contract to player. */
        require(_usdcToken.transfer(_successor, balance),
            "Oops! Balance transfer of the Party treasury has failed!");

        return true;
    }

    /**
     * Withdraw
     *
     * Anyone can remove their LOVE (aka USDC) from any fan pool, at any time.
     */
    function withdraw(
        uint _appid,
        uint _love
    ) external returns (bool) {
        /* Initialize table. */
        FanClub storage club;// = _miniapps[_appid];

// TODO Re-build properties w/ getters.

        /* Validate table host. */
        if (club.owner == address(0x0)) {
            /* Delegate call to predecessor. */
            return MiniAppsPartyFans(_predecessor).withdraw(_appid, _love);
        }

        return true;
    }

    /***************************************************************************
     *
     * GETTERS
     *
     */

    /**
     * Get (USDC) Balance
     *
     * Retrieve the total amount of USDC a fan has deposited into the pool
     * for a specific mini app.
     */
    function getBalance(
        bytes32 _appid,
        address _fan
    ) external view returns (uint) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, ".total.", _appid, ".love.for.", _fan
        ));

        /* Retrieve value from Mini Apps Party database. */
        uint totalLove = _miniAppsPartyDb.getUint(hash);

        return totalLove;
    }

    /**
     * Get Fan
     *
     * Return a fan.
     */
    function getFan(
        bytes32 _appid,
        address _fan
    ) external view returns (Fan memory) {
        /* Initialize fan. */
        Fan storage fan = _fans[_tableid][_address];

        /* Validate fan address. */
        if (fan.id == address(0x0)) {
            /* Delegate call to predecessor. */
            return MiniAppsPartyFans(_predecessor).getPlayer(_fan, _appid);
        }

        return fan;
    }

    /**
     * Get Fans
     *
     * Return the addresses of all fans w/ active shoutouts.
     */
    function getFans(
        uint _appid
    ) external view returns (address[] memory) {
        /* Initialize mini app. */
        MiniApp storage miniapp = _miniapps[_appid];

        /* Validate mini app owner. */
        if (miniapp.owner == address(0x0)) {
            /* Delegate call to predecessor. */
            return MiniAppsPartyFans(_predecessor).getFans(_appid);
        }

        return miniapp.fans;
    }

    /**
     * Get Fan Club
     *
     * Return a fan club.
     */
    function getFanClub(
        uint _appid
    ) external view returns (FanClub memory) {
        /* Initialize mini app. */
        FanClub storage club = _clubs[_appid];

        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, ".owner.of.", _appid
        ));

        /* Retrieve value from Mini Apps Party database. */
        club.owner = _miniAppsPartyDb.getAddress(hash);

        /* Update new total chips. */
        _miniAppsPartyDb.setUint(hash, totalChips + _amount);

        /* Validate mini app owner. */
        if (miniapp.owner == address(0x0)) {
            /* Delegate call to predecessor. */
            return MiniAppsPartyFans(_predecessor).getMiniApp(_appid);
        }

        return miniapp;
    }

    /**
     * Get Total Fanclubs
     *
     * Total number of tables created by hosts.
     */
    function getTotalTables() external view returns (uint) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, ".total.tables"
        ));

        /* Retrieve value from Mini Apps Party database. */
        uint totalTables = _miniAppsPartyDb.getUint(hash);

        return totalTables;
    }

    /**
     * Get Revision (Number)
     */
    function getRevision() external view returns (uint) {
        return _revision;
    }

    /**
     * Get Predecessor (Address)
     */
    function getPredecessor() external view returns (address) {
        return _predecessor;
    }

    /**
     * Get Successor (Address)
     */
    function getSuccessor() external view returns (address) {
        return _successor;
    }

    /***************************************************************************
     *
     * SETTERS
     *
     */

    /**
     * Set Successor
     *
     * This is the contract address that replaced this current instnace.
     */
    function setSuccessor(
        address payable _newSuccessor
    ) external onlyAuthByPartyHosts returns (bool success) {
        /* Set successor contract. */
        _successor = _newSuccessor;

        /* Return success. */
        return true;
    }
}
