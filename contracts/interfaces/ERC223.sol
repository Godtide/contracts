pragma solidity ^0.5.5;


/*
 ERC223 additions to ERC20

 Interface wise is ERC20 + data parameter to transfer and transferFrom.
*/
interface ERC223 {
    function transfer(address to, uint value, bytes calldata data) external returns (bool);
    function transferFrom(address from, address to, uint value, bytes calldata data) external returns (bool);
}
