// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./DateTime.sol";
import "../interfaces/ICashbackModule.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SubscriptionsContract is OwnableUpgradeable, DateTime {
    using SafeMathUpgradeable for uint256;

    IERC20 public xgt;
    address public feeWallet;
    // ICashbackModule public cashback;

    enum Status {NULL, ACTIVE, PAUSED, UNSUBSCRIBED, END}

    struct Subscription {
        address user;
        address merchant;
        string productId;
        string parentProductId;
        Status status;
        bool unlimited;
        uint256 billingDay;
        uint256 nextBillingDay;
        uint256 billingCycle;
        uint256 cycles;
        uint256 price;
        uint256 successPaymentsAmount;
        uint256 lastPaymentDate;
    }

    struct OneTimePurchase {
        address user;
        address merchant;
        string productId;
        string parentProductId;
        uint256 date;
        uint256 price;
        bool paid;
    }

    mapping(string => Subscription) private subscriptions;
    mapping(string => OneTimePurchase) private purchases;
    mapping(string => bool) private productPaused;

    mapping(address => uint256) private activeSubscriptionsOfUser;
    mapping(address => uint256) public customerBalances;

    event SubscriptionCreated(
        address user,
        address merchant,
        string subscriptionId,
        string productId
    );
    event SubscriptionMonthlyPaymentPaid(
        address user,
        address merchant,
        uint256 payment,
        uint256 lastPaymentDate
    );

    function initialize(address _xgt, address _feeWallet) external initializer {
        xgt = IERC20(_xgt);
        feeWallet = _feeWallet;
    }

    // function updateCashbackModule(address _cashbackModule) public onlyOwner {
    //     cashback = ICashbackModule(_cashbackModule);
    // }

    function updateFeeWallet(address _feeWallet) external onlyOwner {
        feeWallet = _feeWallet;
    }

    fallback() external payable {
        _deposit(msg.sender);
    }

    receive() external payable {
        _deposit(msg.sender);
    }

    function deposit() public payable {
        _deposit(msg.sender);
    }

    function depositForUser(address _user) public payable {
        _deposit(_user);
    }

    function _deposit(address _user) internal {
        require(_user != address(0), "Empty address provided");
        customerBalances[_user] = customerBalances[_user].add(msg.value);
    }

    function withdraw() public {
        _withdraw(msg.sender);
    }

    function withdrawForUser(address _user) public onlyOwner {
        _withdraw(_user);
    }

    function _withdraw(address _user) internal {
        require(_user != address(0), "Empty address provided");
        require(
            activeSubscriptionsOfUser[_user] == 0,
            "User still has an ongoing subscription"
        );
        uint256 remainingBalance = customerBalances[_user];
        if (remainingBalance > 0) {
            customerBalances[_user] = 0;
            _transferXdai(_user, remainingBalance);
        }
    }

    function subscribeUser(
        address user,
        address merchant,
        string memory subscriptionId,
        string memory productId,
        uint256 billingDay,
        uint256 billingCycle,
        uint256 cycles,
        uint256[] calldata priceInfo, // price, basePayment, tokenPayment, tokenPrice
        bool unlimited,
        string memory parentProductId
    ) public onlyOwner {
        require(!productPaused[productId], "Product paused by merchant");
        require(
            subscriptions[subscriptionId].status != Status.ACTIVE,
            "User already has an active subscription for this merchant"
        );
        require(billingDay <= 28, "Invalid billing day");

        if (bytes(subscriptions[subscriptionId].parentProductId).length > 0) {
            require(
                !productPaused[subscriptions[subscriptionId].parentProductId],
                "Parent product paused by merchant"
            );
        }

        activeSubscriptionsOfUser[user] = activeSubscriptionsOfUser[user].add(
            1
        );
        subscriptions[subscriptionId] = Subscription(
            user,
            merchant,
            productId,
            parentProductId,
            Status.ACTIVE,
            unlimited,
            billingDay,
            0,
            billingCycle,
            cycles,
            priceInfo[0],
            0,
            0
        );
        emit SubscriptionCreated(user, merchant, subscriptionId, productId);
        processSubscriptionPayment(
            subscriptionId,
            priceInfo[1],
            priceInfo[2],
            priceInfo[3]
        );
    }

    function processSubscriptionPayment(
        string memory subscriptionId,
        uint256 basePayment,
        uint256 tokenPayment,
        uint256 tokenPrice
    ) public onlyOwner {
        uint256 tokenPaymentValue = (tokenPayment.mul(tokenPrice)).div(10**18);
        uint256 totalValue = tokenPaymentValue.add(basePayment);
        require(
            (subscriptions[subscriptionId].successPaymentsAmount <
                subscriptions[subscriptionId].cycles) ||
                subscriptions[subscriptionId].unlimited,
            "Subscription is over"
        );
        require(
            (basePayment.add(tokenPaymentValue) <=
                subscriptions[subscriptionId].price),
            "Payment cant be more then started payment amount"
        );
        require(
            !productPaused[subscriptions[subscriptionId].productId],
            "Product paused by merchant"
        );
        require(
            subscriptions[subscriptionId].status != Status.UNSUBSCRIBED,
            "Subscription must not be unsubscribed"
        );
        require(
            subscriptions[subscriptionId].status != Status.PAUSED,
            "Subscription must not be paused"
        );

        require(
            block.timestamp >= subscriptions[subscriptionId].nextBillingDay
        );
        if (subscriptions[subscriptionId].billingDay != 0) {
            uint8 month = getMonth(block.timestamp);
            uint16 year = getYear(block.timestamp);
            if (month == 12) {
                month = 1;
                year++;
            } else {
                month++;
            }
            subscriptions[subscriptionId].nextBillingDay = toTimestamp(
                year,
                month,
                uint8(subscriptions[subscriptionId].billingDay),
                0,
                0,
                0
            );
        } else {
            if (subscriptions[subscriptionId].nextBillingDay == 0) {
                subscriptions[subscriptionId].nextBillingDay = block.timestamp;
            }
            subscriptions[subscriptionId].nextBillingDay = subscriptions[
                subscriptionId
            ]
                .nextBillingDay
                .add(subscriptions[subscriptionId].billingCycle);
        }

        if (
            customerBalances[subscriptions[subscriptionId].user].add(
                tokenPaymentValue
            ) <
            subscriptions[subscriptionId].price ||
            xgt.balanceOf(subscriptions[subscriptionId].user) < tokenPayment
        ) {
            subscriptions[subscriptionId].status = Status.UNSUBSCRIBED;
            return;
        }

        customerBalances[subscriptions[subscriptionId].user] = customerBalances[
            subscriptions[subscriptionId].user
        ]
            .sub(basePayment);

        _transferXdai(subscriptions[subscriptionId].merchant, basePayment);
        _transferXGT(
            subscriptions[subscriptionId].user,
            subscriptions[subscriptionId].merchant,
            tokenPayment
        );

        subscriptions[subscriptionId].status = Status.ACTIVE;
        subscriptions[subscriptionId].lastPaymentDate = block.timestamp;
        subscriptions[subscriptionId].successPaymentsAmount = subscriptions[
            subscriptionId
        ]
            .successPaymentsAmount
            .add(1);

        emit SubscriptionMonthlyPaymentPaid(
            subscriptions[subscriptionId].user,
            subscriptions[subscriptionId].merchant,
            totalValue,
            subscriptions[subscriptionId].lastPaymentDate
        );

        if (
            subscriptions[subscriptionId].successPaymentsAmount ==
            subscriptions[subscriptionId].cycles &&
            !subscriptions[subscriptionId].unlimited
        ) {
            subscriptions[subscriptionId].status = Status.END;
            activeSubscriptionsOfUser[
                subscriptions[subscriptionId].user
            ] = activeSubscriptionsOfUser[subscriptions[subscriptionId].user]
                .sub(1);
        }
    }

    function processOneTimePurchase(
        address user,
        address merchant,
        string memory purchaseId,
        string memory productId,
        string memory parentProductId,
        uint256 price,
        uint256 basePayment,
        uint256 tokenPayment,
        uint256 tokenPrice
    ) public onlyOwner {
        require(
            customerBalances[user] >= basePayment &&
                xgt.balanceOf(user) >= tokenPayment,
            "User doesnt have enough tokens for first payment"
        );

        purchases[purchaseId] = OneTimePurchase(
            user,
            merchant,
            productId,
            parentProductId,
            block.timestamp,
            price,
            false
        );
        processOneTimePayment(
            purchaseId,
            basePayment,
            tokenPayment,
            tokenPrice
        );
    }

    function processOneTimePayment(
        string memory purchaseId,
        uint256 basePayment,
        uint256 tokenPayment,
        uint256 tokenPrice
    ) public onlyOwner {
        uint256 tokenPaymentValue = (tokenPayment.mul(tokenPrice)).div(10**18);
        require(
            basePayment.add(tokenPaymentValue) <= purchases[purchaseId].price,
            "Payment cant be more then started payment amount"
        );

        require(!purchases[purchaseId].paid, "Already paid");

        require(
            customerBalances[purchases[purchaseId].user] >= basePayment &&
                xgt.balanceOf(purchases[purchaseId].user) >= tokenPayment,
            "Balance not sufficient"
        );

        customerBalances[purchases[purchaseId].user] = customerBalances[
            purchases[purchaseId].user
        ]
            .sub(basePayment);

        _transferXdai(purchases[purchaseId].merchant, basePayment);
        _transferXGT(
            purchases[purchaseId].user,
            purchases[purchaseId].merchant,
            tokenPayment
        );

        purchases[purchaseId].paid = true;
    }

    function pauseSubscriptionsByMerchant(string memory productId)
        public
        onlyOwner
    {
        productPaused[productId] = true;
    }

    function activateSubscriptionsByMerchant(string memory productId)
        public
        onlyOwner
    {
        productPaused[productId] = false;
    }

    function unsubscribeBatchByMerchant(string[] memory subscriptionIds)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < subscriptionIds.length; i++) {
            cancelSubscription(subscriptionIds[i]);
        }
    }

    function cancelSubscription(string memory subscriptionId) public onlyOwner {
        subscriptions[subscriptionId].status = Status.UNSUBSCRIBED;
        activeSubscriptionsOfUser[
            subscriptions[subscriptionId].user
        ] = activeSubscriptionsOfUser[subscriptions[subscriptionId].user].sub(
            1
        );
    }

    function pauseSubscription(string memory subscriptionId) public onlyOwner {
        require(
            subscriptions[subscriptionId].status != Status.PAUSED,
            "Subscription is already paused"
        );
        require(
            customerBalances[subscriptions[subscriptionId].user] >=
                subscriptions[subscriptionId].price.mul(125).div(1000),
            "User doesnt have enough tokens for pause payment"
        );

        subscriptions[subscriptionId].status = Status.PAUSED;

        uint256 merchantValue =
            subscriptions[subscriptionId].price.mul(10).div(100);
        uint256 feeValue =
            subscriptions[subscriptionId].price.mul(25).div(1000);
        customerBalances[subscriptions[subscriptionId].user] = customerBalances[
            subscriptions[subscriptionId].user
        ]
            .sub(merchantValue);

        _transferXdai(subscriptions[subscriptionId].merchant, merchantValue);
        _transferXdai(feeWallet, feeValue);
    }

    function activateSubscription(string memory subscriptionId)
        public
        onlyOwner
    {
        require(
            subscriptions[subscriptionId].status != Status.UNSUBSCRIBED,
            "Subscription must be unsubscribed"
        );
        subscriptions[subscriptionId].status = Status.ACTIVE;
    }

    function getSubscriptionStatus(string calldata subscriptionId)
        external
        view
        returns (uint256)
    {
        return uint256(subscriptions[subscriptionId].status);
    }

    function getSubscriptionDetails(string calldata subscriptionId)
        external
        view
        returns (Subscription memory)
    {
        return subscriptions[subscriptionId];
    }

    function _transferXdai(address _receiver, uint256 _amount) internal {
        payable(_receiver).transfer(_amount);
    }

    function _transferXGT(
        address _sender,
        address _receiver,
        uint256 _amount
    ) internal {
        require(
            xgt.transferFrom(_sender, _receiver, _amount),
            "Token transfer failed."
        );
    }
}
