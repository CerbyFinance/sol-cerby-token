// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;




/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}





/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant alphabet = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = alphabet[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

}









/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}



struct RoleAccess {
    bytes32 role;
    address addr;
}

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
}

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `ROLE_ADMIN`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `ROLE_ADMIN` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping (address => bool) members;
        bytes32 adminRole;
    }

    mapping (bytes32 => RoleData) private _roles;

    bytes32 public constant ROLE_ADMIN = 0x00;

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{20}) is missing role (0x[0-9a-f]{32})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{20}) is missing role (0x[0-9a-f]{32})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if(!hasRole(role, account)) {
            revert(string(abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(account), 20),
                " is missing role ",
                Strings.toHexString(uint256(role), 32)
            )));
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(ROLE_ADMIN) {
        _grantRole(role, account);
    }
    
    function grantRolesBulk(RoleAccess[] calldata roles)
        external
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i<roles.length; i++)
        {
            _setupRole(roles[i].role, roles[i].addr);
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        emit RoleAdminChanged(role, getRoleAdmin(role), adminRole);
        _roles[role].adminRole = adminRole;
    }

    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}





/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;

        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) { // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }


    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}


/**
 * @dev External interface of AccessControlEnumerable declared to support ERC165 detection.
 */
interface IAccessControlEnumerable {
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}

/**
 * @dev Extension of {AccessControl} that allows enumerating the members of each role.
 */
abstract contract AccessControlEnumerable is IAccessControlEnumerable, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping (bytes32 => EnumerableSet.AddressSet) private _roleMembers;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlEnumerable).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) public view override returns (address) {
        return _roleMembers[role].at(index);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) public view override returns (uint256) {
        return _roleMembers[role].length();
    }

    /**
     * @dev Overload {grantRole} to track enumerable memberships
     */
    function grantRole(bytes32 role, address account) public virtual override {
        super.grantRole(role, account);
        _roleMembers[role].add(account);
    }

    /**
     * @dev Overload {revokeRole} to track enumerable memberships
     */
    function revokeRole(bytes32 role, address account) public virtual override {
        super.revokeRole(role, account);
        _roleMembers[role].remove(account);
    }

    /**
     * @dev Overload {renounceRole} to track enumerable memberships
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        super.renounceRole(role, account);
        _roleMembers[role].remove(account);
    }

    /**
     * @dev Overload {_setupRole} to track enumerable memberships
     */
    function _setupRole(bytes32 role, address account) internal virtual override {
        super._setupRole(role, account);
        _roleMembers[role].add(account);
    }
}





struct AccessSettings {
        bool isMinter;
        bool isBurner;
        bool isTransferer;
        bool isModerator;
        bool isTaxer;
        
        address addr;
    }

interface IDefiFactoryToken {
    function approve(
        address _spender,
        uint _value
    )  external returns (
        bool success
    );
    
    function balanceOf(
        address account
    )
        external
        view
        returns (uint);
    
    function totalSupply()
        external
        view
        returns (uint);
        
    function chargeCustomTax(address from, uint amount)
        external;
        
    function mintHumanAddress(address to, uint desiredAmountToMint) external;

    function burnHumanAddress(address from, uint desiredAmountToBurn) external;

    function mintByBridge(address to, uint realAmountToMint) external;

    function burnByBridge(address from, uint realAmountBurn) external;
    
    function getUtilsContractAtPos(uint pos)
        external
        view
        returns (address);
        
    function transferFromTeamVestingContract(address recipient, uint256 amount) external;
    
    function correctTransferEvents(address[] calldata addrs)
        external;
    
    function publicForcedUpdateCacheMultiplier()
        external;
    
    function updateUtilsContracts(AccessSettings[] calldata accessSettings)
        external;
    
    function transferCustom(address sender, address recipient, uint256 amount)
        external;
}



struct IsHumanInfo {
    bool isHumanTransaction;
    bool isBuy;
    bool isSell;
}

interface IDeftStorageContract {
    
    function getBuyTimestamp(address tokenAddr, address addr)
        external
        view
        returns (uint);
    
    function updateBuyTimestamp(address tokenAddr, address addr, uint newBuyTimestamp)
        external;
        
    function isHumanTransaction(address tokenAddr, address sender, address recipient)
        external
        returns (IsHumanInfo memory);
    
    function isBotAddress(address addr)
        external
        view
        returns (bool);
    
    function isExcludedFromBalance(address addr)
        external
        view
        returns (bool);
    
    function bulkMarkAddressAsBot(address[] calldata addrs)
        external;
    
    function markAddressAsBot(address addr)
        external;
    
    function markAddressAsNotBot(address addr)
        external;
        
        
    function markPairAsDeftEthPair(address addr, bool value)
        external;
    
