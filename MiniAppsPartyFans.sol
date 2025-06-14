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

    /* Maximum number of fans to use for billing. */
    uint8 MAX_FANS_FOR_PAYOUTS = 15;

    /* Initialize BDFL (aka shomari.eth warplet) address. */
    address bdflAddr = 0x84D677548B9BE8dE8096F10Ff7d6C3e6187d7196;

    /* Initialize fan club handler. */
    // clubid => FanClub
    // mapping(uint => FanClub) private _clubs;

    /* Initialize fans. */
    // clubid => (fan) address => Fan
    // mapping(bytes32 => mapping(address => Fan)) private _fans;
    // clubid => (fan) addresses
    mapping(bytes32 => Shoutout[]) private _shoutouts;

    /* Initialize Fan schema. */
    struct Fan {
        address id;         // address of fan
        uint totalLove;     // total LOVE balance of the fan
        bytes32[] clubs;    // list of clubs this fan is showing LOVE for
    }

    /* Initialize Fan Club schema. */
    struct FanClub {
        bytes32 appid;      // a unique identifier for each mini app (default: keccak<hostname>)
        address owner;      // mini app owner
        uint payout;        // total payouts sent to mini app owner
        uint8 revision;     // revision (location) for the (latest) mini app data
        address[] fans;     // list of fans supporting (w/ a shoutout) the mini app
    }

    /* Initialize Fan Club schema. */
    struct Shoutout {
        address fanid;      // the address of the fan
        uint love;          // amount of LOVE available for the shoutout
        string message;     // a message posted to the fan club section of the mini app
    }

    /* Initialize (emit) events. */
    event FanClubCreated(
        bytes32 indexed clubid,
        address creator
    );
    event PayoutsDelivered(
        bytes32 indexed clubid,
        uint love
    );
    event ShoutoutPosted(
        bytes32 indexed clubid,
        address fan,
        uint love,
        string shoutout
    );
    event WithdrawalCompleted(
        bytes32 indexed clubid,
        address fan,
        uint love,
        uint balance
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
        // bytes32 _clubid
    ) external view onlyAuthByPartyHosts returns (bool) {
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
        bytes32 _clubid,
        uint8 _maxFans
    ) external onlyAuthByPartyHosts returns (bool) {
        /* Set (fan club) owner. */
        address owner = getOwner(_clubid);

        /* Validate fan club owner. */
        if (owner == address(0x0)) {
            /* Delegate call to predecessor. */
            return MiniAppsPartyFans(_predecessor).payouts(_clubid, _maxFans);
        }

        Shoutout[] memory shoutouts = sortByLove(_clubid);

        uint8 numFans;
        uint payoutAmt = 0;
        address receiver = address(0x0);

        /* Validate maximum payouts. */
        if (shoutouts.length > MAX_FANS_FOR_PAYOUTS) {
            numFans = MAX_FANS_FOR_PAYOUTS;
        } else {
            numFans = uint8(shoutouts.length);
        }

        /* Handle payout collection. */
        for (uint i = 0; i < numFans; i++) {
            // payoutAmt
        }


        /* Set total LOVE amount. */
        // uint totalLove = getTotalLove(_clubid);


        /* Validate payout amount. */
        // require(club.pot >= (club.paid - payoutAmt),
        //     "Oops! You CANNOT payout more than the pot size.");

        /* Update paid amount. */
        // NOTE: Calculate before "action" is taken (prevent re-entry exploitation).
        // club.paid = club.paid - payoutAmt;

        /* Transfer payout amount from contract to player. */
        require(_usdcToken.transfer(receiver, payoutAmt),
            "Oops! USDC transfer has failed!");

        /* Initialize asset id. */
        uint assetid;

        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, ".total.", assetid, ".chips.for.", receiver
        ));

        /* Retrieve value from eternal database. */
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
     * @param _clubid A unique identifier for the Mini App. (default is hostname)
     * @param _love Amount of USDC required to enter the table.
     * @param _message A message to be displayed in the app's Fanclub. (max: 100 characters)
     */
    function shoutout(
        bytes32 _clubid,
        uint _love,
        string calldata _message
    ) external returns (bool) {
        /* Validate LOVE amount. */
        require(_love >= MIN_BOOST_AMOUNT,
            "Oops! Amount of USDC is UNDER the minimum of 1.00.");

        /* Set (fan club) owner. */
        address owner = getOwner(_clubid);

        /* Validate table host. */
        if (owner == address(0x0)) {
            /* Delegate call to predecessor. */
            return MiniAppsPartyFans(_predecessor).shoutout(_clubid, _love, _message);
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
        // Fan memory fan = Fan(
        //     msg.sender,
        //     _love,
        //     _message
        // );

        /* Add to players. */
        // _fans[_clubid][msg.sender] = fan;

        /* Broadcast (fan) shoutout. */
        emit ShoutoutPosted(
            _clubid,
            msg.sender,
            _love,
            _message
        );

        return true;
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
        bytes32 _clubid,
        uint _love
    ) external returns (bool) {
        /* Set (fan club) owner. */
        address owner = getOwner(_clubid);

        /* Validate club owner. */
        if (owner == address(0x0)) {
            /* Delegate call to predecessor. */
            return MiniAppsPartyFans(_predecessor).withdraw(_clubid, _love);
        }

        return true;
    }

    /***************************************************************************
     *
     * GETTERS
     *
     */

    /**
     * Get (Fan) Club
     *
     * Retrieve the complete details for a specific fan club.
     */
    function getClub(
        bytes32 _clubid
    ) external view returns (FanClub memory) {
        /* Initialize fan club. */
        FanClub memory club;

        /* Set fan club owner. */
        club.owner = getOwner(_clubid);

// TODO Re-build ALL properties from (public) getters.

        /* Return fan club. */
        return club;
    }

    /**
     * Get Fan
     *
     * Return a fan.
     */
    function getFan(
        address _fan
    ) external view returns (Fan memory) {
        /* Initialize fan. */
        Fan memory fan;// = _fans[_clubid][_fan];

// TODO Re-build properties w/ getters.

        /* Validate fan address. */
        if (fan.id == address(0x0)) {
            /* Delegate call to predecessor. */
            return MiniAppsPartyFans(_predecessor).getFan(_fan);
        }

        /* Return fan. */
        return fan;
    }

    /**
     * Get Fans
     *
     * Return the addresses of all fans w/ active shoutouts.
     */
    function getFans(
        bytes32 _clubid
    ) external view returns (address[] memory) {
        /* Initialize mini app. */
        FanClub memory club;// = _clubs[_clubid];

// TODO Re-build properties w/ getters.

        /* Validate mini app owner. */
        if (club.owner == address(0x0)) {
            /* Delegate call to predecessor. */
            return MiniAppsPartyFans(_predecessor).getFans(_clubid);
        }

        return club.fans;
    }

    /**
     * Get Love
     *
     * Retrieve the total amount of USDC a fan has deposited into the pool
     * for a specific fan club.
     */
    function getLove(
        bytes32 _clubid,
        address _fan
    ) public view returns (uint) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, ".total.", _clubid, ".love.for.", _fan
        ));

        /* Retrieve value from eternal database. */
        uint totalLove = _miniAppsPartyDb.getUint(hash);

        return totalLove;
    }

    /**
     * Get (Fan Club) Owner
     *
     * Return the address for the owner of a fan club.
     */
    function getOwner(
        bytes32 _clubid
    ) public view returns (address) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, ".owner.of.", _clubid
        ));

        /* Return value from eternal database. */
        return _miniAppsPartyDb.getAddress(hash);
    }

    /**
     * Get Shoutout
     *
     * Retrieve the total amount of USDC a fan has deposited into the pool
     * for a specific fan club.
     */
    function getShoutout(
        bytes32 _clubid,
        address _fan
    ) public view returns (string memory) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, _clubid, ".shoutout.by.", _fan
        ));

        /* Retrieve value from eternal database. */
        string memory message = _miniAppsPartyDb.getString(hash);

        /* Return (shoutout) message. */
        return message;
    }

    /**
     * Get Total Fan Clubs
     *
     * Return the total number of active fan clubs.
     */
    function getTotalClubs() external view returns (uint) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, ".total.fan.clubs"
        ));

        /* Retrieve value from eternal database. */
        uint totalClubs = _miniAppsPartyDb.getUint(hash);

        /* Return total number of fan clubs. */
        return totalClubs;
    }

    /**
     * Get Total Love
     *
     * Return the total amount of LOVE available for a fan club.
     */
    function getTotalLove(
        bytes32 _clubid
    ) public view returns (uint) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, ".total.love.for.", _clubid
        ));

        /* Retrieve value from eternal database. */
        uint totalLove = _miniAppsPartyDb.getUint(hash);

        /* Return total amount of LOVE in fan club. */
        return totalLove;
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

    /***************************************************************************
     *
     * UTILITIES
     *
     */

    /**
     * Generate Mini App ID
     *
     * Hashes the hostname of the mini app to generate a unique mini app ID.
     */
    function generateAppId(
        string calldata _hostname
    ) external pure returns (bytes32) {
        /* Generate a unique mini app ID. */
        bytes32 appid = keccak256(abi.encodePacked(_hostname));

        /* Return mini app ID. */
        return appid;
    }

    /**
     * Sort (Fans) by Love
     *
     * Will sort all fans within a club, based on the amount of LOVE they offer.
     */
    function sortByLove(
        bytes32 _clubid
    ) public view returns(Shoutout[] memory) {
        /* Retrieve all fans for club. */
        Shoutout[] memory shoutouts = _shoutouts[_clubid];

        /* Handle fan sorting. */
        for (uint i = 1; i < shoutouts.length; i++) {
            for (uint j = 0; j < i; j++) {
                if (shoutouts[i].love < shoutouts[j].love) {
                    Shoutout memory x = shoutouts[i];
                    shoutouts[i] = shoutouts[j];
                    shoutouts[j] = x;
                }
            }
        }

        return shoutouts;
    }
}
