import fs from "fs";
import path from "path";
import Web3 from "web3";

require("dotenv").config();

const { PRIVATE_KEY } = process.env;

const web3 = new Web3(
  new Web3.providers.HttpProvider(
    //"https://data-seed-prebsc-1-s1.binance.org:8545/",
    //"https://kovan.infura.io/v3/6af3a6f4302246e8bbd4e69b5bfc9e33"
    "https://ropsten.infura.io/v3/6af3a6f4302246e8bbd4e69b5bfc9e33"
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
      gasPrice: 3e9+1,
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
    fs.readFileSync(path.resolve("../artifacts/DefiFactoryToken.json"), "utf8"),
  );
  const noBotsTechJson = JSON.parse(
    fs.readFileSync(path.resolve("../artifacts/NoBotsTech.json"), "utf8"),
  );
  const teamVestingJson = JSON.parse(
    fs.readFileSync(
      path.resolve("../artifacts/TeamVestingContract.json"),
      "utf8",
    ),
  );

  const fill1Items = JSON.parse(
    fs.readFileSync(path.resolve("./files/fill1.json"), "utf8"),
  );

  const manyRefItems = Array.from({
    length: 6,
  }).map((_, i) =>
    JSON.parse(
      fs.readFileSync(path.resolve("./files/", `ref${i + 1}.json`), "utf8"),
    ),
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
    "NoBotsTech",
    noBotsTechJson,
    account,
    0,
  );

  console.log("NoBotsTech: ", noBotsTechContract.options.address);

  const teamVestingContract = await deployContract(
    "TeamVestingContract",
    teamVestingJson,
    account,
    15e14,
  );

  console.log("TeamVestingContract: ", teamVestingContract.options.address);

  // const [defiFactoryTokenContract, noBotsTechContract, teamVestingContract] =
  //   await Promise.all([
  //     deployContract("DefiFactoryToken", defiFactoryJson, account, 0),
  //     deployContract("NoBotsTech", noBotsTechJson, account, 0),
  //     deployContract("TeamVestingContract", teamVestingJson, account, 15e14),
  //   ]);

  let nonce = await web3.eth.getTransactionCount(account);

  console.log({
    nonce,
  });

  // prettier-ignore
  async function step1() {
    //console.log("DefiFactoryToken.updateUtilsContracts: " + new Date());

    try {
      const transaction = await defiFactoryTokenContract.methods.updateUtilsContracts([
        [false, false, false, false, false, noBotsTechContract.options.address],
        [true, true, true, true, true, teamVestingContract.options.address],
        [false, false, false, false, false, "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"], //Uniswap factory v2
        //[false, false, false, false, false, "0xB7926C0430Afb07AA7DEfDE6DA862aE0Bde767bc"], //Pancake factory v2
      ])

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 3e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log('step1 ok')
  
    } catch (error) {
      console.log(error.message);
    }
  }

  // prettier-ignore
  async function step2() {
    //console.log("NoBotsTech.grantRolesBulk: " + new Date());
    try {
      const transaction = await noBotsTechContract.methods.grantRolesBulk([
        ["0x0000000000000000000000000000000000000000000000000000000000000000", defiFactoryTokenContract.options.address],
        ["0x0000000000000000000000000000000000000000000000000000000000000000", teamVestingContract.options.address],
        ["0xd27488087fca693adcf8b477ec0ca6cf5134d7f124fdc511eb258522c40fd72b", teamVestingContract.options.address],
        ["0xbd68ab95cda3c90ac0bffc2b3a3a97a564372fc3ca4a8e4575d3ce58179b7563", teamVestingContract.options.address]
      ])

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 3e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log('step2 ok')
  
    } catch (error) {
      console.log(error.message);
    }
  }

  // prettier-ignore
  async function step3() {
    //console.log("TeamVestingContract.updateDefiFactoryContract: " + new Date());
    try {
      const transaction = await teamVestingContract.methods.updateDefiFactoryContract(defiFactoryTokenContract.options.address)

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 3e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log('step3 ok')
  
    } catch (error) {
      console.log(error.message);
    }
  }

  // prettier-ignore
  async function step4() {
    return
    //console.log("TeamVestingContract.updateInvestmentSettings: " + new Date());
    try {
      /*const transaction = await teamVestingContract.methods
      .updateInvestmentSettings(
        //"0x094616F0BdFB0b526bD735Bf66Eca0Ad254ca81F", // WBNB testnet
        //"0xd0A1E359811322d97991E03f863a0C30C2cF029C", // WETH kovan
        "0xc778417E063141139Fce010982780140Aa0cD5Ab", // WETH ropsten
        "0x539FaA851D86781009EC30dF437D794bCd090c8F", 150e13, // dev address & cap
        "0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6", 100e13, // team address & cap
        "0xE019B37896f129354cf0b8f1Cf33936b86913A34", 50e13 // marketing address & cap
      )

      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 3e9+1,
      }, _account.privateKey);

      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log('step4 ok')*/
  
    } catch (error) {
      console.log(error.message);
    }
  }

  async function step5() {
    return;
    //console.log("NoBotsTech.updateReCachePeriod: " + new Date());
    try {
      const transaction = await noBotsTechContract.methods.updateReCachePeriod(
        60,
      );

      const signed = await web3.eth.accounts.signTransaction(
        {
          nonce: nonce++,
          to: transaction._parent._address,
          data: transaction.encodeABI(),
          gas: await transaction.estimateGas({ from: account }),
          gasPrice: 3e9+1,
        },
        _account.privateKey,
      );

      const receipt = await web3.eth.sendSignedTransaction(
        signed.rawTransaction!,
      );

      console.log("step5 ok");
    } catch (error) {
      console.log(error.message);
    }
  }

  await Promise.all([step1(), step2(), step3(), step4(), step5()]);

  // prettier-ignore
  try {
    const transaction = await teamVestingContract.methods.createPair()

    const signed  = await web3.eth.accounts.signTransaction({
      nonce   : nonce++,
      to      : transaction._parent._address,
      data    : transaction.encodeABI(),
      gas: await transaction.estimateGas({from: account}),
      gasPrice: 3e9+1,
    }, _account.privateKey);

    const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

    console.log('create pair ok')

  } catch (error) {
    console.log(error.message);
  }

  
  /*
  try {
    const transaction = await teamVestingContract.methods.addLiquidity()

    const signed  = await web3.eth.accounts.signTransaction({
      nonce   : nonce++,
      to      : transaction._parent._address,
      data    : transaction.encodeABI(),
      gas: await transaction.estimateGas({from: account}),
      gasPrice: 3e9+1,
    }, _account.privateKey);

    const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

    console.log('add liquidity ok')

  } catch (error) {
    console.log(error.message);
  }
  
  // prettier-ignore
  async function refN(refItems: any[]) {
    //console.log("NoBotsTech.updateReCachePeriod: " + new Date());
    try {
      const transaction = await defiFactoryTokenContract.methods.registerReferralsBulk(refItems)
  
      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 3e9+1,
      }, _account.privateKey);
  
      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log('refN ok')
  
    } catch (error) {
      console.log(error.message);
    }
  }

  // prettier-ignore
  async function fill1() {
    //console.log("NoBotsTech.updateReCachePeriod: " + new Date());
    try {
      const transaction = await noBotsTechContract.methods.fillTestReferralTemporaryBalances(fill1Items)
  
      const signed  = await web3.eth.accounts.signTransaction({
        nonce   : nonce++,
        to      : transaction._parent._address,
        data    : transaction.encodeABI(),
        gas: await transaction.estimateGas({from: account}),
        gasPrice: 3e9+1,
      }, _account.privateKey);
  
      const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log('fill1 ok')
  
    } catch (error) {
      console.log(error.message);
    }
   
  }

  const chunks = chunk<any>(manyRefItems, 3);

  for (const items of chunks) {
    await Promise.all(items.map(item => refN(item)));
  }

  await fill1();*/
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