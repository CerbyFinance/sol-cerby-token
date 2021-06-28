import fs from "fs";
import path from "path";
import Web3 from "web3";

require("dotenv").config();

const { PRIVATE_KEY } = process.env;
const APPROVER_WALLET_ADDRESS = "0xa044c17fC7E0076C856eE3A8a71a527E5d11caDD";
//const DEFT_STORAGE_ADDRESS = "0x23b14094ba274a210Fc0CE95054915C50d16a477"; // BSC Testnet
const DEFT_STORAGE_ADDRESS = "0x1700d9698bB791b4aBB795657DCC6509B7f14cC6"; // Kovan
const CROSS_CHAIN_BRIDGE_ADDRESS = "0x537b503609273524940F3DE4F8EC407cC7eE2459"; // Kovan
const UNISWAP_V2_FACTORY = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"; // Uniswap
//const UNISWAP_V2_FACTORY = "0x6725F303b657a9451d8BA641348b6761A6CC7a17"; // BSC Testnet
/*
  For BSC Testnet swaps
  const UNISWAP_V2_ROUTER = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"; // BSC Testnet
  const NATIVE_TOKEN_ADDRESS = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd"; // BSC Testnet
  https://swap.extraffix.com/#/swap
*/

/* Kovan latest version
current block: 25775315
DeftStorageContract:  0x1700d9698bB791b4aBB795657DCC6509B7f14cC6
DefiFactoryToken:  0xC0138126C0Bd394C547df17B649B81B543c76906
NoBotsTechV2:  0x97b14887Fed9666FA283691530778Acee8DEAE74
LiquidityHelper:  0x9c369c5124d1fF290d1c001Bc2570abc095EB25c
CrossChainBridge:  0x537b503609273524940F3DE4F8EC407cC7eE2459
*/

const web3 = new Web3(
  new Web3.providers.HttpProvider(
    //"https://data-seed-prebsc-1-s1.binance.org:8545/",
    "https://kovan.infura.io/v3/6af3a6f4302246e8bbd4e69b5bfc9e33"
    //"https://ropsten.infura.io/v3/6af3a6f4302246e8bbd4e69b5bfc9e33"
  ),
);

async function deployContract(
  contractName: string,
  metadata: any,
  account: string,
  value: number,
) {
  try {
    const contractFromAbi = new web3.eth.Contract(metadata.abi);

    const contract = contractFromAbi.deploy({
      data: metadata.data.bytecode.object,
      arguments: [],
    });

    const newContractInstance = await contract.send({
      from: account,
      gas: 6e6,
      // @ts-ignore
      gasPrice: 2e9+1,
      value,
    });

    return newContractInstance;
  } catch (error) {
    console.log(contractName + ": " + error.message);

    return new web3.eth.Contract([]);
  }
}

