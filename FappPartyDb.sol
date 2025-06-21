pragma solidity ^0.8.9;

/*******************************************************************************
 *
 * Copyright (c) 2025 shomari.eth
 * SPDX-License-Identifier: MIT
 *
 * FappPartyDb
 *
 * An eternal database, providing a sustainable storage solution for use
 * throughout the upgrade lifecycle of managing contracts.
 *
 * Released 25.6.21
 *
 * https://fapp.party
 */

import { Ownable } from "./interfaces/Ownable.sol";

/*******************************************************************************
 * FappParty Db Contract
 */
contract FappPartyDb is Ownable {
    /* Initialize all storage types. */
    mapping(bytes32 => address)    private addressStorage;
    mapping(bytes32 => bool)       private boolStorage;
    mapping(bytes32 => bytes)      private bytesStorage;
    mapping(bytes32 => int256)     private intStorage;
    mapping(bytes32 => string)     private stringStorage;
    mapping(bytes32 => uint256)    private uIntStorage;

    /**
     * @dev Only allow access from the latest version of a FappParty
     *      contract or authorized FappParty administrator(s).
     */
    modifier onlyAuthByPartyHosts() {
        /***********************************************************************
         * The owner is only allowed to set the authorized contracts upon
         * deployment, to register the initial contracts, afterwards their
         * direct access is permanently disabled.
         */
        if (msg.sender == owner()) {
            /* Verify owner's write access has not already been disabled. */
            require(boolStorage[keccak256(
                abi.encodePacked('owner.auth.disabled'))] != true);
        } else {
            /* Verify write access is only permitted to authorized accounts. */
            require(boolStorage[keccak256(
                abi.encodePacked(msg.sender, '.has.auth'))] == true);
        }

        _;      // function code is inserted here
    }

    /***************************************************************************
     * Initialize all getter methods.
     */

    /// @param _key The key for the record
    function getAddress(bytes32 _key) external view returns (address) {
        return addressStorage[_key];
    }

    /// @param _key The key for the record
    function getBool(bytes32 _key) external view returns (bool) {
        return boolStorage[_key];
    }

    /// @param _key The key for the record
    function getBytes(bytes32 _key) external view returns (bytes memory) {
        return bytesStorage[_key];
    }

    /// @param _key The key for the record
    function getInt(bytes32 _key) external view returns (int) {
        return intStorage[_key];
    }

    /// @param _key The key for the record
    function getString(bytes32 _key) external view returns (string memory) {
        return stringStorage[_key];
    }

    /// @param _key The key for the record
    function getUint(bytes32 _key) external view returns (uint) {
        return uIntStorage[_key];
    }


    /***************************************************************************
     * Initialize all setter methods.
     */

    /// @param _key The key for the record
    function setAddress(bytes32 _key, address _value) onlyAuthByPartyHosts external {
        addressStorage[_key] = _value;
    }

    /// @param _key The key for the record
    function setBool(bytes32 _key, bool _value) onlyAuthByPartyHosts external {
        boolStorage[_key] = _value;
    }

    /// @param _key The key for the record
    function setBytes(bytes32 _key, bytes calldata _value) onlyAuthByPartyHosts external {
        bytesStorage[_key] = _value;
    }

    /// @param _key The key for the record
    function setInt(bytes32 _key, int _value) onlyAuthByPartyHosts external {
        intStorage[_key] = _value;
    }

    /// @param _key The key for the record
    function setString(bytes32 _key, string calldata _value) onlyAuthByPartyHosts external {
        stringStorage[_key] = _value;
    }

    /// @param _key The key for the record
    function setUint(bytes32 _key, uint _value) onlyAuthByPartyHosts external {
        uIntStorage[_key] = _value;
    }


    /***************************************************************************
     * Initialize all delete methods.
     */

    /// @param _key The key for the record
    function deleteAddress(bytes32 _key) onlyAuthByPartyHosts external {
        delete addressStorage[_key];
    }

    /// @param _key The key for the record
    function deleteBool(bytes32 _key) onlyAuthByPartyHosts external {
        delete boolStorage[_key];
    }

    /// @param _key The key for the record
    function deleteBytes(bytes32 _key) onlyAuthByPartyHosts external {
        delete bytesStorage[_key];
    }

    /// @param _key The key for the record
    function deleteInt(bytes32 _key) onlyAuthByPartyHosts external {
        delete intStorage[_key];
    }

    /// @param _key The key for the record
    function deleteString(bytes32 _key) onlyAuthByPartyHosts external {
        delete stringStorage[_key];
    }

    /// @param _key The key for the record
    function deleteUint(bytes32 _key) onlyAuthByPartyHosts external {
        delete uIntStorage[_key];
    }
}
