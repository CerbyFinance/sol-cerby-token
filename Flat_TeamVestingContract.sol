// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT




interface IDefiFactoryToken {
    function mintHumanAddress(address to, uint desiredAmountToMint) external;

    function burnHumanAddress(address from, uint desiredAmountToBurn) external;

    function mintUniswapContract(address to, uint realAmountToMint) external;

    function burnUniswapContract(address from, uint realAmountBurn) external;
    
    function getUtilsContractAtPos(uint pos)
        external
        view
        returns (address);
        
    function transferFromTeamVestingContract(address recipient, uint256 amount) external;
}
// SPDX-License-Identifier: MIT



struct TaxAmountsInput {
    address sender;
    address recipient;
    uint transferAmount;
    uint senderBalance;
    uint recipientBalance;
}
struct TaxAmountsOutput {
    uint senderBalance;
    uint recipientBalance;
    uint burnAndRewardAmount;
    uint recipientGetsAmount;
}
struct TemporaryReferralRealAmountsBulk {
    address addr;
    uint realBalance;
}

interface INoBotsTech {
    function prepareTaxAmounts(
        TaxAmountsInput calldata taxAmountsInput
    ) 
        external
        returns(TaxAmountsOutput memory taxAmountsOutput);
    
    function getTemporaryReferralRealAmountsBulk(address[] calldata addrs)
        external
        view
        returns (TemporaryReferralRealAmountsBulk[] memory);
        
    function prepareHumanAddressMintOrBurnRewardsAmounts(bool isMint, address account, uint desiredAmountToMintOrBurn)
        external
        returns (uint realAmountToMintOrBurn);
        
    function prepareUniswapMintOrBurnRewardsAmounts(bool isMint, address account, uint realAmountToMintOrBurn)
        external;
        
    function getBalance(address account, uint accountBalance)
        external
        view
        returns(uint);
        
    function getRealBalance(address account, uint accountBalance)
        external
        view
        returns(uint);
        
    function getRealBalanceTeamVestingContract(uint accountBalance)
        external
        view
        returns(uint);
        
    function getTotalSupply()
        external
        view
        returns (uint);
        
    function grantRole(bytes32 role, address account) 
        external;
        
    function getCalculatedReferrerRewards(address addr, address[] calldata referrals)
        external
        view
        returns (uint);
        
    function getCachedReferrerRewards(address addr)
        external
        view
        returns (uint);
    
    function updateReferrersRewards(address[] calldata referrals)
        external;
    
    function clearReferrerRewards(address addr)
        external;
    
    function chargeCustomTax(uint taxAmount, uint accountBalance)
        external
        returns (uint);
    
    function chargeCustomTaxPreBurned(uint taxAmount)
        external;
        
    function registerReferral(address referral, address referrer)
        external;
        
    function filterNonZeroReferrals(address[] calldata referrals)
        external
        view
        returns (address[] memory);
    
    event MultiplierUpdated(uint newMultiplier);
    event BotTransactionDetected(address from, address to, uint transferAmount, uint taxedAmount);
    event ReferralRewardUpdated(address referral, uint amount);
    event ReferralRegistered(address referral, address referrer);
    event ReferralDeleted(address referral, address referrer);
}
// SPDX-License-Identifier: MIT



interface IUniswapV2Factory {
    
    function getPair(
        address tokenA,
        address tokenB
    )
        external
        view
        returns (address);
        
    function createPair(
        address tokenA,
        address tokenB
    ) 
        external
        returns (address);
        
}

// SPDX-License-Identifier: MIT



interface IUniswapV2Pair {
    
    function sync()
        external;
        
    function getReserves()
        external
        view
        returns (uint, uint, uint32);
        
    function token0()
        external
        view
        returns (address);
        
    function token1()
        external
        view
        returns (address);
        
    function mint(address to) 
        external
        returns (uint);       
    
