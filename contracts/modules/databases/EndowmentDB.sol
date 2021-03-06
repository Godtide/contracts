pragma solidity ^0.5.5;

import "./GenericDB.sol";
import "../proxy/Proxied.sol";
import "../../libs/SafeMath.sol";
import '../../GameVarAndFee.sol';
import './GMGetterDB.sol';

contract EndowmentDB is Proxied {
  using SafeMath for uint256;

  GenericDB public genericDB;

  // TABLE_KEY_PROFILE for ProfileDB lookup (read-only).
  bytes32 internal constant TABLE_KEY_PROFILE = keccak256(abi.encodePacked("ProfileTable"));
  // TABLE_KEY_HONEYPOT defines a set for active Honeypots of EndowmentFund.
  bytes32 internal constant TABLE_KEY_HONEYPOT = keccak256(abi.encodePacked("HoneypotTable"));
  // TABLE_KEY_HONEYPOT_DISSOLVED defines a set for dissolved honeypots of EndowmentFund.
  bytes32 internal constant TABLE_KEY_HONEYPOT_DISSOLVED = keccak256(abi.encodePacked("HoneypotDissolvedTable"));
  // TABLE_NAME_CONTRIBUTION_KTY defines a set of KTY contributors of a honeypot of EndowmentFund.
  bytes32 internal constant TABLE_NAME_CONTRIBUTION_KTY = "ContributionTableKTY";
  // TABLE_NAME_CONTRIBUTION_ETH defines a set of ETH contributors of a honeypot of EndowmentFund.
  bytes32 internal constant TABLE_NAME_CONTRIBUTION_ETH = "ContributionTableETH";
  // VAR_KEY_ACTUAL_FUNDS_KTY
  bytes32 internal constant VAR_KEY_ACTUAL_FUNDS_KTY = keccak256(abi.encodePacked("actualFundsKTY"));
  // VAR_KEY_ACTUAL_FUNDS_ETH
  bytes32 internal constant VAR_KEY_ACTUAL_FUNDS_ETH = keccak256(abi.encodePacked("actualFundsETH"));
  // VAR_KEY_INGAME_FUNDS_KTY
  bytes32 internal constant VAR_KEY_INGAME_FUNDS_KTY = keccak256(abi.encodePacked("ingameFundsKTY"));
  // VAR_KEY_INGAME_FUNDS_ETH
  bytes32 internal constant VAR_KEY_INGAME_FUNDS_ETH = keccak256(abi.encodePacked("ingameFundsETH"));

  string internal constant ERROR_DOES_NOT_EXIST = "Not exists";
  string internal constant ERROR_NOT_REGISTERED = "Not registered";
  string internal constant ERROR_ALREADY_EXIST = "Already exists";
  string internal constant ERROR_INSUFFICIENT_FUNDS = "Insufficient funds";

  constructor(GenericDB _genericDB) public {
    setGenericDB(_genericDB);
  }

  function setGenericDB(GenericDB _genericDB) public onlyOwner {
    genericDB = _genericDB;
  }

  function updateHoneyPotFund(
    uint256 _gameId, uint256 _kty_amount, uint256 _eth_amount, bool deductFunds
  )
    external
    only2Contracts(CONTRACT_NAME_ENDOWMENT_FUND, CONTRACT_NAME_GAMEMANAGER_HELPER)
    returns (bool)
  {
    uint honeyPotKtyTotal;
    uint honeyPotEthTotal;

    if (_kty_amount > 0){

      // get total Kty availabe in the HoneyPot
      bytes32 honeyPotKtyTotalKey = keccak256(abi.encodePacked(_gameId, "ktyTotal"));
      honeyPotKtyTotal = genericDB.getUintStorage(CONTRACT_NAME_ENDOWMENT_DB, honeyPotKtyTotalKey);

      if (deductFunds){

        require(honeyPotKtyTotal >= _kty_amount);

        genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, honeyPotKtyTotalKey, honeyPotKtyTotal.sub(_kty_amount));

      }else{ // add

        genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, honeyPotKtyTotalKey, honeyPotKtyTotal.add(_kty_amount));

      }
    }

    if (_eth_amount > 0){
      // get total Eth availabe in the HoneyPot
      bytes32 honeyPotEthTotalKey = keccak256(abi.encodePacked(_gameId, "ethTotal"));
      honeyPotEthTotal = genericDB.getUintStorage(CONTRACT_NAME_ENDOWMENT_DB, honeyPotEthTotalKey);

      if (deductFunds){

        require(honeyPotEthTotal >= _eth_amount);

        genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, honeyPotEthTotalKey, honeyPotEthTotal.sub(_eth_amount));

      }else{ // add

        genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, honeyPotEthTotalKey, honeyPotEthTotal.add(_eth_amount));

      }
    }

    return true;
  }

  function updateInvestment(uint256 _investment)
  external
  onlyContract(CONTRACT_NAME_ENDOWMENT_FUND)
  {
    uint currentInvestment = genericDB.getUintStorage(CONTRACT_NAME_ENDOWMENT_DB, "investmentForNext");
    genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, "investmentForNext", currentInvestment.add(_investment));
  }

  function subInvestment(uint256 _investment)
  external
  onlyContract(CONTRACT_NAME_ENDOWMENT_FUND)
  {
    uint currentInvestment = genericDB.getUintStorage(CONTRACT_NAME_ENDOWMENT_DB, "investmentForNext");
    genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, "investmentForNext", currentInvestment.sub(_investment));
  }

  function updateEndowmentFund(
    uint256 _kty_amount, uint256 _eth_amount, bool deductFunds
  )
    external
    only2Contracts(CONTRACT_NAME_ENDOWMENT_FUND, CONTRACT_NAME_GAMEMANAGER_HELPER)
    returns (bool)
  {
    return (_updateEndowmentFund(_kty_amount, _eth_amount, deductFunds));
  }

  function _updateEndowmentFund(
    uint256 _kty_amount, uint256 _eth_amount, bool deductFunds
  )
    internal
    returns (bool)
  {

    if (_kty_amount > 0){

      uint actualFundsKTY = genericDB.getUintStorage(CONTRACT_NAME_ENDOWMENT_DB, VAR_KEY_ACTUAL_FUNDS_KTY);
      if (deductFunds){

        require(actualFundsKTY >= _kty_amount);

        genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, VAR_KEY_ACTUAL_FUNDS_KTY, actualFundsKTY.sub(_kty_amount));

      }else{ // add
        genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, VAR_KEY_ACTUAL_FUNDS_KTY, actualFundsKTY.add(_kty_amount));

      }
    }

    if (_eth_amount > 0){
      uint actualFundsETH = genericDB.getUintStorage(CONTRACT_NAME_ENDOWMENT_DB, VAR_KEY_ACTUAL_FUNDS_ETH);

      if (deductFunds){

        require(actualFundsETH >= _eth_amount);

        genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, VAR_KEY_ACTUAL_FUNDS_ETH, actualFundsETH.sub(_eth_amount));

      }else{ // add

        genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, VAR_KEY_ACTUAL_FUNDS_ETH, actualFundsETH.add(_eth_amount));

      }
    }

    return true;
  }

  function getEndowmentBalance() public view
  returns (uint256 endowmentBalanceKTY, uint256 endowmentBalanceETH)  {
    endowmentBalanceKTY = genericDB.getUintStorage(CONTRACT_NAME_ENDOWMENT_DB, VAR_KEY_ACTUAL_FUNDS_KTY);
    endowmentBalanceETH = genericDB.getUintStorage(CONTRACT_NAME_ENDOWMENT_DB, VAR_KEY_ACTUAL_FUNDS_ETH);
  }

  function createHoneypot(
    uint gameId,
    uint state,
    uint createdTime,
    uint ktyTotal,
    uint ethTotal,
    string memory honeypotClass
  )
    internal
  {
    require(genericDB.pushNodeToLinkedList(CONTRACT_NAME_ENDOWMENT_DB, TABLE_KEY_HONEYPOT, gameId), ERROR_ALREADY_EXIST);
    genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, keccak256(abi.encodePacked(gameId, "state")), state);
    genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, keccak256(abi.encodePacked(gameId, "createdTime")), createdTime);
    genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, keccak256(abi.encodePacked(gameId, "ktyTotal")), ktyTotal);
    genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, keccak256(abi.encodePacked(gameId, "ethTotal")), ethTotal);
    genericDB.setStringStorage(CONTRACT_NAME_ENDOWMENT_DB, keccak256(abi.encodePacked(gameId, "honeypotClass")), honeypotClass);
  }

  function setHoneypotState( uint _gameId, uint state)
  external
  only2Contracts(CONTRACT_NAME_ENDOWMENT_FUND, CONTRACT_NAME_GAMEMANAGER_HELPER)
  {
    genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, keccak256(abi.encodePacked(_gameId, "state")), state);
    // if (claimTime > 0){
    //   genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, keccak256(abi.encodePacked(_gameId, "claimTime")), claimTime);
    // }
    // else{
    //   genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, keccak256(abi.encodePacked(_gameId, "claimTime")), 0);
    // }
  }

  /**
  * @dev check if enough funds present and maintains balance of tokens in DB
  */
  function generateHoneyPot(uint256 gameId, uint256 ktyAllocated, uint256 ethAllocated, string memory honeypotClass)
    public
    onlyContract(CONTRACT_NAME_HONEYPOT_ALLOCATION_ALGO)
    returns (uint, uint) {

    // + adds amount to honeypot
    createHoneypot(
      gameId,
      0,
      now,
      ktyAllocated,
      ethAllocated,
      honeypotClass
    );

    // deduct amount from endowment
    require(_updateEndowmentFund(ktyAllocated, ethAllocated, true));

    return (ktyAllocated, ethAllocated);
  }

  function setPoolIDinGame(uint _gameId, uint _poolId)
      external
      onlyContract(CONTRACT_NAME_GAMECREATION)
  {
    genericDB.setUintStorage(
      CONTRACT_NAME_ENDOWMENT_DB,
      keccak256(abi.encodePacked(_gameId, "poolID")),
      _poolId
    );
  }

  function addETHtoPool(uint256 gameId, address loser)
        external
        onlyContract(CONTRACT_NAME_GAMEMANAGER)
    {
        uint256 totalEthForLoser = GMGetterDB(proxy.getContract(CONTRACT_NAME_GM_GETTER_DB)).getTotalBet(gameId, loser);
        uint256 percentageForPool = GameVarAndFee(proxy.getContract(CONTRACT_NAME_GAMEVARANDFEE)).getPercentageForPool();
        uint256 ETHtoPool = totalEthForLoser.mul(percentageForPool).div(1000000);
        _addETHtoPool(gameId, ETHtoPool);
    }

  function _addETHtoPool(uint _gameId, uint _eth)
      internal
      // external
      // onlyContract(CONTRACT_NAME_ACCOUNTING_DB)
  {
    // get _pool_id of the pool associated with the game with _gameId
    uint _pool_id = getPoolID(_gameId);
    // get previous amount of ether stored in this pool with _pool_id
    uint prevETH = genericDB.getUintStorage(
      CONTRACT_NAME_ENDOWMENT_DB,
      keccak256(abi.encodePacked(_pool_id, "ETHinPool"))
    );

    // record initial ether amount added to this pool
    genericDB.setUintStorage(
      CONTRACT_NAME_ENDOWMENT_DB,
      keccak256(abi.encodePacked(_pool_id, "InitialETHinPool")),
      prevETH.add(_eth)
    );

    // add _eth to the previous amount of ether in this pool
    genericDB.setUintStorage(
      CONTRACT_NAME_ENDOWMENT_DB,
      keccak256(abi.encodePacked(_pool_id, "ETHinPool")),
      prevETH.add(_eth)
    );
  }

  function subETHfromPool(uint256 _eth, uint256 _pool_id)
      external
      onlyContract(CONTRACT_NAME_ENDOWMENT_FUND)
  {
    // get previous amount of ether stored in this pool with _pool_id
    uint prevETH = genericDB.getUintStorage(
      CONTRACT_NAME_ENDOWMENT_DB,
      keccak256(abi.encodePacked(_pool_id, "ETHinPool"))
    );
    // add _eth to the previous amount of ether in this pool
    genericDB.setUintStorage(
      CONTRACT_NAME_ENDOWMENT_DB,
      keccak256(abi.encodePacked(_pool_id, "ETHinPool")),
      prevETH.sub(_eth)
    );
  }

  function getETHinPool(uint _pool_id)
      public
      view
      returns(uint)
  {
    return genericDB.getUintStorage(
      CONTRACT_NAME_ENDOWMENT_DB,
      keccak256(abi.encodePacked(_pool_id, "ETHinPool"))
    );
  }

  function checkInvestment(uint256 pool_id)
  external
  onlyContract(CONTRACT_NAME_WITHDRAW_POOL)
  returns(uint256)
  {
    uint256 remainingFundsPool;
    if(pool_id != 0) {
      remainingFundsPool = getETHinPool(pool_id.sub(1));

      genericDB.setUintStorage(
        CONTRACT_NAME_ENDOWMENT_DB,
        keccak256(abi.encodePacked(pool_id.sub(1), "ETHinPool")),
        0
      );

      genericDB.setUintStorage(
        CONTRACT_NAME_ENDOWMENT_DB,
        keccak256(abi.encodePacked(pool_id, "ETHinPool")),
        remainingFundsPool
      );
    }

    _updateEndowmentFund(0, genericDB.getUintStorage(CONTRACT_NAME_ENDOWMENT_DB, "investmentForNext"), false);

    uint256 actualFunds = genericDB.getUintStorage(CONTRACT_NAME_ENDOWMENT_DB, VAR_KEY_ACTUAL_FUNDS_ETH);
    genericDB.setUintStorage(CONTRACT_NAME_ENDOWMENT_DB, "investmentForNext", 0);
    return actualFunds.sub(remainingFundsPool);
  }

  function getInvestment()
  external
  view
  returns(uint256)
  {
    return genericDB.getUintStorage(CONTRACT_NAME_ENDOWMENT_DB, "investmentForNext");
  }

  function getTotalForEpoch(uint256 pool_id)
  external
  onlyContract(CONTRACT_NAME_WITHDRAW_POOL)
  returns(uint256, uint256)
  {
    uint256 fundsForPool = getETHinPool(pool_id);
    genericDB.setUintStorage(
        CONTRACT_NAME_ENDOWMENT_DB,
        keccak256(abi.encodePacked(pool_id, "InitialETHinPool")),
        fundsForPool
      );
    uint256 actualFunds = genericDB.getUintStorage(CONTRACT_NAME_ENDOWMENT_DB, VAR_KEY_ACTUAL_FUNDS_ETH);
    return (actualFunds.sub(fundsForPool), fundsForPool);
  }

  // get pool ID of the pool associated with a honey pot
  function getPoolID(uint _gameId)
      public view returns(uint poolID)
  {
    poolID = genericDB.getUintStorage(CONTRACT_NAME_ENDOWMENT_DB, keccak256(abi.encodePacked(_gameId, "poolID")));
  }

  modifier onlyExistingHoneypot(uint gameId) {
    require(genericDB.doesNodeExist(CONTRACT_NAME_ENDOWMENT_DB, TABLE_KEY_HONEYPOT, gameId), ERROR_DOES_NOT_EXIST);
    _;
  }

  modifier onlyExistingProfile(address account) {
    require(genericDB.doesNodeAddrExist(CONTRACT_NAME_PROFILE_DB, TABLE_KEY_PROFILE, account), ERROR_NOT_REGISTERED);
    _;
  }
}

