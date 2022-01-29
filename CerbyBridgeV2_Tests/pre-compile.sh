mkdir  -p compiled

solc -o ../bin/ --bin --abi --overwrite ../CerbyBridgeV2.sol
solc -o ../bin/ --bin --abi --optimize --overwrite ../TestNamedToken.sol

cp ../bin/*.abi ./abis