    function swap(
        uint amount0Out, 
        uint amount1Out, 
        address to, 
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT




interface IWeth {

    function balanceOf(
        address account
    )
        external
        view
        returns (uint);
        
    function decimals()
        external
        view
        returns (uint);

    function transfer(
        address _to,
        uint _value
    )  external returns (
        bool success
    );
        
        
    function deposit()
        external
        payable;

    function withdraw(
        uint wad
    ) external;

    function approve(
        address _spender,
        uint _value
    )  external returns (
        bool success
    );
}

// SPDX-License-Identifier: MIT



// SPDX-License-Identifier: MIT



// SPDX-License-Identifier: MIT



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

// SPDX-License-Identifier: MIT



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

// SPDX-License-Identifier: MIT



// SPDX-License-Identifier: MIT



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
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
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

// SPDX-License-Identifier: MIT



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



contract TeamVestingContract is AccessControlEnumerable {
    bytes32 public constant ROLE_WHITELIST = keccak256("ROLE_WHITELIST");
    bytes32 public constant ROLE_NOTAX = keccak256("ROLE_NOTAX");
    
    uint constant NOBOTS_TECH_CONTRACT_ID = 0;
    uint constant UNISWAP_V2_FACTORY_CONTRACT_ID = 2;

    struct Investor {
        address addr;
        uint wethValue;
        uint sentValue;
        uint startDelay;
        uint lockFor;
    }
    
    enum States { AcceptingPayments, ReachedGoal, PreparedAddLiqudity, CreatedPair, AddedLiquidity, DistributedTokens }
    States public state;
    
    mapping(address => uint) cachedIndex;
    Investor[] investors;
    uint public totalInvested;
    uint public totalSent;
    
    address public defiFactoryToken = 0x2493e2D8a80d95AF4e4d2C1448a29c34Ba27ca30;
    
    uint public constant TOTAL_SUPPLY_CAP = 1 * 1e9 * 1e18; // 1B
    
    uint public percentForTheTeam = 30;
    uint public percentForUniswap = 70;
    uint constant PERCENT_DENORM = 100;
    
    address public nativeToken;
    
    address public developerAddress;
    uint public developerCap = 150e13;
    uint public constant DEVELOPER_STARTING_LOCK_DELAY = 0 days;
    uint public constant DEVELOPER_STARTING_LOCK_FOR = 10 minutes; // TODO: Change on production
    
    address public teamAddress;
    uint public teamCap = 100e13;
    uint public constant TEAM_STARTING_LOCK_DELAY = 0 days;
    uint public constant TEAM_STARTING_LOCK_FOR = 730 days;
    
    address public marketingAddress;
    uint public marketingCap = 50e13;
    uint public constant MARKETING_STARTING_LOCK_DELAY = 0;
    uint public constant MARKETING_STARTING_LOCK_FOR = 365;
    
    uint public startedLocking;
    address public wethAndTokenPairContract;
    
    
    uint amountOfTokensForInvestors;
    
    address constant BURN_ADDRESS = address(0x0);
    
    constructor () payable { // TODO: remove payable on production
        
        _setupRole(ROLE_ADMIN, _msgSender());
        
        // TODO: remove on production
        updateInvestmentSettings(
            0xd0A1E359811322d97991E03f863a0C30C2cF029C, // WETH kovan
            0x539FaA851D86781009EC30dF437D794bCd090c8F, 150e13, // dev
            0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6, 100e13, // team
            0xE019B37896f129354cf0b8f1Cf33936b86913A34, 50e13 // marketing
        );
        
        state = States.AcceptingPayments;
        
        // TODO: remove on production
        addInvestor(msg.sender, msg.value);
        checkIfGoalIsReachedAndPrepareLiqudity();
    }

    receive() external payable {
        require(state == States.AcceptingPayments, "VestingContract: Accepting payments has been stopped!");
        
        addInvestor(msg.sender, msg.value);
    }
    
    modifier onlyAdmins {
        require(hasRole(ROLE_ADMIN, _msgSender()), "VestingContract: !ROLE_ADMIN");
        _;
    }

    function addInvestor(address addr, uint wethValue)
        internal
    {
        uint updMaxInvestAmount;
        uint lockFor;
        uint startDelay;
        if (addr == developerAddress)
        {
            updMaxInvestAmount = developerCap;
            lockFor = DEVELOPER_STARTING_LOCK_FOR;
            startDelay = DEVELOPER_STARTING_LOCK_DELAY;
        } else if (addr == teamAddress)
        {
            updMaxInvestAmount = teamCap;
            lockFor = TEAM_STARTING_LOCK_FOR;
            startDelay = TEAM_STARTING_LOCK_DELAY;
        } else if (addr == marketingAddress) 
        {
            updMaxInvestAmount = marketingCap;
            lockFor = MARKETING_STARTING_LOCK_FOR;
            startDelay = MARKETING_STARTING_LOCK_DELAY;
        } else
        {
            updMaxInvestAmount = 0;
            lockFor = 36500 days;
            startDelay = 36500 days;
        }
        
        if (cachedIndex[addr] == 0)
        {
            investors.push(
                Investor(
                    addr, 
                    wethValue,
                    0,
                    startDelay,
                    lockFor
                )
            );
            cachedIndex[addr] = investors.length;
        } else
        {
            investors[cachedIndex[addr] - 1].wethValue += wethValue;
        }
        require(
            investors[cachedIndex[addr] - 1].wethValue <= updMaxInvestAmount,
            "VestingContract: Requires Investor max amount less than maxInvestAmount!"
        );
        
        totalInvested += wethValue;
    }
    
    function checkIfGoalIsReachedAndPrepareLiqudity()
        public
        onlyAdmins
    {
        state = States.ReachedGoal;
        
        prepareAddLiqudity();
    }
    
    function prepareAddLiqudity()
        internal
        onlyAdmins
    {
        require(state == States.ReachedGoal, "VestingContract: Preparing add liquidity is completed!");
        require(address(this).balance > 0, "VestingContract: Ether balance must be larger than zero!");
        
        IWeth iWeth = IWeth(nativeToken);
        iWeth.deposit{ value: address(this).balance }();
        
        state = States.PreparedAddLiqudity;
    }
    
    function createPairAndAddLiqudity()
        public
        onlyAdmins
    {
        require(state == States.PreparedAddLiqudity, "VestingContract: Pair is already created!");

        IUniswapV2Factory iUniswapV2Factory = IUniswapV2Factory(
            IDefiFactoryToken(defiFactoryToken).
                getUtilsContractAtPos(UNISWAP_V2_FACTORY_CONTRACT_ID)
        );
        wethAndTokenPairContract = iUniswapV2Factory.getPair(defiFactoryToken, nativeToken);
        if (wethAndTokenPairContract == BURN_ADDRESS)
        {
            wethAndTokenPairContract = iUniswapV2Factory.createPair(defiFactoryToken, nativeToken);
        }
           
        INoBotsTech iNoBotsTech = INoBotsTech(
            IDefiFactoryToken(defiFactoryToken).
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        ); 
        iNoBotsTech.grantRole(ROLE_WHITELIST, wethAndTokenPairContract);
        
        state = States.CreatedPair;
        
        addLiquidity();
    }
    
    function addLiquidity()
        internal
        onlyAdmins
    {
        require(state == States.CreatedPair, "VestingContract: Liquidity is already added!");
        
        IWeth iWeth = IWeth(nativeToken);
        uint wethAmount = iWeth.balanceOf(address(this));
        iWeth.transfer(wethAndTokenPairContract, wethAmount);
        
        uint amountOfTokensForUniswap = (TOTAL_SUPPLY_CAP * percentForUniswap) / PERCENT_DENORM; // 70% for uniswap
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.mintHumanAddress(wethAndTokenPairContract, amountOfTokensForUniswap);
        
        IUniswapV2Pair iPair = IUniswapV2Pair(wethAndTokenPairContract);
        iPair.mint(_msgSender());
    
        state = States.AddedLiquidity;
        
        distributeTokens();
    }

    function distributeTokens()
        internal
        onlyAdmins
    {
        require(state == States.AddedLiquidity, "VestingContract: Tokens have already been distributed!");
        
        INoBotsTech iNoBotsTech = INoBotsTech(
            IDefiFactoryToken(defiFactoryToken).
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        );
        
        iNoBotsTech.grantRole(ROLE_WHITELIST, address(this));
        iNoBotsTech.grantRole(ROLE_NOTAX, address(this));
        
        amountOfTokensForInvestors = (TOTAL_SUPPLY_CAP * percentForTheTeam) / PERCENT_DENORM; // 30% for the team
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.mintHumanAddress(address(this), amountOfTokensForInvestors);
        
        startedLocking = block.timestamp;
        
        state = States.DistributedTokens;
    }
    
    function claimTeamVestingTokens(uint amount)
        public
    {
        address addr = msg.sender;
        
        uint claimableAmount = getClaimableTokenAmount(addr);
        require(claimableAmount > 0, "VestingContract: !claimable_amount");
        
        if (
            amount == 0 || 
            amount > claimableAmount
        ) {
            amount = claimableAmount;
        }
        require(amount <= claimableAmount, "VestingContract: !amount");
        require(cachedIndex[addr] > 0, "VestingContract: !exists_addr");
        
        investors[cachedIndex[addr] - 1].sentValue += amount;
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.transferFromTeamVestingContract(addr, amount);
    }
    
    function burnVestingTokens(uint amount)
        public
        onlyAdmins
    {
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.burnHumanAddress(address(this), amount);
        
        INoBotsTech iNoBotsTech = INoBotsTech(
            IDefiFactoryToken(defiFactoryToken).
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        );
        amountOfTokensForInvestors -= iNoBotsTech.getRealBalanceTeamVestingContract(amount);
    }
    
    function taxVestingTokens(uint amount)
        public
        onlyAdmins
    {
        INoBotsTech iNoBotsTech = INoBotsTech(
            IDefiFactoryToken(defiFactoryToken).
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        );
        
        amountOfTokensForInvestors = iNoBotsTech.chargeCustomTax(
            amount, 
            amountOfTokensForInvestors
        );
    }
    
    function getClaimableTokenAmount(address addr)
        public
        view
        returns(uint)
    {
        require(state == States.DistributedTokens, "VestingContract: Tokens aren't distributed yet!");
        
        require(cachedIndex[addr] > 0, "VestingContract: !exist");
        
        Investor memory investor = investors[cachedIndex[addr] - 1];
        
        uint realStartedLocking = startedLocking + investor.startDelay;
        if (block.timestamp < realStartedLocking) return 0;
        
        uint lockedUntil = realStartedLocking + investor.lockFor; 
        uint nominator = 1;
        uint denominator = 1;
        if (block.timestamp < lockedUntil)
        {
            nominator = block.timestamp - realStartedLocking;
            denominator = investor.lockFor;
        }
            
        uint claimableAmount = 
            (investor.wethValue * amountOfTokensForInvestors * nominator) / 
                (denominator * totalInvested);
                
        if (claimableAmount <= investor.sentValue) return 0;
        claimableAmount -= investor.sentValue;
        
        return claimableAmount;
    }
    
    function getLeftTokenAmount(address addr)
        public
        view
        returns(uint)
    {
        require(state == States.DistributedTokens, "VestingContract: Tokens aren't distributed yet!");
        
        if (addr == BURN_ADDRESS) addr = msg.sender;
        Investor memory investor = investors[cachedIndex[msg.sender] - 1];
        uint leftAmount = 
            (investor.wethValue * amountOfTokensForInvestors) / 
                (totalInvested);
                
        if (leftAmount <= investor.sentValue) return 0;
        leftAmount -= investor.sentValue;
        
        return leftAmount;
    }
    
    function getInvestorsCount()
        public
        view
        returns(uint)
    {
        return investors.length;
    }
    
    function getInvestorByAddr(address addr)
        external
        view
        returns(Investor memory)
    {
        return investors[cachedIndex[addr] - 1];
    }
    
    function getInvestorByPos(uint pos)
        external
        view
        returns(Investor memory)
    {
        return investors[pos];
    }
    
    function listInvestors(uint offset, uint limit)
        public
        view
        returns(Investor[] memory)
    {
        uint start = offset;
        uint end = offset + limit;
        end = (end > investors.length)? investors.length: end;
        uint numItems = (end > start)? end - start: 0;
        
        Investor[] memory listOfInvestors = new Investor[](numItems);
        for(uint i = start; i < end; i++)
        {
            listOfInvestors[i - start] = investors[i];
        }
        
        return listOfInvestors;
    }
    
    function updateDefiFactoryContract(address newContract)
        external
        onlyAdmins
    {
        defiFactoryToken = newContract;
    }
    
    function updateInvestmentSettings(
        address _nativeToken, 
        address _developerAddress, uint _developerCap,
        address _teamAddress, uint _teamCap,
        address _marketingAddress, uint _marketingCap
    )
        public
        onlyAdmins
    {
        nativeToken = _nativeToken;
        developerAddress = _developerAddress;
        developerCap = _developerCap;
        teamAddress = _teamAddress;
        teamCap = _teamCap;
        marketingAddress = _marketingAddress;
        marketingCap = _marketingCap;
    }
}