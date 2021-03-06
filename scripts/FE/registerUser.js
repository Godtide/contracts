const KFProxy = artifacts.require('KFProxy')
const Register = artifacts.require('Register')
const WithdrawPool = artifacts.require("WithdrawPool");
const EarningsTracker = artifacts.require("EarningsTracker");
const GameVarAndFee = artifacts.require("GameVarAndFee");

function setMessage(contract, funcName, argArray) {
  return web3.eth.abi.encodeFunctionCall(
    contract.abi.find((f) => { return f.name == funcName; }),
    argArray
  );
}

function formatDate(timestamp) {
  let date = new Date(null);
  date.setSeconds(timestamp);
  return date.toTimeString().replace(/.*(\d{2}:\d{2}:\d{2}).*/, "$1");
}

//truffle exec scripts/FE/registerUsers.js User

module.exports = async (callback) => {
  try{
    let proxy = await KFProxy.deployed();
    let register = await Register.deployed()
    let withdrawPool = await WithdrawPool.deployed();
    let earningsTracker = await EarningsTracker.deployed();
    let gameVarAndFee = await GameVarAndFee.deployed();
    
    accounts = await web3.eth.getAccounts();
    
    let user = process.argv[4];

    let fee = await gameVarAndFee.getFinalizeRewards();
    console.log(fee.toString());

    // let numberOfPools = await withdrawPool.getTotalNumberOfPools();

    await proxy.execute('Register', setMessage(register, 'register', []), {
      from: accounts[user]
    });

    let isRegistered = await register.isRegistered(accounts[user])

    if(isRegistered) console.log('\nRegistered User ', accounts[user]);

    let newNumberOfPools = await withdrawPool.getTotalNumberOfPools();
    // if(newNumberOfPools > numberOfPools) {
      for(let i = 0; i < newNumberOfPools; i++) {
        let amounts = await earningsTracker.amountsPerEpoch(i);
        console.log("Number of pools:", newNumberOfPools.toNumber());
        console.log("\n******************* Pool 0 Created*******************");
        const pool_0_details = await withdrawPool.weeklyPools(i);
        console.log(
          "epoch ID associated with this pool",
          pool_0_details.epochID.toString()
        );
        console.log(
          "block number when this pool was created",
          pool_0_details.blockNumber.toString()
        );
        console.log(
          "initial ether available in this pool:",
          pool_0_details.initialETHAvailable.toString()
        );
        console.log(
          "ether available in this pool:",
          pool_0_details.ETHAvailable.toString()
        );
        console.log(
          "date available for claiming from this pool:",
          formatDate(pool_0_details.dateAvailable)
        );
        console.log(
          "whether initial ether has been distributed to this pool:",
          pool_0_details.initialETHadded
        );
        console.log(
          "time when this pool is dissolved:",
          formatDate(pool_0_details.dateDissolved)
        );
        console.log(
          "stakers who have claimed from this pool:",
          pool_0_details.stakersClaimed[0]
        );
        console.log(
          "Investments in Pool:",
          web3.utils.fromWei(amounts.investment.toString())
        );
        console.log(
          "Interest in Pool:",
          web3.utils.fromWei(amounts.interest.toString())
        );
        console.log("********************************************************\n");
      // }
    }

    callback()
  }
  catch(e){callback(e)}
}
