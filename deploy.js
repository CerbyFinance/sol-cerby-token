(async () => {
    console.log("Deploying: " + new Date());
    
    const account = (await web3.eth.getAccounts())[0];
    /*const ethNetwork = 'https://kovan.infura.io/v3/6af3a6f4302246e8bbd4e69b5bfc9e33';
    let web3 = await new Web3(new Web3.providers.WebsocketProvider(ethNetwork))
    let accountInst = web3.eth.accounts.
        privateKeyToAccount("0xc7c9d41a50ac661df0f0e5eb8b788135a6ded1581d088b42898487296cf3fefb");
    web3.eth.accounts.wallet.add(accountInst);
    let account = accountInst.address;*/

    let defiFactoryJson = JSON.parse(await remix.call('fileManager', 'getFile', "sol-defifactory-token/artifacts/DefiFactoryToken.json"));
    let noBotsTechJson = JSON.parse(await remix.call('fileManager', 'getFile', "sol-nobots-tech/artifacts/NoBotsTech.json"));
    let teamVestingJson = JSON.parse(await remix.call('fileManager', 'getFile', "sol-defifactory-token/artifacts/TeamVestingContract.json"));
    
    let [defiFactoryTokenContract, noBotsTechContract, teamVestingContract] = await Promise.all([
        deployContract("DefiFactoryToken", defiFactoryJson, account, 0),
        deployContract("NoBotsTech", noBotsTechJson, account, 0),
        deployContract("TeamVestingContract", teamVestingJson, account, 15e14)
    ]);
    
    console.log("DefiFactoryToken: ", defiFactoryTokenContract.options.address);
    console.log("NoBotsTech: ", noBotsTechContract.options.address);
    console.log("TeamVestingContract: ", teamVestingContract.options.address);
    
    async function step1() {
        //console.log("DefiFactoryToken.updateUtilsContracts: " + new Date());
        try {
            await defiFactoryTokenContract.methods.
                updateUtilsContracts([
                    [false, false, false, false, false, noBotsTechContract.options.address],
                    [true, true, true, true, true, teamVestingContract.options.address],
                    [false, false, false, false, false, "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"]
                ]).send({
                    from: account, 
                    gas: 1e6,
                    gasPrice: 2e9 + 1,
                    value: 0
                })
            .then(function (result) {
                //console.log(result);
            });
        }
        catch (error) { console.log(error.message);fail; }
    }
    
    async function step2() {
        //console.log("NoBotsTech.grantRolesBulk: " + new Date());
        try {
            await noBotsTechContract.methods.
                grantRolesBulk([
                    ["0xc869e1d528fd91a06036810c7f025f082e044b8f0374c3d1d4b1fb5490dd90ae", defiFactoryTokenContract.options.address],
                    ["0x0000000000000000000000000000000000000000000000000000000000000000", teamVestingContract.options.address],
                    ["0xd27488087fca693adcf8b477ec0ca6cf5134d7f124fdc511eb258522c40fd72b", teamVestingContract.options.address],
                    ["0x2eb7a2681a755a3da9e842879bcbcac38d32d4567f8f95e32a00f74605b40993", teamVestingContract.options.address]
                ]).send({
                    from: account, 
                    gas: 7e5,
                    gasPrice: 2e9 + 1,
                    value: 0
                })
            .then(function (result) {
                //console.log(result);
            });
        }
        catch (error) { console.log(error.message);fail; }
    }
    
    async function step3() {
        //console.log("TeamVestingContract.updateDefiFactoryContract: " + new Date());
        try {
            await teamVestingContract.methods.
                updateDefiFactoryContract(
                    defiFactoryTokenContract.options.address
                ).send({
                    from: account, 
                    gas: 2e5,
                    gasPrice: 2e9 + 1,
                    value: 0
                })
            .then(function (result) {
                //console.log(result);
            });
        }
        catch (error) { console.log(error.message);fail; }
    }
    
    async function step4() {
        //console.log("TeamVestingContract.updateInvestmentSettings: " + new Date());
        try {
            /*await teamVestingContract.methods.
                updateInvestmentSettings(
                    "0xd0A1E359811322d97991E03f863a0C30C2cF029C", // Native token: WETH kovan
                    "0x539FaA851D86781009EC30dF437D794bCd090c8F", 150e13, // dev address & cap
                    "0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6", 100e13, // team address & cap
                    "0xE019B37896f129354cf0b8f1Cf33936b86913A34", 50e13 // marketing address & cap
                ).send({
                    from: account, 
                    gas: 2e5,
                    gasPrice: 2e9 + 1,
                    value: 0
                })
            .then(function (result) {
                //console.log(result);
            });*/
        }
        catch (error) { console.log(error.message);fail; }
    }
    
    async function step5() {
        //console.log("NoBotsTech.updateReCachePeriod: " + new Date());
        try {
            /*await noBotsTechContract.methods.
                updateReCachePeriod(
                    60
                ).send({
                    from: account, 
                    gas: 2e5,
                    gasPrice: 2e9 + 1,
                    value: 0
                })
            .then(function (result) {
                //console.log(result);
            });*/
        }
        catch (error) { console.log(error.message);fail; }
    }
    
    await Promise.all([step1(), step2(), step3(), step4(), step5()]);
    
    
    //console.log("TeamVestingContract.createPair: " + new Date());
    try {
        await teamVestingContract.methods.
            createPair(
            ).send({
                from: account, 
                gas: 5e6,
                gasPrice: 2e9 + 1,
                value: 0
            })
        .then(function (result) {
            //console.log(result);
        });
    }
    catch (error) { console.log(error.message); fail; }
    
    //console.log("TeamVestingContract.addLiquidity: " + new Date());
    try {
        await teamVestingContract.methods.
            addLiquidity(
            ).send({
                from: account, 
                gas: 5e6,
                gasPrice: 2e9 + 1,
                value: 0
            })
        .then(function (result) {
            //console.log(result);
        });
    }
    catch (error) { console.log(error.message);fail; }
    
    //console.log("TeamVestingContract.distributeTokens: " + new Date());
    try {
        await teamVestingContract.methods.
            distributeTokens(
            ).send({
                from: account, 
                gas: 5e6,
                gasPrice: 2e9 + 1,
                value: 0
            })
        .then(function (result) {
            //console.log(result);
        });
    }
    catch (error) { console.log(error.message);fail; }

    console.log("Completed: " + new Date());
})();

async function deployContract (contractName, metadata, account, value)  {
  try {
    let contract = new web3.eth.Contract(metadata.abi);

    contract = contract.deploy({
      data: metadata.data.bytecode.object,
      arguments: []
    });

    let newContractInstance = await contract.send({
        from: account,
        gas: 6e6,
        gasPrice: 2e9 + 1,
        value: value
    });
    return newContractInstance;
  } catch (e) {
    console.log(contractName + ": " + e.message);
  }
}





