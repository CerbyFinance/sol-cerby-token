mkdir  -p compiled

# solc -o ../bin/ --bin --abi --optimize --overwrite ../CerbySwapLP1155V1.sol
# solc -o ../bin/ --bin --abi --optimize --overwrite ../WETH.sol
solc -o ../bin/ --bin --abi --overwrite ../CrossChainBridgeV2.sol
solc -o ../bin/ --bin --abi --optimize --overwrite ../TestNamedToken.sol

cp ../bin/*.abi ./abis