const BigNumber = require("bignumber.js");
require("chai")
  .use(require("chai-shallow-deep-equal"))
  .use(require("chai-bignumber")(BigNumber))
  .use(require("chai-as-promised"))
  .should();

const GenericDB = artifacts.require("GenericDB");
const GameVarAndFee = artifacts.require("GameVarAndFee");
const Proxy = artifacts.require("Proxy");
const DateTime = artifacts.require("DateTime");

contract("DateTime", ([creator, randomAddress]) => {
  beforeEach(async () => {
    this.proxy = await Proxy.new();
    this.genericDB = await GenericDB.new();
    this.gameVarAndFee = await GameVarAndFee.new(this.genericDB.address);
    this.dateTime = await DateTime.new();

    await this.proxy.addContract("GameVarAndFee", this.gameVarAndFee.address);

    await this.gameVarAndFee.setProxy(this.proxy.address);
    await this.genericDB.setProxy(this.proxy.address);
    await this.dateTime.setProxy(this.proxy.address);
  });

  describe("DateTime", () => {
    it("sets new proxy", async () => {
      await this.dateTime.setProxy(creator).should.be.fulfilled;
      let proxy = await this.dateTime.proxy();
      proxy.should.be.equal(creator);
    });

    it("calculates correct time", async () => {
      await this.proxy.setVarAndFee("futureGameTime", 3600);
      await this.proxy.setVarAndFee("gamePrestart", 120);

      let gamePrestartTime = await this.dateTime.runGamePrestartTime().should.be
        .fulfilled;

      block = await web3.eth.getBlock();

      Date.prototype.addHours = function(h) {
        this.setHours(this.getHours() + h);
        return this;
      };

      Date.prototype.subMinutes = function(m) {
        this.setMinutes(this.getMinutes() - m);
        return this;
      };

      blockDate = Date(block.timestamp * 1000);

      var utcDate = new Date(blockDate);

      //Adds 3600 sec and subtracts 120 seconds
      utcDate = utcDate.addHours(1).subMinutes(2);

      gamePrestartTime._hour.toNumber().should.be.equal(utcDate.getUTCHours());
      gamePrestartTime._minute
        .toNumber()
        .should.be.equal(utcDate.getUTCMinutes());
      gamePrestartTime.second
        .toNumber()
        .should.be.equal(utcDate.getUTCSeconds());
    });
  });
});
