// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDepositNodeOperatorDeployer.sol";
import "../interface/IDawnStorageInterface.sol";
import "./DepositNodeOperator.sol";

contract DepositNodeOperatorDeployer is IDepositNodeOperatorDeployer {
    bytes32 internal constant _OPERATOR_CREATION_SALT = keccak256("DepositNodeManager.OPERATOR_CREATION_SALT");
    IDawnStorageInterface internal _dawnStorage = IDawnStorageInterface(address(0));

    error InconsistentPredictedAddress(address predicted, address deployed);

    /// 仅限匹配最新部署的DawnPool合约
    modifier onlyLatestContract(string memory contractName, address contractAddress) {
        require(
            contractAddress ==
                IDawnStorageInterface(_dawnStorage).getAddress(
                    keccak256(abi.encodePacked("contract.address", contractName))
                ),
            "Invalid or outdated contract"
        );
        _;
    }

    constructor(IDawnStorageInterface dawnStorage) {
        _dawnStorage = dawnStorage;
    }

    function deployDepositNodeOperator(
        address operator
    ) external onlyLatestContract("DepositNodeManager", msg.sender) returns (address) {
        // Calculate address and set access
        address predictedAddress = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            _OPERATOR_CREATION_SALT,
                            keccak256(
                                abi.encodePacked(
                                    type(DepositNodeOperator).creationCode,
                                    abi.encode(operator, _dawnStorage)
                                )
                            )
                        )
                    )
                )
            )
        );
        IDawnStorageInterface(_dawnStorage).setBool(
            keccak256(abi.encodePacked("contract.exists", predictedAddress)),
            true
        );
        DepositNodeOperator nodeAddress = new DepositNodeOperator{salt: _OPERATOR_CREATION_SALT}(
            operator,
            _dawnStorage
        );
        if (predictedAddress != address(nodeAddress))
            revert InconsistentPredictedAddress(predictedAddress, address(nodeAddress));
        return address(nodeAddress);
    }
}
