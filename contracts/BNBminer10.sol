// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BNBminer10 {
    uint256 public constant EGGS_TO_HATCH_1MINERS = 864000;
    uint256 public constant PSN = 10000;
    uint256 public constant PSNH = 5000;
    bool public initialized = false;
    address public ceoAddress;

    mapping(address => uint256) public hatcheryMiners;
    mapping(address => uint256) public claimedEggs;
    mapping(address => uint256) public lastHatch;
    mapping(address => address) public referrals;
    uint256 public marketEggs;

    event EggsRebaked(address indexed user, address indexed ref, uint256 eggsUsed, uint256 newMiners);
    event EggsEaten(address indexed user, uint256 eggsSold, uint256 reward, uint256 fee);
    event EggsBaked(address indexed user, uint256 eggsBought, uint256 amountSpent);

    constructor() {
        ceoAddress = msg.sender;
    }

    modifier onlyInitialized() {
        require(initialized, "Market not initialized yet");
        _;
    }

    modifier onlyCEO() {
        require(msg.sender == ceoAddress, "Caller is not the CEO");
        _;
    }

    function rebakePizza(address ref) public onlyInitialized {
        if (ref == msg.sender || ref == address(0) || hatcheryMiners[ref] == 0) {
            ref = ceoAddress;
        }
        if (referrals[msg.sender] == address(0)) {
            referrals[msg.sender] = ref;
        }

        uint256 eggsUsed = getMyEggs();
        uint256 newMiners = eggsUsed / EGGS_TO_HATCH_1MINERS;
        hatcheryMiners[msg.sender] += newMiners;
        claimedEggs[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;

        // Send referral eggs
        claimedEggs[referrals[msg.sender]] += (eggsUsed * 15) / 100;

        // Boost market to nerf miners hoarding
        marketEggs += eggsUsed / 3;

        emit EggsRebaked(msg.sender, ref, eggsUsed, newMiners);
    }

    function eatPizza() public onlyInitialized {
        uint256 hasEggs = getMyEggs();
        uint256 eggValue = calculateEggSell(hasEggs);
        uint256 fee = devFee(eggValue);
        claimedEggs[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;
        marketEggs += hasEggs;

        payable(ceoAddress).transfer(fee);
        payable(msg.sender).transfer(eggValue - fee);

        emit EggsEaten(msg.sender, hasEggs, eggValue - fee, fee);
    }

    function bakePizza(address ref) public payable onlyInitialized {
        uint256 eggsBought = calculateEggBuy(msg.value, address(this).balance - msg.value);
        uint256 fee = devFee(msg.value);
        eggsBought -= devFee(eggsBought);

        payable(ceoAddress).transfer(fee);
        claimedEggs[msg.sender] += eggsBought;

        rebakePizza(ref);
        emit EggsBaked(msg.sender, eggsBought, msg.value);
    }

    function calculateTrade(uint256 rt, uint256 rs, uint256 bs) public pure returns (uint256) {
        return (PSN * bs) / (PSNH + ((PSN * rs + PSNH * rt) / rt));
    }

    function calculateEggSell(uint256 eggs) public view returns (uint256) {
        return calculateTrade(eggs, marketEggs, address(this).balance);
    }

    function calculateEggBuy(uint256 eth, uint256 contractBalance) public view returns (uint256) {
        return calculateTrade(eth, contractBalance, marketEggs);
    }

    function calculateEggBuySimple(uint256 eth) public view returns (uint256) {
        return calculateEggBuy(eth, address(this).balance);
    }

    function devFee(uint256 amount) public pure returns (uint256) {
        return (amount * 7) / 100;
    }

    function openKitchen() public payable onlyCEO {
        require(marketEggs == 0, "Market already initialized");
        initialized = true;
        marketEggs = 86400000000;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getMyMiners() public view returns (uint256) {
        return hatcheryMiners[msg.sender];
    }

    function getMyEggs() public view returns (uint256) {
        return claimedEggs[msg.sender] + getEggsSinceLastHatch(msg.sender);
    }

    function getEggsSinceLastHatch(address adr) public view returns (uint256) {
        uint256 secondsPassed = min(EGGS_TO_HATCH_1MINERS, block.timestamp - lastHatch[adr]);
        return secondsPassed * hatcheryMiners[adr];
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}