    function markPairAsDeftOtherPair(address addr, bool value)
        external;
}


contract CrossChainBridge is AccessControlEnumerable {
    event ProofOfBurn(address addr, address token, uint amount, uint amountAsFee, uint currentNonce, uint sourceChain, uint destinationChain, bytes32 transactionHash);
    event ProofOfMint(address addr, address token, uint amountAsFee, uint finalAmount, bytes32 transactionHash);
    event ApprovedTransaction(bytes32 transactionHash);
    event BulkApprovedTransactions(bytes32[] transactionHashes);
    event FeeUpdated(uint newFeePercent);
    
    enum States{ DefaultValue, Burned, Approved, Executed }
    mapping(bytes32 => States) public transactionStorage;
    
    uint constant NO_BOTS_TECH_CONTRACT_ID = 0;
    uint constant DEFT_STORAGE_CONTRACT_ID = 3;
    bytes32 public constant ROLE_APPROVER = keccak256("ROLE_APPROVER");
    
    
    address UNISWAP_V2_FACTORY_ADDRESS;
    address WETH_TOKEN_ADDRESS;
    
    mapping(address => uint) public currentNonce;
    address public beneficiaryAddress;
    
    mapping(address => mapping (uint => uint)) feeDependingOnDestinationChainId;
    
    uint constant ETH_MAINNET_CHAIN_ID = 1;
    uint constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint constant ETH_KOVAN_CHAIN_ID = 42;
    uint constant BSC_MAINNET_CHAIN_ID = 56;
    uint constant BSC_TESTNET_CHAIN_ID = 97;
    uint constant MATIC_MAINNET_CHAIN_ID = 137;
    
    address constant APPROVER_WALLET = 0xdEF78a28c78A461598d948bc0c689ce88f812AD8;
    
    struct SourceProofOfBurn {
        uint amountToBridge;
        uint amountAsFee;
        uint sourceChainId;
        uint sourceNonce;
        address sourceTokenAddr;
        bytes32 transactionHash;
    }
    
    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);
        _setupRole(ROLE_APPROVER, msg.sender);
        _setupRole(ROLE_APPROVER, APPROVER_WALLET);
        
        
        beneficiaryAddress = APPROVER_WALLET;
        
        
        /* Testnet */
        if (block.chainid == ETH_KOVAN_CHAIN_ID)
        {
            _setupRole(ROLE_ADMIN, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
            _setupRole(ROLE_APPROVER, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
            
            feeDependingOnDestinationChainId[0x40A24Fe8E4F7dDd2F614C0BC7e3d405b60f6a248][BSC_TESTNET_CHAIN_ID] = 1e5 * 1e18; // allow to bridge to bsc
        } else if (block.chainid == BSC_TESTNET_CHAIN_ID)
        {
            _setupRole(ROLE_ADMIN, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
            _setupRole(ROLE_APPROVER, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
            
            feeDependingOnDestinationChainId[0x40A24Fe8E4F7dDd2F614C0BC7e3d405b60f6a248][ETH_KOVAN_CHAIN_ID] = 2e6 * 1e18; // allow to bridge to eth
        }
        
        /* MAINNET */
        if (block.chainid == ETH_MAINNET_CHAIN_ID)
        {
            feeDependingOnDestinationChainId[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][BSC_MAINNET_CHAIN_ID] = 1e5 * 1e18; // allow to bridge to bsc
            feeDependingOnDestinationChainId[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][MATIC_MAINNET_CHAIN_ID] = 1e5 * 1e18; // allow to bridge to polygon
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID)
        {
            feeDependingOnDestinationChainId[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][ETH_MAINNET_CHAIN_ID] = 2e6 * 1e18; // allow to bridge to eth
            feeDependingOnDestinationChainId[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][MATIC_MAINNET_CHAIN_ID] = 1e5 * 1e18; // allow to bridge to polygon
        } else if (block.chainid == MATIC_MAINNET_CHAIN_ID)
        {
            feeDependingOnDestinationChainId[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][ETH_MAINNET_CHAIN_ID] = 2e6 * 1e18; // allow to bridge to eth
            feeDependingOnDestinationChainId[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][BSC_MAINNET_CHAIN_ID] = 1e5 * 1e18; // allow to bridge to bsc
        }
    }
    
    function getFeeDependingOnDestinationChainId(address tokenAddr, uint destinationChainId)
        public
        view
        returns(uint)
    {
        return feeDependingOnDestinationChainId[tokenAddr][destinationChainId];
    }
    
    function updateFeeDependingOnDestinationChainId(address token, uint chainId, uint amountAsFee)
        external
        onlyRole(ROLE_ADMIN)
    {
        feeDependingOnDestinationChainId[token][chainId] = amountAsFee;
    }
    
    function updateBeneficiaryAddress(address newBeneficiaryAddr)
        external
        onlyRole(ROLE_ADMIN)
    {
        beneficiaryAddress = newBeneficiaryAddr;
    }
    
    function markTransactionAsApproved(bytes32 transactionHash) 
        external
        onlyRole(ROLE_APPROVER)
    {
        require(
            transactionStorage[transactionHash] < States.Approved,
            "CCB: Already approved"
        );
        transactionStorage[transactionHash] = States.Approved;
        emit ApprovedTransaction(transactionHash);
    }
    
    function bulkMarkTransactionsAsApproved(bytes32[] memory transactionHashes) 
        external
        onlyRole(ROLE_APPROVER)
    {
        for(uint i=0; i<transactionHashes.length; i++)
        {
            if (transactionStorage[transactionHashes[i]] < States.Approved)
            {
                transactionStorage[transactionHashes[i]] = States.Approved;
            } else
            {
                transactionHashes[i] = 0x0;
            }
        }
        emit BulkApprovedTransactions(transactionHashes);
    }
    
    function mintWithBurnProof(SourceProofOfBurn memory sourceProofOfBurn) 
        external
    {
        require(
            transactionStorage[sourceProofOfBurn.transactionHash] == States.Approved,
            "CCB: Transaction is not approved or already executed"
        );
        
        bytes32 transactionHash = keccak256(abi.encodePacked(
                msg.sender, sourceProofOfBurn.sourceTokenAddr, sourceProofOfBurn.amountToBridge, sourceProofOfBurn.amountAsFee, sourceProofOfBurn.sourceChainId, block.chainid, sourceProofOfBurn.sourceNonce
            ));
        require(
            transactionHash == sourceProofOfBurn.transactionHash,
            "CCB: Provided hash is invalid"
        );
        
        uint amountAsFeeHasToBeLargerThanZero = feeDependingOnDestinationChainId[sourceProofOfBurn.sourceTokenAddr][sourceProofOfBurn.sourceChainId];
        require(
            amountAsFeeHasToBeLargerThanZero > 0,
            "CCB: Destination is forbidden (mint)"
        );
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(sourceProofOfBurn.sourceTokenAddr);
        if (
                block.chainid == ETH_MAINNET_CHAIN_ID ||
                block.chainid == MATIC_MAINNET_CHAIN_ID ||
                block.chainid == BSC_MAINNET_CHAIN_ID
            )
        {
            IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
                iDefiFactoryToken.getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
            );
            require(
                !iDeftStorageContract.isBotAddress(msg.sender),
                "CCB: Minting is temporary disabled!"
            );
        }
        
        transactionStorage[sourceProofOfBurn.transactionHash] = States.Executed;
        
        uint amountAsFee = sourceProofOfBurn.amountAsFee;
        uint finalAmount = sourceProofOfBurn.amountToBridge - amountAsFee; 
        
        iDefiFactoryToken.mintByBridge(msg.sender, finalAmount);
        
        emit ProofOfMint(msg.sender, sourceProofOfBurn.sourceTokenAddr, amountAsFee, finalAmount, transactionHash);
    }
    
    function burnAndCreateProof(address token, uint amount, uint destinationChainId) 
        external
    {
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(token);
        require(
            amount <= iDefiFactoryToken.balanceOf(msg.sender),
            "CCB: Amount must not exceed available balance. Try reducing the amount."
        );
        require(
            block.chainid != destinationChainId,
            "CCB: Destination chain must be different from current chain"
        );
        
        uint amountAsFee = feeDependingOnDestinationChainId[token][destinationChainId];
        require(
            amountAsFee > 0,
            "CCB: Destination is forbidden (burn)"
        );
        require(
            amount > amountAsFee,
            "CCB: Amount is lower than the minimum permitted amount"
        );
        
        if (
                block.chainid == ETH_MAINNET_CHAIN_ID ||
                block.chainid == MATIC_MAINNET_CHAIN_ID ||
                block.chainid == BSC_MAINNET_CHAIN_ID
            )
        {
            IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
                iDefiFactoryToken.getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
            );
            require(
                !iDeftStorageContract.isBotAddress(msg.sender),
                "CCB: Burning is temporary disabled!"
            );
        }
        
        bytes32 transactionHash = keccak256(abi.encodePacked(
                msg.sender, token, amount, amountAsFee, block.chainid, destinationChainId, currentNonce[token]
            ));
            
        transactionStorage[transactionHash] = States.Burned;
        
        iDefiFactoryToken.burnByBridge(msg.sender, amount);
        iDefiFactoryToken.mintHumanAddress(beneficiaryAddress, amountAsFee);
        
        emit ProofOfBurn(msg.sender, token, amount, amountAsFee, currentNonce[token], block.chainid, destinationChainId, transactionHash);
        currentNonce[token]++;
    }
}