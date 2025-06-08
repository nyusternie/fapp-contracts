/*******************************************************************************
 *
 * Copyright (c) 2025 shomari.eth
 * SPDX-License-Identifier: MIT
 *
 * Mini Apps Party Sponsors
 *
 * Apps that have paid to be "boosted" throughout the platform.
 *
 * Version 1 (alpha)
 * Released 25.6.7
 *
 * https://miniapps.party/sponsors
 */
pragma solidity ^0.8.9;

import { Ownable } from "../interfaces/Ownable.sol";
import { IERC20 } from "../interfaces/IERC20.sol";
import { IMiniAppsPartyDb } from "../interfaces/IMiniAppsPartyDb.sol";

contract MiniAppsPartySponsors is Ownable {
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
    //       Cast Casino database keys; in order to prevent ANY accidental or
    //       malicious SQL-injection vulnerabilities / attacks.
    string private _namespace = "miniapps.party";

    /* Initialize chain id. */
    // !! IMPORTANT NOTE: THIS VALUE MUST BE UPDATED FOR EACH NETWORK !!
    // !! IMPORTANT NOTE: THIS VALUE MUST BE UPDATED FOR EACH NETWORK !!
    // !! IMPORTANT NOTE: THIS VALUE MUST BE UPDATED FOR EACH NETWORK !!
    // Base = 8453
    // Base (Sepolia) = 84532
    // Degen = 666666666
    uint CHAIN_ID = 8453;

    /* Initialize maximum seats per table. */
    // NOTE: This will be REMOVED after WAGMI is enabled.
    uint8 MAX_SEATS_PER_TABLE = 23;

    /* Initilaize maximum FOMO level. */
    // up to 20% inflation per buy-in
    uint8 MAX_FOMO_LEVEL = 20;

    /* Initialize maximum time-to-sit. */
    // 86400 seconds == 24 hours
    uint MAX_TIME_TO_SIT = 86400;

    /* Initialize tables handler. */
    // tableid => Table
    mapping(uint => Table) private _tables;

    /* Initialize players. */
    // tableid => (player) address => Player
    mapping(uint => mapping(address => Player)) private _players;

    /* Gameplay (Round) State */
    enum GameplayState {
        Unset,      // unused venue
        Set,        // venue created and waiting for community cards
        Community,  // community cards have been dealt
        Showdown,   // players cards have been dealt
        Closed      // all payouts sent and the table is closed
    }

    /* Initialize table schema. */
    // NOTE: If no token is specified, the network's "native" coin is used instead.
    //       e.g. $BASE, $DEGEN, $ETH, $OP
    struct Table {
        GameplayState state;
        address token;              // token used for participating at the table
        address host;               // table/game creator
        uint seed;                  // a random number, provided by the host, used to deal community cards
        uint buyin;                 // buy-in amount for the table
        uint tts;                   // a.k.a time-to-sit - duration of seating time before cards are dealt
        uint pot;                   // total pot size from player buy-ins
        uint paid;                  // total payouts sent to players
        uint8 seats;                // maximum number of players allowed at the table
        uint8 fomo;                 // an inflation mechanism, triggered after each buy-in (default is 0)
        uint8 theme;                // set artwork (or suit) display on "special" cards [default is Hearts]
        CommunityCards community;   // community cards for the table
        address[] seated;           // seated players (w/ buy-in) at the table
    }

    /* Initialize (player) cards schema. */
    struct Player {
        address id;
        uint seed;
        PlayerCards cards;
    }

    /* Initialize (player) cards schema. */
    struct PlayerCards {
        int8 hole1;
        int8 hole2;
    }

    /* Initialize (community) cards schema. */
    struct CommunityCards {
        uint8 flop1;
        uint8 flop2;
        uint8 flop3;
        uint8 turn;
        uint8 river;
    }

    /* Initialize (emit) events. */
    event TableCreated(
        uint indexed tableid,
        Table table
    );
    event CommunityCardsDealt(
        uint indexed tableid,
        uint8 flop1,
        uint8 flop2,
        uint8 flop3,
        uint8 turn,
        uint8 river
    );
    event BuyIn(
        uint indexed tableid,
        Player player
    );
    event PlayerCardsDealt(
        uint indexed tableid,
        address player,
        int8 hole1,
        int8 hole2
    );
    event PlayersCardsDealt(
        uint indexed tableid,
        address[] players,
        int8[] hole1,
        int8[] hole2
    );
    event Payout(
        uint indexed tableid,
        uint pot,
        uint amount
    );

    /* Constructor */
    constructor() {
        /* Initialize Cast Casino (eternal) storage database contract. */
        // NOTE We hard-code the address here, since it should never change.
        _miniAppsPartyDb = IMiniAppsPartyDb(0x045a1e7D4274cB2704Fc1C8598777B3d450D4b49);

        /* Initialize (aname) hash. */
        bytes32 hash = keccak256(abi.encodePacked("aname.", _namespace));

        /* Set predecessor address. */
        _predecessor = payable(_miniAppsPartyDb.getAddress(hash));

        /* Verify predecessor address. */
        if (_predecessor != address(0)) {
            /* Retrieve the last revision number (if available). */
            uint lastRevision = MiniAppsPartySponsors(_predecessor).getRevision();

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
     * @dev Only allow access to an authorized Cast Casino provider.
     */
    modifier onlyAuthByCastCasino() {
        /* Verify write access is only permitted to authorized providers. */
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
     * Set Table
     *
     * A host MUST begin a hand by first setting the table. This process
     * involves generating sufficient entropy to Deal the Flop.
     *
     * NOTE: Randomization occurs by utilzing the block hashes of the *NEXT*
     *       blocks produced by the miners.
     *
     * @param _token Primary token used for buy-ins.
     * @param _buyin Minimum amount of tokens required to enter the table.
     * @param _tts Time-to-sit (in seconds), before play begins.
     * @param _seats Maximum number of players allowed at this table.
     */
    function setTable(
        address _token,
        uint _seed,
        uint _buyin,
        uint _tts,
        uint8 _seats,
        uint8 _fomo,
        uint8 _theme
    ) external returns (uint) {
        require(_tts <= MAX_TIME_TO_SIT,
            "Oops! Your maximum seating time is OVER the casino limit.");

        require(_seats <= MAX_SEATS_PER_TABLE,
            "Oops! Your maximum player seats is OVER the casino limit.");

        require(_fomo <= MAX_FOMO_LEVEL,
            "Oops! Your FOMO level is OVER the casino limit.");

        /* Initialize community cards. */
        CommunityCards memory community;

        /* Initialize (seated player) address handler. */
        address[] memory seated;

        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, ".total.tables"
        ));

        /* Retrieve value from Cast Casino database. */
        uint totalTables = _miniAppsPartyDb.getUint(hash);

        /* Initialize the table. */
        _tables[totalTables] = Table({
            state: GameplayState.Set,
            token: _token,
            host: msg.sender,
            seed: _seed,
            buyin: _buyin,
            tts: _tts,
            pot: 0,
            paid: 0,
            seats: _seats,
            fomo: _fomo,
            theme: _theme,
            community: community,
            seated: seated
        });

        /* Broadcast event. */
        emit TableCreated(totalTables, _tables[totalTables]);

        /* Update (increment) table count. */
        _miniAppsPartyDb.setUint(hash, totalTables + 1);

        return totalTables;
    }

    /**
     * Deal Community Cards
     *
     * The platorm begins each hand by dealing a flop + turn + river.
     *
     * NOTE: A flop is three (3) "random" cards provided for all participating
     *       players to utilize in forming their final hand.
     *
     * NOTE: A host MUST "set the table" BEFORE dealing the flop.
     */
    function dealCommunityCards(
        uint _tableid,
        uint8 _flop1,
        uint8 _flop2,
        uint8 _flop3,
        uint8 _turn,
        uint8 _river
    ) external onlyAuthByCastCasino {
        /* Initialize table. */
        Table storage table = _tables[_tableid];

        /* Validate table status. */
        require(table.state == GameplayState.Set,
            "Oops! This table is NOT ready for (community) dealing.");

        /* Set community cards. */
        table.community.flop1 = _flop1;
        table.community.flop2 = _flop2;
        table.community.flop3 = _flop3;
        table.community.turn = _turn;
        table.community.river = _river;

        /* Emit community cards. */
        emit CommunityCardsDealt(
            _tableid,
            _flop1,
            _flop2,
            _flop3,
            _turn,
            _river
        );

        /* Update table state to COMMUNITY. */
        table.state = GameplayState.Community;
    }

    /**
     * Buy-In
     *
     * Allows a player to join the table.
     *
     * A single player may buy-in (i.e. be seated) more than once.
     *
     * NOTE: ONLY externally owned accounts are permitted to buy in.
     *       This offers a better UX for players, as the casino
     *       will then automatically deliver payouts after the
     *       completion of each hand.
     *
     * @param _tableid the unique id of the table.
     */
    function buyIn(
        uint _tableid,
        uint _seed
    ) external payable {
        /* Validate sender (is NOT a contract). */
        require(_isContract(msg.sender) == false,
            "Oops! You CANNOT buy-in using a smart wallet. Please use a standard EOA wallet.");

        /* Initialize table. */
        Table storage table = _tables[_tableid];

        /* Validate table host. */
        if (table.host == address(0x0)) {
            /* Delegate call to predecessor. */
            return CastPoker(_predecessor).buyIn(_tableid, _seed);
        }

        /* Validate table status. */
        require(table.state == GameplayState.Community,
            "Oops! This table is NOT ready for buy-ins.");

        require(table.seated.length < MAX_SEATS_PER_TABLE,
            "Oops! This table is already full!");

        /* Validate player is unique (to this table). */
        require(_players[_tableid][msg.sender].id == address(0),
            "Oops! You CANNOT sit more than once at the same table.");

        /* Validate deposit method. */
        // NOTE: Support is available for either the network's
        //       native coin OR an ERC-20 token.
        if (table.token == address(0)) {
            require(msg.value == table.buyin,
                "Oops! That's NOT the buy-in amount to join this table.");
        } else {
            // NOTE: MUST FIRST pre-authorize this contract with an allowance
            //       from the player's wallet.

            /* Transfer buy-in amount from player to table/contract. */
            require(IERC20(table.token).transferFrom(msg.sender, address(this), table.buyin),
                "Oops! You DO NOT have a sufficient balance to buy-in with that asset.");
        }

        /* Add buy-in to pot. */
        table.pot = table.pot + table.buyin;

        /* Assign player (id/address) to the next seat. */
        table.seated.push(msg.sender);

        /* Create player (object). */
        Player memory player = Player(
            msg.sender,
            _seed,
            PlayerCards(-1, -1) // NOTE: 0 is reserved for Ace-of-Spades
        );

        /* Add to players. */
        _players[_tableid][msg.sender] = player;

        /* Broadcast (player) buy-in. */
        emit BuyIn(_tableid, player);
    }

    /**
     * Deal Player Cards
     *
     * Distributes the cards for a participating player.
     *
     * NOTE: An event is kept onchain so that other players can later verify
     *       that there was no cheating.
     */
    function dealCards(
        uint _tableid,
        address[] calldata _playersPool,
        int8[] calldata _hole1Pool,
        int8[] calldata _hole2Pool
    ) external onlyAuthByCastCasino {
        /* Initialize table. */
        Table storage table = _tables[_tableid];

        /* Validate table host. */
        if (table.host == address(0x0)) {
            /* Delegate call to predecessor. */
            return CastPoker(_predecessor).dealCards(
                _tableid, _playersPool, _hole1Pool, _hole2Pool);
        }

        /* Validate table status. */
        require(table.state == GameplayState.Community,
            "Oops! This table DOES NOT have a community yet.");

        /* Initialize counter. */
        uint i;

        /* Handle multiple players. */
        for (i = 0; i < _playersPool.length; i++) {
            /* Validate hole cards. */
            require(
                _players[_tableid][_playersPool[i]].cards.hole1 == -1 &&
                _players[_tableid][_playersPool[i]].cards.hole2 == -1,
                "Oops! Cards have already been dealt to that player."
            );

            /* Set player (hole) cards. */
            _players[_tableid][_playersPool[i]].cards.hole1 = _hole1Pool[i];
            _players[_tableid][_playersPool[i]].cards.hole2 = _hole2Pool[i];
        }

        /* Broadcast cards dealt. */
        emit PlayersCardsDealt(
            _tableid,
            _playersPool,
            _hole1Pool,
            _hole2Pool
        );
    }

    /**
     * Showdown
     *
     * Compare all player cards and determine the winner of the hand.
     */
    function showdown(
        uint _tableid
    ) external onlyAuthByCastCasino returns (bool) {
        /* Initialize table. */
        Table storage table = _tables[_tableid];

        /* Validate table host. */
        if (table.host == address(0x0)) {
            /* Delegate call to predecessor. */
            return CastPoker(_predecessor).showdown(_tableid);
        }

        /* Validate table status. */
        require(table.state == GameplayState.Community,
            "Oops! This table is NOT ready for a showdown.");

        /* Update table state to SHOWDOWN. */
        // NOTE: This function (and status update) is called for each player.
        table.state = GameplayState.Showdown;

        return true;
    }

    /**
     * Payout
     *
     * Allows the casino to distribute winnings to the respective players.
     *
     * NOTE: Chip totals are stored in the Cast Casino database.
     */
    function payout(
        uint _tableid,
        address _player,
        uint _amount
    ) external onlyAuthByCastCasino returns (bool) {
        /* Initialize table. */
        Table storage table = _tables[_tableid];

        /* Validate table host. */
        if (table.host == address(0x0)) {
            /* Delegate call to predecessor. */
            return CastPoker(_predecessor).payout(_tableid, _player, _amount);
        }

        /* Validate table status. */
        require(
            table.state == GameplayState.Showdown ||
            table.state == GameplayState.Closed,
            "Oops! This table is NOT ready for payouts and completion."
        );

        /* Validate payout amount. */
        require(table.pot >= (table.paid + _amount),
            "Oops! You CANNOT payout more than the pot size.");

        /* Update paid amount. */
        // NOTE: Calculate before "action" is taken (prevent re-entry exploitation).
        table.paid = table.paid + _amount;

        /* Validate deposit method. */
        // NOTE: Support is available for either the network's
        //       native coin OR an ERC-20 token.
        if (table.token == address(0)) {
            (bool success, ) = _player.call{ value: _amount}("");

            require(success, "Oops! Asset transfer has failed!");
        } else {
            /* Transfer payout amount from contract to player. */
            require(IERC20(table.token).transfer(_player, _amount),
                "Oops! Token transfer has failed!");
        }

        /* Initialize asset id. */
        uint assetid;

        /* Set the table asset id. */
        // NOTE: Used during payout for chips disbursements.
        if (table.token == address(0)) {
            assetid = CHAIN_ID;
        } else {
            assetid = uint160(table.token);
        }

        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, ".total.", assetid, ".chips.for.", _player
        ));

        /* Retrieve value from Cast Casino database. */
        uint totalChips = _miniAppsPartyDb.getUint(hash);

        /* Update new total chips. */
        _miniAppsPartyDb.setUint(hash, totalChips + _amount);

        return true;
    }

    /**
     * Close Table
     *
     * Everyone has been paid and the table is now closed.
     */
    function closeTable(
        uint _tableid
    ) external onlyAuthByCastCasino returns (bool) {
        /* Initialize table. */
        Table storage table = _tables[_tableid];

        /* Validate table host. */
        if (table.host == address(0x0)) {
            /* Delegate call to predecessor. */
            return CastPoker(_predecessor).closeTable(_tableid);
        }

        /* Validate table status. */
        require(table.state == GameplayState.Showdown,
            "Oops! This table CANNOT be closed yet.");

        /* Update table state to COMPLETED. */
        table.state = GameplayState.Closed;

        return true;
    }

    /***************************************************************************
     *
     * GETTERS
     *
     */

    /**
     * Get Chips
     *
     * Retrieve the total number of chips a player has earned
     * for a specific asset.
     */
    function getChips(
        uint _chainid,
        address _assetid,
        address _player
    ) external view returns (uint) {
        /* Initialize asset id. */
        uint assetid;

        if (_assetid == address(0)) {
            assetid = _chainid;
        } else {
            assetid = uint160(_assetid);
        }

        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, ".total.", assetid, ".chips.for.", _player
        ));

        /* Retrieve value from Cast Casino database. */
        uint totalChips = _miniAppsPartyDb.getUint(hash);

        return totalChips;
    }

    /**
     * Get Player
     *
     * Return a player.
     */
    function getPlayer(
        uint _tableid,
        address _address
    ) external view returns (Player memory) {
        /* Initialize player. */
        Player storage player = _players[_tableid][_address];

        /* Validate player address. */
        if (player.id == address(0x0)) {
            /* Delegate call to predecessor. */
            return CastPoker(_predecessor).getPlayer(_tableid, _address);
        }

        return player;
    }

    /**
     * Get Seated
     *
     * Return the addresses of all players currently seated.
     */
    function getSeated(
        uint _tableid
    ) external view returns (address[] memory) {
        /* Initialize table. */
        Table storage table = _tables[_tableid];

        /* Validate table host. */
        if (table.host == address(0x0)) {
            /* Delegate call to predecessor. */
            return CastPoker(_predecessor).getSeated(_tableid);
        }

        return table.seated;
    }

    /**
     * Get Tables
     *
     * Return a table.
     */
    function getTable(
        uint _tableid
    ) external view returns (Table memory) {
        /* Initialize table. */
        Table storage table = _tables[_tableid];

        /* Validate table host. */
        if (table.host == address(0x0)) {
            /* Delegate call to predecessor. */
            return CastPoker(_predecessor).getTable(_tableid);
        }

        return table;
    }

    /**
     * Get Total Tables
     *
     * Total number of tables created by hosts.
     */
    function getTotalTables() external view returns (uint) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, ".total.tables"
        ));

        /* Retrieve value from Cast Casino database. */
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
    ) external onlyAuthByCastCasino returns (bool success) {
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
     * Is Contract
     *
     * Will determine (with reasonable certainty, if an address
     * belongs to a contract.
     */
    function _isContract(address _addr) internal view returns (bool) {
        /* Initialize size. */
        uint size;

        /* Calculate size. */
        assembly { size := extcodesize(_addr) }

        /* Evaluate size. */
        return size > 0;
    }
}
