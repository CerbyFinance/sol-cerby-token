import fs from "fs";
import path from "path";
import Web3 from "web3";

require("dotenv").config();

const { PRIVATE_KEY } = process.env;

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

  const currentBlock = await web3.eth.getBlockNumber();
  console.log("current block:", currentBlock);

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


  let nonce = await web3.eth.getTransactionCount(account);

  console.log({
    nonce,
  });

  // prettier-ignore
  async function step1() {
    try {
      const transaction = await defiFactoryTokenContract.methods.updateUtilsContracts([
        [true, true, false, false, false, noBotsTechContract.options.address],
        [true, true, false, false, false, liquidityHelperContract.options.address],
        [false, false, false, false, false, "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"], //Uniswap factory v2
        //[false, false, false, false, false, "0xB7926C0430Afb07AA7DEfDE6DA862aE0Bde767bc"], //Pancake factory v2
      ])

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 2e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log('step1 ok')
  
    } catch (error) {
      console.log(error.message);
    }
  }

  // prettier-ignore
  async function step2() {
    try {
      const transaction = await noBotsTechContract.methods.grantRolesBulk([
        ["0x0000000000000000000000000000000000000000000000000000000000000000", defiFactoryTokenContract.options.address],
        ["0x0000000000000000000000000000000000000000000000000000000000000000", liquidityHelperContract.options.address],
      ])

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 2e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log('step2 ok')
  
    } catch (error) {
      console.log(error.message);
    }
  }

  // prettier-ignore
  async function step3() {
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

      console.log('step3 ok')
  
    } catch (error) {
      console.log(error.message);
    }
  }

  // prettier-ignore
  async function step4() {
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

      console.log('step4 ok')
  
    } catch (error) {
      console.log(error.message);
    }
  }

  

  await Promise.all([step1(), step2(), step3(), step4()]);



  // prettier-ignore
  async function createPairOnUniswapV2() {
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

      console.log('created pair')
  
    } catch (error) {
      console.log(error.message);
    }
  }

  // prettier-ignore
  async function addLiquidityOnUniswapV2() {
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
