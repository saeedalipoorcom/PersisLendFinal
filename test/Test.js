const hre = require("hardhat");
// const { expect } = require("chai");

const provider = new hre.ethers.providers.JsonRpcProvider(
  "http://127.0.0.1:8545"
);

describe("Persia", async () => {
  let Owner;
  const amount = hre.ethers.utils.parseEther("1000");

  let DAIAggregatorV3Contract;
  let ETHAggregatorV3Contract;
  let LINKAggregatorV3Contract;
  let OracleProxyContract;

  let DAIContract;
  let PersisContract;

  let DAITokenMarketContract;
  let DAIDataContract;

  let LinkTokenMarketContract;
  let LinkDataContract;

  let LinkRewardManagerDataStorageContract;
  let LinkRewardManagerContract;

  let ETHTokenMarketContract;
  let ETHDataContract;

  let InterestModelContract;
  let ManagerContract;
  let ManagerDataStorageContract;

  let DAIRewardManagerDataStorageContract;
  let DAIRewardManagerContract;

  let ETHRewardManagerDataStorageContract;
  let ETHRewardManagerContract;

  const borrowLimit = hre.ethers.utils.parseEther("0.75");
  const martinCallLimit = hre.ethers.utils.parseEther("0.93");
  const minimumInterestRate = 0;
  const liquiditySensitive = hre.ethers.utils.parseEther("0.05");

  describe("", async function () {
    it("Depolyment", async function () {
      [Owner] = await hre.ethers.getSigners();

      /// ///////////////////////////////////////////////////////////////////////// DEPLOY PRICE AggregatorV3
      const DAIAggregatorV3 = await hre.ethers.getContractFactory(
        "AggregatorV3"
      );
      DAIAggregatorV3Contract = await DAIAggregatorV3.deploy(
        "0x2bA49Aaa16E6afD2a993473cfB70Fa8559B523cF"
      );
      await DAIAggregatorV3Contract.deployed();

      const ETHAggregatorV3 = await hre.ethers.getContractFactory(
        "AggregatorV3"
      );
      ETHAggregatorV3Contract = await ETHAggregatorV3.deploy(
        "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e"
      );
      await ETHAggregatorV3Contract.deployed();

      const LINKAggregatorV3 = await hre.ethers.getContractFactory(
        "AggregatorV3"
      );
      LINKAggregatorV3Contract = await LINKAggregatorV3.deploy(
        "0xd8bD0a1cB028a31AA859A21A3758685a95dE4623"
      );
      await LINKAggregatorV3Contract.deployed();

      const OracleProxy = await hre.ethers.getContractFactory("oracleProxy");
      OracleProxyContract = await OracleProxy.deploy(
        DAIAggregatorV3Contract.address,
        ETHAggregatorV3Contract.address,
        LINKAggregatorV3Contract.address
      );
      await OracleProxyContract.deployed();

      /// ///////////////////////////////////////////////////////////////////////// DEPLOY DAI
      const DAI = await hre.ethers.getContractFactory("DAI");

      DAIContract = await DAI.deploy();
      await DAIContract.deployed();
      console.log("DAIContract deployed to:", DAIContract.address);

      const Persis = await hre.ethers.getContractFactory("Persis");
      PersisContract = await Persis.deploy();

      await PersisContract.deployed();
      console.log("PersisContract deployed to:", PersisContract.address);

      /// ///////////////////////////////////////////////////////////////////////// DEPLOY INTEREST MODEL
      const InterestModel = await hre.ethers.getContractFactory(
        "InterestModel"
      );

      InterestModelContract = await InterestModel.deploy(
        hre.ethers.utils.parseEther("0.025"),
        hre.ethers.utils.parseEther("0.8"),
        hre.ethers.utils.parseEther("0.1"),
        hre.ethers.utils.parseEther("0.18"),
        hre.ethers.utils.parseEther("0.825")
      );
      await InterestModelContract.deployed();
      console.log(
        "InterestModelContract deployed to:",
        InterestModelContract.address
      );

      await InterestModelContract.setBlocksPerYear(
        hre.ethers.utils.parseEther("2102400")
      );
      /// ///////////////////////////////////////////////////////////////////////// DEPLOY MARKET
      const DAITokenMarket = await hre.ethers.getContractFactory("TokenMarket");
      DAITokenMarketContract = await DAITokenMarket.deploy(DAIContract.address);
      await DAITokenMarketContract.deployed();
      console.log(
        "DAITokenMarketContract deployed to:",
        DAITokenMarketContract.address
      );

      const LinkTokenMarket = await hre.ethers.getContractFactory(
        "TokenMarket"
      );
      LinkTokenMarketContract = await LinkTokenMarket.deploy(
        "0xd8bD0a1cB028a31AA859A21A3758685a95dE4623"
      );
      await LinkTokenMarketContract.deployed();
      console.log(
        "LinkTokenMarketContract deployed to:",
        LinkTokenMarketContract.address
      );

      const ETHTokenMarket = await hre.ethers.getContractFactory("ETHMarket");
      ETHTokenMarketContract = await ETHTokenMarket.deploy();
      await ETHTokenMarketContract.deployed();
      console.log(
        "ETHTokenMarketContract deployed to:",
        ETHTokenMarketContract.address
      );

      /// ///////////////////////////////////////////////////////////////////////// DEPLOY MARKET DATA STORAGE
      const DAIData = await hre.ethers.getContractFactory("MarketData");
      DAIDataContract = await DAIData.deploy(
        borrowLimit,
        martinCallLimit,
        minimumInterestRate,
        liquiditySensitive
      );
      await DAIDataContract.deployed();
      console.log("DAIDataContract deployed to:", DAIDataContract.address);

      const LinkData = await hre.ethers.getContractFactory("MarketData");
      LinkDataContract = await LinkData.deploy(
        borrowLimit,
        martinCallLimit,
        minimumInterestRate,
        liquiditySensitive
      );
      await LinkDataContract.deployed();
      console.log("LinkDataContract deployed to:", LinkDataContract.address);

      const ETHData = await hre.ethers.getContractFactory("MarketData");
      ETHDataContract = await ETHData.deploy(
        borrowLimit,
        martinCallLimit,
        minimumInterestRate,
        liquiditySensitive
      );
      await ETHDataContract.deployed();
      console.log("ETHDataContract deployed to:", ETHDataContract.address);

      /// ///////////////////////////////////////////////////////////////////////// DEPLOY CORE MANAGER
      const Manager = await hre.ethers.getContractFactory("Manager");

      ManagerContract = await Manager.deploy(PersisContract.address);
      await ManagerContract.deployed();
      console.log("ManagerContract deployed to:", ManagerContract.address);

      await PersisContract.transfer(
        ManagerContract.address,
        hre.ethers.utils.parseEther("1000000")
      );

      /// ///////////////////////////////////////////////////////////////////////// DEPLOY CORE MANAGER DATA
      const ManagerDataStorage = await hre.ethers.getContractFactory(
        "ManagerData"
      );

      ManagerDataStorageContract = await ManagerDataStorage.deploy();
      await ManagerDataStorageContract.deployed();
      console.log(
        "ManagerDataStorageContract deployed to:",
        ManagerDataStorageContract.address
      );

      /// ///////////////////////////////////////////////////////////////////////// DEPLOY REWARD MANAGER DATA
      const RewardManagerDataStorage = await hre.ethers.getContractFactory(
        "RewardManagerDataStorage"
      );
      DAIRewardManagerDataStorageContract =
        await RewardManagerDataStorage.deploy();
      await DAIRewardManagerDataStorageContract.deployed();
      console.log(
        "DAIRewardManagerDataStorageContract deployed to:",
        DAIRewardManagerDataStorageContract.address
      );

      const LinkRewardManagerDataStorage = await hre.ethers.getContractFactory(
        "RewardManagerDataStorage"
      );
      LinkRewardManagerDataStorageContract =
        await LinkRewardManagerDataStorage.deploy();
      await LinkRewardManagerDataStorageContract.deployed();
      console.log(
        "LinkRewardManagerDataStorageContract deployed to:",
        LinkRewardManagerDataStorageContract.address
      );

      const ETHRewardManagerDataStorage = await hre.ethers.getContractFactory(
        "RewardManagerDataStorage"
      );
      ETHRewardManagerDataStorageContract =
        await ETHRewardManagerDataStorage.deploy();
      await ETHRewardManagerDataStorageContract.deployed();
      console.log(
        "ETHRewardManagerDataStorageContract deployed to:",
        ETHRewardManagerDataStorageContract.address
      );

      /// ///////////////////////////////////////////////////////////////////////// DEPLOY REWARD MANAGER
      const RewardManager = await hre.ethers.getContractFactory(
        "RewardManager"
      );
      DAIRewardManagerContract = await RewardManager.deploy();
      await DAIRewardManagerContract.deployed();
      console.log(
        "DAIRewardManagerContract deployed to:",
        DAIRewardManagerContract.address
      );

      const LinkRewardManager = await hre.ethers.getContractFactory(
        "RewardManager"
      );
      LinkRewardManagerContract = await LinkRewardManager.deploy();
      await LinkRewardManagerContract.deployed();
      console.log(
        "LinkRewardManagerContract deployed to:",
        LinkRewardManagerContract.address
      );

      const ETHRewardManager = await hre.ethers.getContractFactory(
        "RewardManager"
      );
      ETHRewardManagerContract = await ETHRewardManager.deploy();
      await ETHRewardManagerContract.deployed();
      console.log(
        "ETHRewardManagerContract deployed to:",
        ETHRewardManagerContract.address
      );
    });

    it("SETUP", async function () {
      /// DAI MARKET //////////////////////////////////////////////////////////////////////
      await DAITokenMarketContract.setManagerContract(ManagerContract.address);
      await DAITokenMarketContract.setDataStorageContract(
        DAIDataContract.address
      );
      await DAITokenMarketContract.setInterestModelContract(
        InterestModelContract.address
      );
      await DAITokenMarketContract.setRewardManagerContract(
        DAIRewardManagerContract.address
      );
      await DAITokenMarketContract.setMarketName("DAI");
      await DAITokenMarketContract.setMarketID(1);

      /// DAI DATA //////////////////////////////////////////////////////////////////////
      await DAIDataContract.setMarketContract(DAITokenMarketContract.address);
      await DAIDataContract.setInterestModelContract(
        InterestModelContract.address
      );

      /// link MARKET //////////////////////////////////////////////////////////////////////
      await LinkTokenMarketContract.setManagerContract(ManagerContract.address);
      await LinkTokenMarketContract.setDataStorageContract(
        LinkDataContract.address
      );
      await LinkTokenMarketContract.setInterestModelContract(
        InterestModelContract.address
      );
      await LinkTokenMarketContract.setRewardManagerContract(
        LinkRewardManagerContract.address
      );
      await LinkTokenMarketContract.setMarketName("Link");
      await LinkTokenMarketContract.setMarketID(3);

      /// link DATA //////////////////////////////////////////////////////////////////////
      await LinkDataContract.setMarketContract(LinkTokenMarketContract.address);
      await LinkDataContract.setInterestModelContract(
        InterestModelContract.address
      );

      /// ETH MARKET //////////////////////////////////////////////////////////////////////
      await ETHTokenMarketContract.setManagerContract(ManagerContract.address);
      await ETHTokenMarketContract.setDataStorageContract(
        ETHDataContract.address
      );
      await ETHTokenMarketContract.setInterestModelContract(
        InterestModelContract.address
      );
      await ETHTokenMarketContract.setRewardManagerContract(
        ETHRewardManagerContract.address
      );
      await ETHTokenMarketContract.setMarketName("ETH");
      await ETHTokenMarketContract.setMarketID(2);

      /// ETH DATA //////////////////////////////////////////////////////////////////////
      await ETHDataContract.setMarketContract(ETHTokenMarketContract.address);
      await ETHDataContract.setInterestModelContract(
        InterestModelContract.address
      );

      /// MANAGER //////////////////////////////////////////////////////////////////////
      await ManagerDataStorageContract.setManagerContractAddress(
        ManagerContract.address
      );

      await ManagerContract.setOracleContract(OracleProxyContract.address);
      await ManagerContract.setManagerDataStorageContract(
        ManagerDataStorageContract.address
      );
      await ManagerContract.registerNewHandler(
        1,
        DAITokenMarketContract.address
      );

      await ManagerContract.registerNewHandler(
        3,
        LinkTokenMarketContract.address
      );

      await ManagerContract.registerNewHandler(
        2,
        ETHTokenMarketContract.address
      );

      /// DAI REWARD MANAGER DATA //////////////////////////////////////////////////////////////////////
      await DAIRewardManagerDataStorageContract.setRewardManagerContract(
        DAIRewardManagerContract.address
      );

      /// Link REWARD MANAGER DATA //////////////////////////////////////////////////////////////////////
      await LinkRewardManagerDataStorageContract.setRewardManagerContract(
        LinkRewardManagerContract.address
      );

      /// ETH REWARD MANAGER DATA //////////////////////////////////////////////////////////////////////
      await ETHRewardManagerDataStorageContract.setRewardManagerContract(
        ETHRewardManagerContract.address
      );

      /// DAI REWARD MANAGER //////////////////////////////////////////////////////////////////////
      await DAIRewardManagerContract.setManagerContractAddress(
        ManagerContract.address
      );
      await DAIRewardManagerContract.setMarketDataStorageContract(
        DAIDataContract.address
      );
      await DAIRewardManagerContract.setRewardManagerDataStorageContract(
        DAIRewardManagerDataStorageContract.address
      );

      /// Link REWARD MANAGER //////////////////////////////////////////////////////////////////////
      await LinkRewardManagerContract.setManagerContractAddress(
        ManagerContract.address
      );
      await LinkRewardManagerContract.setMarketDataStorageContract(
        LinkDataContract.address
      );
      await LinkRewardManagerContract.setRewardManagerDataStorageContract(
        LinkRewardManagerDataStorageContract.address
      );

      /// ETH REWARD MANAGER //////////////////////////////////////////////////////////////////////
      await ETHRewardManagerContract.setManagerContractAddress(
        ManagerContract.address
      );
      await ETHRewardManagerContract.setMarketDataStorageContract(
        ETHDataContract.address
      );
      await ETHRewardManagerContract.setRewardManagerDataStorageContract(
        ETHRewardManagerDataStorageContract.address
      );
    });

    it("CHARGE DAI TO DAI POOL", async function () {
      await DAIContract.approve(DAITokenMarketContract.address, amount);
      await DAIContract.transfer(DAITokenMarketContract.address, amount);

      await DAIDataContract.addAmountToTotalDeposit(amount);
    });

    it("DEPOSIT DAI", async function () {
      await DAIContract.approve(DAITokenMarketContract.address, amount);
      await DAITokenMarketContract.deposit(amount);

      console.log((await hre.ethers.provider.getBlockNumber()).toString());

      for (let i = 0; i < 10; i++) {
        await provider.send("evm_mine");
      }

      console.log((await hre.ethers.provider.getBlockNumber()).toString());

      console.log(
        (
          await DAITokenMarketContract.getUpdatedUserRewardAmount(Owner.address)
        ).toString()
      );

      // const [, addr1] = await hre.ethers.getSigners();

      // amount = hre.ethers.utils.parseEther("10000");

      // await DAIContract.approve(addr1.address, amount);
      // await DAIContract.transfer(addr1.address, amount);

      // await DAIContract.connect(addr1).approve(
      //   DAITokenMarketContract.address,
      //   amount
      // );
      // await DAITokenMarketContract.connect(addr1).deposit(amount);
      // console.log((await hre.ethers.provider.getBlockNumber()).toString());

      // for (let i = 0; i < 10; i++) {
      //   await hre.ethers.provider.send("evm_mine");
      // }
      // console.log((await hre.ethers.provider.getBlockNumber()).toString());

      // console.log(
      //   (
      //     await DAITokenMarketContract.getUpdatedUserRewardAmount(addr1.address)
      //   ).toString()
      // );

      // console.log(
      //   (
      //     await DAITokenMarketContract.getUpdatedUserRewardAmount(Owner.address)
      //   ).toString()
      // );
    });

    it("VERIFY DATA AFTER DEPOSIT DAI", async function () {
      // expect(await DAIDataContract.getMarketDepositTotalAmount()).to.equal(
      //   amount
      // );
      // expect(await DAIDataContract.getMarketBorrowTotalAmount()).to.equal(0);
      // expect(await DAIDataContract.getMarketBorrowLimit()).to.equal(
      //   borrowLimit
      // );
      // expect(await DAIDataContract.getMarketMarginCallLimit()).to.equal(
      //   martinCallLimit
      // );
      // expect(
      //   await DAIDataContract.getUserDepositAmount(Owner.address)
      // ).to.equal(amount);
      // expect(await DAIDataContract.getUserBorrowAmount(Owner.address)).to.equal(
      //   0
      // );
      // expect(await DAIDataContract.getUserIsAccessed(Owner.address)).to.equal(
      //   true
      // );
    });

    // it("CHECK DAI REWARD", async function () { });

    // it("WITHDRAW DAI", async function () {
    //   await DAITokenMarketContract.withdraw(amount);
    // });

    // it("VERIFY DATA AFTER WITHDRAW DAI", async function () {
    //   expect(await DAIDataContract.getMarketDepositTotalAmount()).to.equal(0);
    //   expect(await DAIDataContract.getMarketBorrowTotalAmount()).to.equal(0);

    //   expect(await DAIDataContract.getMarketBorrowLimit()).to.equal(
    //     borrowLimit
    //   );
    //   expect(await DAIDataContract.getMarketMarginCallLimit()).to.equal(
    //     martinCallLimit
    //   );

    //   expect(
    //     await DAIDataContract.getUserDepositAmount(Owner.address)
    //   ).to.equal(0);
    //   expect(await DAIDataContract.getUserBorrowAmount(Owner.address)).to.equal(
    //     0
    //   );
    //   expect(await DAIDataContract.getUserIsAccessed(Owner.address)).to.equal(
    //     true
    //   );
    // });
  });
});
