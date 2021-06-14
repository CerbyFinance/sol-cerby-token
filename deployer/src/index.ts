import fs from "fs";
import path from "path";
import Web3 from "web3";

require("dotenv").config();

const { PRIVATE_KEY } = process.env;
//const DEFT_STORAGE_ADDRESS = "0xA8B08BD4F7dECdD532c517a9793C050Ac7Debf00"; // Kovan
const DEFT_STORAGE_ADDRESS = "0x23b14094ba274a210Fc0CE95054915C50d16a477"; // BSC Testnet
//const DEFT_STORAGE_ADDRESS = "0xC238D647c258eb276c2e520134e2218012D8F05b"; // Kovan
//const UNISWAP_V2_FACTORY = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"; // Uniswap
const UNISWAP_V2_FACTORY = "0x6725F303b657a9451d8BA641348b6761A6CC7a17"; // BSC Testnet
//const UNISWAP_V2_ROUTER = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"; // BSC Testnet
//const NATIVE_TOKEN_ADDRESS = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd"; // BSC Testnet
// https://swap.extraffix.com/#/swap

const web3 = new Web3(
  new Web3.providers.HttpProvider(
    "https://data-seed-prebsc-1-s1.binance.org:8545/",
    //"https://kovan.infura.io/v3/6af3a6f4302246e8bbd4e69b5bfc9e33"
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
      gasPrice: 10e9+1,
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



  const crossChainBridgeContract = await deployContract(
    "CrossChainBridge",
    crossChainBridgeJson,
    account,
    0,
  );
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
        [true, true, false, false, false, noBotsTechContract.options.address],
        [true, true, false, false, false, liquidityHelperContract.options.address],
        [false, false, false, false, false, UNISWAP_V2_FACTORY],
        [false, false, false, false, false, deftStorageContract.options.address],
      ])
      // pancake testnet router https://testnet.bscscan.com/address/0xD99D1c33F9fC3444f8101754aBC46c52416550D1#readContract

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 10e9+1,
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
        gasPrice: 10e9+1,
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
      ])

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 10e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }
  
  // prettier-ignore
  async function stepDeftStorageBuyTimestamp1() {
    let funcName = 'stepDeftStorageBuyTimestamp1';
    try {
      let buyTimestamp = new Date() 
      buyTimestamp.setDate(buyTimestamp.getDate() - 35)

      const transaction = await deftStorageContract.methods.updateBuyTimestamp(
        defiFactoryTokenContract.options.address,
        "0x539FaA851D86781009EC30dF437D794bCd090c8F",
        Math.floor(buyTimestamp.getTime() / 1000)
      )

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 10e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }
  
  // prettier-ignore
  async function stepDeftStorageBuyTimestamp2() {
    let funcName = 'stepDeftStorageBuyTimestamp2';
    try {
      let buyTimestamp = new Date() 
      buyTimestamp.setDate(buyTimestamp.getDate() - 140)

      const transaction = await deftStorageContract.methods.updateBuyTimestamp(
        defiFactoryTokenContract.options.address,
        "0xAAa96EB7c2b9C22144f8B742a5Afdabab3b6781f",
        Math.floor(buyTimestamp.getTime() / 1000)
      )

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 10e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }
  
  // prettier-ignore
  async function stepDeftStorageBuyTimestamp3() {
    let funcName = 'stepDeftStorageBuyTimestamp3';
    try {
      let buyTimestamp = new Date() 
      buyTimestamp.setDate(buyTimestamp.getDate() - 333)

      const transaction = await deftStorageContract.methods.updateBuyTimestamp(
        defiFactoryTokenContract.options.address,
        "0xBbB6AE3051C5b486836a32193D8D191572C7cC1D",
        Math.floor(buyTimestamp.getTime() / 1000)
      )

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 10e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log(funcName, ' ok')
  
    } catch (error) {
      console.log(funcName, ' ', error.message);
    }
  }
  
  // prettier-ignore
  async function stepDeftStorageBuyTimestamp4() {
    let funcName = 'stepDeftStorageBuyTimestamp4';
    try {
      let buyTimestamp = new Date() 
      buyTimestamp.setDate(buyTimestamp.getDate() - 600)

      const transaction = await deftStorageContract.methods.updateBuyTimestamp(
        defiFactoryTokenContract.options.address,
        "0x987De8C41CB9e166E51a4913e560c08c2760EfE5",
        Math.floor(buyTimestamp.getTime() / 1000)
      )

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 10e9+1,
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
        gasPrice: 10e9+1,
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
        gasPrice: 10e9+1,
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
        gasPrice: 10e9+1,
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
        gasPrice: 10e9+1,
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
        gasPrice: 10e9+1,
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
        gasPrice: 10e9+1,
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
    stepDeftRoleMinter(),
    stepDeftRoleBurner(),
    stepUpdateDeftContractInCrossChainSwap(),
    stepDeftStorageBuyTimestamp1(),
    stepDeftStorageBuyTimestamp2(),
    stepDeftStorageBuyTimestamp3(),
    stepDeftStorageBuyTimestamp4(),
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
        gasPrice: 10e9+1,
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
        gasPrice: 10e9+1,
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