const start = async () => {
  if (!PRIVATE_KEY) {
    throw new Error("private key not found");
  }

  const _account = web3.eth.accounts.privateKeyToAccount(PRIVATE_KEY);
  web3.eth.accounts.wallet.add(_account);
  web3.eth.defaultAccount = _account.address;
  const account = _account.address;

  const defiFactoryJson = JSON.parse(
    fs.readFileSync(path.resolve("../DEFT/artifacts/DefiFactoryToken.json"), "utf8"),
  );
  const noBotsTechJson = JSON.parse(
    fs.readFileSync(path.resolve("../artifacts/NoBotsTechV2.json"), "utf8"),
  );
  const liquidityHelperJson = JSON.parse(
    fs.readFileSync(path.resolve("../artifacts/LiquidityHelper.json"), "utf8"),
  );
  const deftStorageJson = JSON.parse(
    fs.readFileSync(path.resolve("../artifacts/DeftStorageContract.json"), "utf8"),
  );
  const crossChainBridgeJson = JSON.parse(
    fs.readFileSync(path.resolve("../artifacts/CrossChainBridge.json"), "utf8"),
  );

  const currentBlock = await web3.eth.getBlockNumber();
  console.log("current block:", currentBlock);

  const deftStorageContract = new web3.eth.Contract(
    // @ts-ignore
    deftStorageJson.abi,
    DEFT_STORAGE_ADDRESS,
  )
  console.log("DeftStorageContract: ", deftStorageContract.options.address);

  const defiFactoryTokenContract = await deployContract(
    "DefiFactoryToken",
    defiFactoryJson,
    account,
    0,
  );
  console.log("DefiFactoryToken: ", defiFactoryTokenContract.options.address);

  const noBotsTechContract = await deployContract(
    "NoBotsTechV2",
    noBotsTechJson,
    account,
    0,
  );
  console.log("NoBotsTechV2: ", noBotsTechContract.options.address);

  const liquidityHelperContract = await deployContract(
    "LiquidityHelper",
    liquidityHelperJson,
    account,
    1e15,
  );
  console.log("LiquidityHelper: ", liquidityHelperContract.options.address);



  /*const crossChainBridgeContract = await deployContract(
    "CrossChainBridge",
    crossChainBridgeJson,
    account,
    0,
  );*/

  const crossChainBridgeContract = new web3.eth.Contract(
    // @ts-ignore
    crossChainBridgeJson.abi,
    CROSS_CHAIN_BRIDGE_ADDRESS,
  )
  console.log("CrossChainBridge: ", crossChainBridgeContract.options.address);


  let nonce = await web3.eth.getTransactionCount(account);

  console.log({
    nonce,
  });

  // prettier-ignore
  async function stepDeftUtilsContracts() {
    let funcName = 'stepDeftUtilsContracts';
    try {
      const transaction = await defiFactoryTokenContract.methods.updateUtilsContracts([
        [true, true, false, false, true, noBotsTechContract.options.address],
        [true, true, false, false, false, liquidityHelperContract.options.address],
        [false, false, false, false, false, UNISWAP_V2_FACTORY],
        [false, false, false, false, false, deftStorageContract.options.address],
      ])

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 2e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }
  
  // prettier-ignore
  async function stepNoBotsRoles() {
    let funcName = 'stepNoBotsRoles';
    try {
      const transaction = await noBotsTechContract.methods.grantRolesBulk([
        ["0x0000000000000000000000000000000000000000000000000000000000000000", defiFactoryTokenContract.options.address],
      ])

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 2e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }
  
  // prettier-ignore
  async function stepDeftStorageRoles() {
    let funcName = 'stepDeftStorageRoles';
    try {
      const transaction = await deftStorageContract.methods.grantRolesBulk([
        ["0x0000000000000000000000000000000000000000000000000000000000000000", liquidityHelperContract.options.address],
        ["0x0000000000000000000000000000000000000000000000000000000000000000", noBotsTechContract.options.address],
        ["0x0000000000000000000000000000000000000000000000000000000000000000", APPROVER_WALLET_ADDRESS],
      ])

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 2e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }
  
  // prettier-ignore
  async function stepDeftStorageMarkAsHuman() {
    let funcName = 'stepDeftStorageMarkAsHuman';
    try {
      const transaction = await deftStorageContract.methods.markAddressAsHuman(noBotsTechContract.options.address, true)

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 2e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }
  
  // prettier-ignore
  async function stepDeftRoleMinter() {
    let funcName = 'stepDeftRoleMinter';
    try {
      const transaction = await defiFactoryTokenContract.methods.grantRole(
        "0xaeaef46186eb59f884e36929b6d682a6ae35e1e43d8f05f058dcefb92b601461", crossChainBridgeContract.options.address
      )

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 2e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }
  
  // prettier-ignore
  async function stepDeftRoleBurner() {
    let funcName = 'stepDeftRoleBurner';
    try {
      const transaction = await defiFactoryTokenContract.methods.grantRole(
        "0xb5b5a86cc252b1b75a439c6ff372933ceb0690188924e6461150adeb00ab80d8", crossChainBridgeContract.options.address
      )

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 2e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }
  
  // prettier-ignore
  async function stepUpdateDeftContractInNoBots() {
    let funcName = 'stepUpdateDeftContractInNoBots';
    try {
      const transaction = await noBotsTechContract.methods.updateDefiFactoryTokenAddress(defiFactoryTokenContract.options.address)

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 2e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }
  
  // prettier-ignore
  async function stepUpdateDeftContractInLiquidityHelper() {
    let funcName = 'stepUpdateDeftContractInLiquidityHelper';
    try {
      const transaction = await liquidityHelperContract.methods.updateDefiFactoryTokenAddress(defiFactoryTokenContract.options.address)

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 2e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }
  
   
  // prettier-ignore
  async function stepUpdateDeftContractInCrossChainSwap() {
    let funcName = 'stepUpdateDeftContractInCrossChainSwap';
    try {
      const transaction = await crossChainBridgeContract.methods.updateMainTokenContract(defiFactoryTokenContract.options.address)

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 2e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }
  
  // prettier-ignore
  async function stepDeftRoles() {
    let funcName = 'stepDeftRoles';
    try {
      const transaction = await defiFactoryTokenContract.methods.grantRole(
        "0x0000000000000000000000000000000000000000000000000000000000000000", liquidityHelperContract.options.address
      )

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 2e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }

  

  await Promise.all([
    stepDeftUtilsContracts(),
    stepNoBotsRoles(),
    stepDeftStorageRoles(),
    stepUpdateDeftContractInNoBots(),
    stepUpdateDeftContractInLiquidityHelper(),
    stepDeftRoles(),
    stepDeftStorageMarkAsHuman(),
    /*stepDeftRoleMinter(),
    stepDeftRoleBurner(),
    stepUpdateDeftContractInCrossChainSwap()*/
  ]);

  // prettier-ignore
  async function createPairOnUniswapV2() {
    let funcName = 'createPairOnUniswapV2';
    try {
      const transaction = await liquidityHelperContract.methods.createPairOnUniswapV2()

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 2e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }

  // prettier-ignore
  async function addLiquidityOnUniswapV2() {
    let funcName = 'addLiquidityOnUniswapV2';
    try {
      const transaction = await liquidityHelperContract.methods.addLiquidityOnUniswapV2()

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 2e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log('added liquidity')
  
    } catch (error) {
      console.log(error.message);
    }
  }
  
  await createPairOnUniswapV2();
  //await delay(1000);
  await addLiquidityOnUniswapV2();
  
};

start();

function chunk<T>(arr: T[], len: number) {
  var chunks = [] as T[][],
    i = 0,
    n = arr.length;

  while (i < n) {
    // @ts-ignore
    chunks.push(arr.slice(i, (i += len)));
  }

  return chunks;
}

function delay(ms: number)
{
  return new Promise(resolve => setTimeout(resolve, ms));
}
