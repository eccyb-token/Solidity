/**
 *Submitted for verification at bttcscan.com on 2026-01-31
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ECCYBStaking
 * @dev Проєкт ECCYB - Кафедра ІТ ЗІЕІТ
 * SECURITY FIX: Додано перевірки доступу (Access Control) для захисту гаманця TREASURY.
 */

interface IECCYB {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract ECCYBStaking {
    IECCYB public token;
    
    // Адреса скарбниці кафедри (Власник)
    // Всі виплати йдуть з цієї адреси через allowance
    address public constant TREASURY = 0xF08B28C6D8A26CD1a24d1DBc95C89005F1E04EAD;
    
    // Відсоток винагороди (10%)
    uint256 public constant REWARD_RATE = 10;

    struct Deposit {
        uint256 amount;
        uint256 unlockTime;
        bool claimed;
    }

    mapping(address => Deposit) public deposits;

    // Модифікатор для обмеження доступу: тільки викладач (власник гаманця TREASURY)
    modifier onlyOwner() {
        require(msg.sender == TREASURY, "ECCYB: Access denied. Only for IT Dept Administrator");
        _;
    }

    event Staked(address indexed user, uint256 amount, uint256 unlockTime);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event EarlyWithdrawal(address indexed user, uint256 amount);

    constructor(address _tokenAddress) {
        token = IECCYB(_tokenAddress);
    }

    /**
     * @dev Публічна функція: Студент вносить активи.
     * Кошти йдуть на гаманець TREASURY.
     */
    function stake(uint256 _amount, uint256 _days) external {
        require(_amount > 0, "ECCYB: Amount must be > 0");
        require(_days > 0, "ECCYB: Duration must be > 0");
        
        // Виклик transferFrom: студент -> TREASURY
        require(
            token.transferFrom(msg.sender, TREASURY, _amount), 
            "ECCYB: Deposit transfer failed"
        );

        deposits[msg.sender] = Deposit({
            amount: _amount,
            unlockTime: block.timestamp + (_days * 1 days),
            claimed: false
        });

        emit Staked(msg.sender, _amount, deposits[msg.sender].unlockTime);
    }

    /**
     * @dev Публічна функція: Вивід після завершення терміну.
     * Безпека забезпечена використанням msg.sender для доступу до мапінгу.
     */
    function withdraw() external {
        Deposit storage d = deposits[msg.sender];
        
        require(d.amount > 0, "ECCYB: No active deposit");
        require(!d.claimed, "ECCYB: Already claimed");
        require(block.timestamp >= d.unlockTime, "ECCYB: Staking term not finished");

        uint256 reward = (d.amount * REWARD_RATE) / 100;
        uint256 totalPayout = d.amount + reward;

        require(token.balanceOf(TREASURY) >= totalPayout, "ECCYB: Treasury empty");

        d.claimed = true;
        uint256 payout = totalPayout;
        d.amount = 0;

        // Виплата: TREASURY -> Студент
        require(token.transferFrom(TREASURY, msg.sender, payout), "ECCYB: Payout failed");

        emit Withdrawn(msg.sender, payout, reward);
    }

    /**
     * @dev Публічна функція: Достроковий вивід без бонусу.
     */
    function earlyWithdraw() external {
        Deposit storage d = deposits[msg.sender];
        
        require(d.amount > 0, "ECCYB: No active deposit");
        require(!d.claimed, "ECCYB: Already claimed");

        uint256 amountToReturn = d.amount;
        d.claimed = true;
        d.amount = 0;

        require(token.transferFrom(TREASURY, msg.sender, amountToReturn), "ECCYB: Early payout failed");

        emit EarlyWithdrawal(msg.sender, amountToReturn);
    }

    /**
     * @dev АДМІНІСТРАТИВНА ФУНКЦІЯ: Зміна адреси токену.
     * ВИПРАВЛЕНО: Додано onlyOwner для запобігання захопленню контролю над контрактом.
     */
    function updateTokenAddress(address _newToken) external onlyOwner {
        require(_newToken != address(0), "ECCYB: Invalid address");
        token = IECCYB(_newToken);
    }

    /**
     * @dev АДМІНІСТРАТИВНА ФУНКЦІЯ: Ручне анулювання депозиту (у разі помилки студента).
     * ВИПРАВЛЕНО: Додано onlyOwner.
     */
    function adminCancelDeposit(address _student) external onlyOwner {
        deposits[_student].claimed = true;
        deposits[_student].amount = 0;
    }
}
