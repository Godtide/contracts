/**
 * @title EndowmentFund
 */
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.5.5;

import "../proxy/Proxied.sol";
import "../../authority/Guard.sol";
import "./Distribution.sol";
import "../endowment/HoneypotAllocationAlgo.sol";

/**
 * @title EndowmentFund
 * @dev Responsible for : manage funds
 * @author @vikrammndal @wafflemakr @Xaleee @ziweidream
 */

contract EndowmentFund is Distribution, Guard {
    using SafeMath for uint256;

    Escrow public escrow;

    event WinnerClaimed(uint indexed gameId, address indexed winner, uint256 ethAmount, uint256 ktyAmount, address from);
    event SentKTYtoEscrow(address sender, uint256 ktyAmount, address receiver);
    event SentETHtoEscrow(address sender, uint256 ethAmount, address receiver);
    event EthSwappedforKTY(address sender, uint256 ethAmount, uint256 ktyAmount, address ktyReceiver);

    enum HoneypotState {
        created,
        assigned,
        gameScheduled,
        gameStarted,
        forefeited,
        claiming,
        dissolved
    }

    /**
    * @dev check if enough funds present and maintains balance of tokens in DB
    */
    function generateHoneyPot(uint256 gameId)
    external
    onlyContract(CONTRACT_NAME_GAMECREATION)
    returns (uint, uint) {
        (
          uint ktyAllocated,
          uint ethAllocated,
          string memory honeypotClass
        ) = HoneypotAllocationAlgo(proxy.getContract(CONTRACT_NAME_HONEYPOT_ALLOCATION_ALGO)).calculateAllocationToHoneypot();
        return (endowmentDB.generateHoneyPot(gameId, ktyAllocated, ethAllocated, honeypotClass));
    }

    /**
    * @dev winner claims
    */
    function claim(uint256 _gameId) external onlyProxy payable {
        address payable msgSender = address(uint160(getOriginalSender()));

        // Honeypot status
        (uint status, /*uint256 claimTime*/) = endowmentDB.getHoneypotState(_gameId);

        require(uint(HoneypotState.claiming) == status);

        // require(now < claimTime, "2");

        require(!getWithdrawalState(_gameId, msgSender));

        (uint256 winningsETH, uint256 winningsKTY) = getWinnerShare(_gameId, msgSender);

        // make sure enough funds in HoneyPot and update HoneyPot balance
        endowmentDB.updateHoneyPotFund(_gameId, winningsKTY, winningsETH, true);

        if (winningsKTY > 0){
            // transfer the KTY
            escrow.transferKTY(msgSender, winningsKTY);
        }

        if (winningsETH > 0){
            // transfer the ETH
            escrow.transferETH(msgSender, winningsETH);
            // transferETHfromEscrow(msgSender, winningsETH);
        }

        // log tokens sent to an address
        endowmentDB.setTotalDebit(_gameId, msgSender, winningsETH, winningsKTY);

        emit WinnerClaimed(_gameId, msgSender, winningsETH, winningsKTY, address(escrow));
    }

    /**
    * @dev send reward to the user that pressed finalize button
    */
    function sendFinalizeRewards(address user)
        external
        onlyContract(CONTRACT_NAME_GAMEMANAGER)
        returns(bool)
    {
        uint reward = gameVarAndFee.getFinalizeRewards();
        transferKTYfromEscrow(address(uint160(user)), reward);
        return true;
    }

    function getWithdrawalState(uint _gameId, address _account) public view returns (bool) {
        (uint256 totalETHdebited, uint256 totalKTYdebited) = endowmentDB.getTotalDebit(_gameId, _account);
        return ((totalETHdebited > 0) && (totalKTYdebited > 0));
    }

    /**
    * @dev updateHoneyPotState
    */
    function updateHoneyPotState(uint256 _gameId, uint _state) public onlyContract(CONTRACT_NAME_GAMEMANAGER) {
        uint256 claimTime;
        if (_state == uint(HoneypotState.claiming)){
            //Send immediately initialEth+15%oflosing and 15%ofKTY to endowment
            (uint256 winningsETH, uint256 winningsKTY) = getEndowmentShare(_gameId);
            endowmentDB.updateEndowmentFund(winningsKTY, winningsETH, false);
            endowmentDB.updateHoneyPotFund(_gameId, winningsKTY, winningsETH, true);
        }
        if(_state == uint(HoneypotState.forefeited)) {
            (uint256 eth, uint256 kty) = endowmentDB.getHoneypotTotal(_gameId);
            endowmentDB.updateEndowmentFund(kty, eth, false);
            endowmentDB.updateHoneyPotFund(_gameId, kty, eth, true);
        }
        endowmentDB.setHoneypotState(_gameId, _state);
    }

    /**
     * @dev Send KTY from EndowmentFund to Escrow
     */
    function sendKTYtoEscrow(uint256 _kty_amount)
        external
        onlySuperAdmin
    {
        require(_kty_amount > 0);

        kittieFightToken.transfer(address(escrow), _kty_amount);

        endowmentDB.updateEndowmentFund(_kty_amount, 0, false);

        emit SentKTYtoEscrow(address(this), _kty_amount, address(escrow));
    }

    /**
     * @dev Send eth to Escrow
     */
    function sendETHtoEscrow() external payable {
        address msgSender = getOriginalSender();

        require(msg.value > 0);

        address(escrow).transfer(msg.value);

        endowmentDB.updateEndowmentFund(0, msg.value, false);

        emit SentETHtoEscrow(msgSender, msg.value, address(escrow));
    }

    /**
     * @dev accepts KTY. KTY is swapped in uniswap.
     * @dev KTY is sent to escrow. Ether is sent to KTY-WETH pair contract by the user.
     * @dev Escrow sends 2x of KTY received in swap to KTY-WETH pair contract to maintain the
     *      original ether to KTY ratio.
     */
    function contributeKTY(address _sender, uint256 _kty_amount) external payable returns(bool) {
        uint etherForSwap = KtyUniswap(proxy.getContract(CONTRACT_NAME_KTY_UNISWAP)).etherFor(_kty_amount);
        // allow an error within 0.0001 ether range, which is around $0.002 USD, that is, 0.2 cents.
        require(msg.value >= etherForSwap.sub(10000000000000), "Insufficient ether for swap KTY");
        // exchange KTY on uniswap
        IUniswapV2Router01(proxy.getContract(CONTRACT_NAME_UNISWAPV2_ROUTER)).swapExactETHForTokens.value(msg.value)(
            0,
            path,
            address(escrow),
            2**255
        );

        endowmentDB.updateEndowmentFund(_kty_amount, 0, false);

        emit EthSwappedforKTY(_sender, msg.value, _kty_amount, address(escrow));

        return true;
    }

    /**
     * @dev GM calls
     */
    function contributeETH(uint _gameId) external payable returns(bool) {
        // require(address(escrow) != address(0));
        address msgSender = getOriginalSender();

        require(msg.value > 0);

        // transfer ETH to Escrow
        if (!address(escrow).send(msg.value)){
            return false;
        }

        endowmentDB.updateHoneyPotFund(_gameId, 0, msg.value, false);

        emit SentETHtoEscrow(msgSender, msg.value, address(escrow));

        return true;
    }

    function contributeETH_Ethie()
    external
    onlyContract(CONTRACT_NAME_EARNINGS_TRACKER)
    payable
    returns(bool)
    {
        // require(address(escrow) != address(0));
        address msgSender = getOriginalSender();

        require(msg.value > 0);

        // transfer ETH to Escrow
        if (!address(escrow).send(msg.value)){
            return false;
        }

        endowmentDB.updateInvestment(msg.value);

        emit SentETHtoEscrow(msgSender, msg.value, address(escrow));

        return true;
    }

    /**
    * @notice MUST BE DONE BEFORE UPGRADING ENDOWMENT AS IT IS THE OWNER
    * @dev change Escrow contract owner before UPGRADING ENDOWMENT AS IT IS THE OWNER
    */
    function transferEscrowOwnership(address payable _newOwner) external onlySuperAdmin {
        escrow.transferOwnership(_newOwner);
    }

    /**
    * @dev transfer Escrow ETH funds
    */
    function transferETHfromEscrow(address payable _someAddress, uint256 _eth_amount)
    private
    returns(bool){
        // require(address(_someAddress) != address(0));

        // transfer the ETH
        escrow.transferETH(_someAddress, _eth_amount);

        // Update DB. true = deductFunds
        endowmentDB.updateEndowmentFund(0, _eth_amount, true);

        return true;
    }

    function transferETHfromEscrowWithdrawalPool(address payable _someAddress, uint256 _eth_amount, uint256 _pool_id)
        public
        onlyContract(CONTRACT_NAME_WITHDRAW_POOL)
        returns(bool)
    {
        endowmentDB.subETHfromPool(_eth_amount, _pool_id);
        transferETHfromEscrow(_someAddress, _eth_amount);
        return true;
    }

    function transferETHfromEscrowEarningsTracker(address payable _someAddress, uint256 _eth_amount, bool invested)
        public
        onlyContract(CONTRACT_NAME_EARNINGS_TRACKER)
        returns(bool)
    {
        if(!invested) {
            endowmentDB.subInvestment(_eth_amount);
            escrow.transferETH(_someAddress, _eth_amount);
        }
        else
            transferETHfromEscrow(_someAddress, _eth_amount);
        return true;
    }

    /**
    * @dev transfer Escrow KFT funds
    */
    function transferKTYfromEscrow(address _someAddress, uint256 _kty_amount)
    private
    returns(bool){
        // require(address(_someAddress) != address(0));

        // transfer the KTY
        escrow.transferKTY(_someAddress, _kty_amount);

        // Update DB. true = deductFunds
        endowmentDB.updateEndowmentFund(_kty_amount, 0, true);

        return true;
    }

    function addETHtoPool(uint256 gameId, address loser)
        external
        onlyContract(CONTRACT_NAME_GAMEMANAGER)
    {
        uint256 totalEthForLoser = gmGetterDB.getTotalBet(gameId, loser);
        uint256 ETHtoPool = totalEthForLoser.mul(gameVarAndFee.getPercentageForPool()).div(1000000);
        endowmentDB.addETHtoPool(gameId, ETHtoPool);
    }

    /**
    * @dev Initialize or Upgrade Escrow
    * @notice BEFORE CALLING: Deploy escrow contract and set the owner as EndowmentFund contract
    */
    function initUpgradeEscrow(Escrow _newEscrow) external onlySuperAdmin returns(bool){

        // require(address(_newEscrow) != address(0));
        _newEscrow.initialize(kittieFightToken);

        // check ownership
        // require(_newEscrow.owner() == address(this));

        // KTY is set
        // require(_newEscrow.getKTYaddress() != address(0));

        if (address(escrow) != address(0)){ // Transfer if any funds

            // transfer all the ETH
            escrow.transferETH(address(_newEscrow), address(escrow).balance);

            // transfer all the KTY
            uint256 ktyBalance = kittieFightToken.balanceOf(address(escrow));
            escrow.transferKTY(address(_newEscrow), ktyBalance);

        }

        escrow = _newEscrow;
        return true;
    }


    /**
     * @dev Do not upgrade Endowment if owner of escrow is still this contract's address
     * Steps:
     * deploy new Endowment
     * set owner of escrow to new Endowment adrress using endowment.transferEscrowOwnership(new Endowment adrress)
     * than set the new Endowment adrress in proxy
     */
    function isEndowmentUpgradabe() public view returns(bool){
        return (address(escrow.owner) != address(this));
    }

}
