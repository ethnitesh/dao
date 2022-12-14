// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IFakeNFTMarketplace {
    function getPrice() external view returns(uint256);
    function available(uint256 _tokenId) external view returns (bool);
    function purchase(uint256 _tokenId) external payable;
}

interface ICryptoDevNFT {
    function balanceOf(address owner) external view  returns (uint256) ;
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns(uint256);
}


contract CryptoDevsDAO is Ownable {
 
 struct Proposal {
    uint256 nftTokenId;
    uint256 deadline;
    uint256 yayVotes;
    uint256 nayVotes;
    bool executed;
    mapping (uint256 => bool) voters;
 }
 mapping (uint256 => Proposal) public proposals;
 uint256 public numProposals;

enum Vote {
    YAY, // yay=0
    NAY // nay =1
}

 IFakeNFTMarketplace nftMarketplace;
 ICryptoDevNFT cryptoDevsNFT;

    constructor(address _nftMarketplace, address _cryptoDevNFT) payable {
        nftMarketplace=IFakeNFTMarketplace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevNFT(_cryptoDevNFT); 
    }

    modifier NftHolderOnly() {
        require(cryptoDevsNFT.balanceOf(msg.sender)>0,"NOT A DAO Member");
        _;
    }
     
     modifier activeProposalOnly(uint256 proposalIndex){
        require(proposals[proposalIndex].deadline > block.timestamp,"DEADLINE EXCEEDED");
        _;
     }
     
     modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline <= block.timestamp, "DEADLINE NOT EXCEEDED");
        
        require(proposals[proposalIndex].executed == false,"PROPOSAL ALREADY EXECUTED");
        _;
     }

    function createProposal(uint256 _nftTokenId) external NftHolderOnly returns(uint256){
        require(nftMarketplace.available(_nftTokenId),"NFT Not For sale");
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId =_nftTokenId;
        proposal.deadline = block.timestamp + 5 minutes;
        numProposals++;
        return numProposals-1;
    }

    function voteOnProposal(uint256 proposalIndex, Vote vote) external NftHolderOnly activeProposalOnly(proposalIndex)
    {
        Proposal storage proposal = proposals[proposalIndex];

        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes =0;

        for(uint256 i=0; i<voterNFTBalance; i++){
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender,i);
            if (proposal.voters[tokenId] == false) {
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }
        require(numVotes >0, "Already Voted");
        if (vote== Vote.YAY) {
            proposal.yayVotes += numVotes;
        }
        else {
            proposal.nayVotes += numVotes;
        }
    }

    function executeProposal(uint256 proposalIndex) external NftHolderOnly inactiveProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];
      
      if(proposal.yayVotes > proposal.nayVotes){
        uint256 nftPrice = nftMarketplace.getPrice();
        require(address(this).balance >= nftPrice, "Not Enough Funds");
        nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
      }
      proposal.executed = true;
    }

    function withdrawEther() external onlyOwner{
        payable(owner()).transfer(address(this).balance);
    }
    receive() external payable{}
    fallback() external payable{}
}