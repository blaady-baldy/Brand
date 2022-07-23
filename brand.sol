// SPDX-License-Identifier: MIT
 pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error NFT_decayed();
error Admin__UpkeepNotTrue();
error Admin__NoBrandAvailable();
error Not_Owner();

contract brand is ERC721URIStorage, Ownable, KeeperCompatibleInterface{

    // uint256 public tokenCounter;
    address public creator;
    bool public isMintEnabled;
    uint256 public totalSupply;
    uint fee;
    uint maxSupply;
    uint256 private immutable day_interval;
    uint256 private s_currentTimeStamp;
    bool startWarranty = false;
    bool firstTransact;

    mapping(uint256 => address[]) owners;
    mapping(uint256 => uint256) warrantyPeriod;
    mapping(uint256 => bool) isValid;
    mapping(uint256 => string) repairHistory;

    constructor(uint256 interval)
    payable
    ERC721("Product", "PRD")
    {
        fee = 0.1 * 10 ** 18;
        totalSupply = 0;
        isMintEnabled = true;
        maxSupply = 100;
        creator = msg.sender;
        day_interval=interval;
        firstTransact = true;
    }

    function createCollectible(string memory _tokenURI, uint256 _warrantyPeriod) 
        external onlyOwner payable{
        require(isMintEnabled, "Minting is not enabled");
        // require(msg.value > fee, "Wrong Value");
        require(maxSupply > totalSupply, "Sold Out");

        totalSupply++;
        uint256 tokenId = totalSupply;

        // tokens.push(Token(msg.sender, _tokenURI, _warrantyPeriod, true));
        warrantyPeriod[tokenId] = _warrantyPeriod;
        isValid[tokenId] = true;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);
    }

    function toggleMint() external onlyOwner {
        isMintEnabled = !isMintEnabled;
    }

    function setMaxSupply(uint256 _maxSupply) external onlyOwner{
        maxSupply = _maxSupply;
    }

    function transferToken(address _sendTo, uint256 _tokenId) public payable{
        if(firstTransact){
            // tokens[_tokenId].isValid = true;
            firstTransact = false;
            s_currentTimeStamp = block.timestamp;
            startWarranty = true;
        }
        if((ownerOf(_tokenId) == msg.sender)&&(isValid[_tokenId])){
            // tokens[_tokenId].owner = _sendTo;
            addOwner(_sendTo, _tokenId);
            _transfer(msg.sender, _sendTo, _tokenId);
        } else revert Not_Owner();

    }

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        upkeepNeeded = ((block.timestamp - s_currentTimeStamp) > day_interval) && startWarranty;
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");

        if (!upkeepNeeded) revert Admin__UpkeepNotTrue();
        if (totalSupply == 0) revert Admin__NoBrandAvailable();

        for (uint256 i = 1; i <= totalSupply && isValid[i]; i++) {
            warrantyPeriod[i] -= 1;
            if (warrantyPeriod[i] == 0) {
                isValid[i] = false;
                // delete(tokens[i]);
            }
        }

        s_currentTimeStamp = block.timestamp;

        bool flag = false;
        for (uint256 i = 1; i <=totalSupply; i++) {
            if(isValid[i] == true){
                flag=true;
            }
        }
            if(!flag){
                startWarranty = false;
            }
    }

    function isNFTDecayed(uint256 _tokenId) public view returns(bool){
        return !isValid[_tokenId];
    }

    function isOwner(uint256 _tokenId) public view returns(bool){
        if(msg.sender == ownerOf(_tokenId)){
            return true;
        }
        else{
            return false;
        }
    }

    function validityPeriod(uint256 _tokenId) public view returns(uint256){
        return warrantyPeriod[_tokenId];
    }

    function viewRepairHistory(uint256 _tokenId) public view returns(string memory){
        return repairHistory[_tokenId];
    }

    function setRepairHistory(uint256 _tokenId, string memory _newRepairHistory) external {
        if( ownerOf(_tokenId) == msg.sender ){
            repairHistory[_tokenId] = _newRepairHistory;
        }
    }

    function addOwner(address _address,uint256 _tokenId) private {
        owners[_tokenId].push(_address);
    }

    function getOwnersLength(uint256 _tokenId) view public returns(uint256) {
        return owners[_tokenId].length;
    }

    function getOwner(uint256 _tokenId, uint256 _index) view public returns(address){
        return owners[_tokenId][_index];
    }
}
