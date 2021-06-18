// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
abstract contract ERC20 is Context, IERC20 {
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "BIP20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "BIP20: transfer from the zero address");
        require(recipient != address(0), "BIP20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "BIP20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "BIP20: approve from the zero address");
        require(spender != address(0), "BIP20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { 
        // add some actions whot's goingon
    }
}
contract Token is ERC20 {}
contract AnimeSwap is Ownable {
    
    // IS HARDCODED TOKEN CONTRACT FOR USAGE
    // MAINNET is = 0xcf086F22de62Ee13FABFe917385A200665D0083F
    Token public token = Token(0xEA5b0daabE97877deF78b239e682ddd1e898Be97);
    string public tokenSymbol  = "AMD";
    
    function emergencyWithdrawTokens() external onlyOwner() {
        uint balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
    }
    
    // CONTRACT IS NOT DESIGN FOR HOLDING BNB BUT WE HAVE THIS ACTION JUST INCASE
    function emergencyWithdrawBNB() external onlyOwner() {
       uint balance = address(this).balance;
       // require(balance > 0, "Token: balance is to low");
       // transfer(msg.sender, balance);
       token.approve(owner(), balance);
       // transferFrom(msg.sender,owner(),msg.value);
       payable( owner() ).transfer(balance);
    }

    // ACCEPT ANY PAYMENTS
    receive() external payable {}
    constructor () payable {}

    // SET NEW PRICE
    event TokenPrice(uint _value);
    uint public priceToBNB = 350;
    function setPrice(uint new_price) virtual external onlyOwner() returns (uint) {
        emit TokenPrice(new_price);
        return priceToBNB = new_price;
    }

    // SWAP ACTION
    event Swap(uint _bnb, uint _recive_tokens, address to_address );
    function swap() public payable virtual returns (bool) {

       uint bnb = msg.value;
       require(bnb != 0, "BIP20: transfer amount exceeds balance");
       
       uint token_value = bnb * priceToBNB;
        
       //FIXED DECIMAL
       token_value = token_value / (10 ** 16);
       
       // require(token_value <= token.balanceOf(address(this)), "not enoph tokens for cashback");
       token.transfer(msg.sender, token_value);

       // SEND BNB
       // token.approve( owner(), bnb);
       payable( owner() ).transfer(bnb);
       emit Swap(bnb, token_value, msg.sender);
       return true;
    }
}


contract AnimeShop is AnimeSwap {
    bool public cashback = true;
    uint public cashbackPercent = 800; // in fact 8%
    
    event BuyAction(uint _value,string _in_token_or_coin, string _uid);
    function buyInToken(
        string memory _ipfs, 
        string memory _uid, 
        uint _value
        ) public virtual returns (bool) {
        
        // require(_value <= token.balanceOf(msg.sender), "not enoph tokens on the balance");
        token.transferFrom(msg.sender, owner(), _value);
        // _value
        set_invoice(_ipfs, _uid, tokenSymbol, false, 0, _value);
        return true;
    }

    function buyInBNB(
        string memory _ipfs,
        string memory _uid
        ) public payable virtual returns (bool) {
        
        uint bnb = msg.value;
        require(bnb != 0, "BIP20: transfer amount exceeds balance");
        uint cash_amount;
        if (cashback) {
           uint256 cash_back_math = bnb * priceToBNB;
           
           // Percentage 10000
           cash_back_math = (cash_back_math / 10000) * cashbackPercent;
           
           //FIXED DECIMAL 
           cash_back_math = cash_back_math / (10 ** 16);
           token.transfer(msg.sender, cash_back_math);
           cash_amount = cash_back_math;
        } else {
           cash_amount = 0;
        }
        
        // SEND BNB TO CREATOR
        // token.approve( owner(), bnb);
        payable( owner() ).transfer(bnb);
        
        set_invoice(_ipfs, _uid, "BNB", cashback, cash_amount, bnb);
        return true;
    }

    // CREATE INVOICE
    mapping(address => uint) private invoices_index;
    mapping(address => string[]) private invoices_list;
    event Invoice(address _order_address, string _uid, string _ipfs_url, string _currency, bool _cashback, uint _cashback_amount, uint _order_value );
    function set_invoice(
        string memory _ipfs,
        string memory _uid, 
        string memory _currency, 
        bool _cash_back, 
        uint _cash_amount, 
        uint _order_value) private {
            invoices_index[msg.sender] = invoices_index[msg.sender] + 1;
            invoices_list[msg.sender].push(_ipfs);
            emit Invoice( msg.sender, _uid, _ipfs, _currency, _cash_back, _cash_amount, _order_value );
    }
    function invoiceIndex(address invoice_address) public virtual view returns (uint) {
        return invoices_index[invoice_address];
    }
    function invoiceList(address invoice_address) public virtual view returns (string[] memory) {
        return invoices_list[invoice_address];
    } 
    // CHASH BACK
    function setCashback(bool _switcher) public virtual  onlyOwner()  returns (bool) {
        return cashback = _switcher;
    }
    function setCashbackPercent(uint _percent) public virtual onlyOwner() returns (uint) {
        return cashbackPercent = _percent;
    }
    
}
