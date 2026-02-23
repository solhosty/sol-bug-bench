// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title AdvancedVaultProxy
 * @dev Minimal proxy with intentional storage collision vulnerability
 *
 * This proxy demonstrates upgrade pattern flaws:
 * - Storage layout mismatch with implementation
 * - Unprotected upgrade function
 * - Admin slot clobbering via delegatecall
 */
contract AdvancedVaultProxy {
    // STORAGE LAYOUT - Intentionally different from AdvancedVault
    // This causes slot collision when delegatecalling
    
    // Slot 0: In AdvancedVault this is balances mapping
    address public implementation;
    
    // Slot 1: In AdvancedVault this is shares mapping  
    address public admin;
    
    // Slot 2: In AdvancedVault this is oracle
    uint256 public version;
    
    // Events
    event Upgraded(address indexed implementation);
    event AdminChanged(address indexed newAdmin);

    /**
     * @dev Constructor sets initial implementation and admin
     */
    constructor(address _implementation, address _admin) {
        implementation = _implementation;
        admin = _admin;
        version = 1;
    }

    /**
     * @dev VULNERABLE: Anyone can upgrade the implementation
     * No access control on upgrade function
     */
    function upgradeTo(address newImplementation) external {
        // VULNERABILITY: No access control check
        implementation = newImplementation;
        version++;
        emit Upgraded(newImplementation);
    }

    /**
     * @dev VULNERABLE: Admin can be changed by anyone
     */
    function changeAdmin(address newAdmin) external {
        // VULNERABILITY: No access control
        admin = newAdmin;
        emit AdminChanged(newAdmin);
    }

    /**
     * @dev Fallback function delegates all calls to implementation
     * VULNERABILITY: Storage collision when implementation writes to slots 0, 1, 2
     * which would overwrite implementation, admin, and version in this proxy
     */
    fallback() external payable {
        address impl = implementation;
        require(impl != address(0), "Implementation not set");
        
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}
