# ⏳ TimeLock Vault

A highly secure, gas-optimized Ethereum smart contract vault. This protocol allows users to deposit ETH with a mandatory 7-day time lock, featuring advanced weighted-average accounting, early withdrawal penalties, and a time-delayed, two-step emergency withdrawal system for the owner.

## 🚀 Key Features

* ⚖️ **Weighted Average Accounting:** Instead of unfairly resetting a user's lock timer on subsequent deposits, the contract calculates a precise weighted average timestamp based on the existing balance and new deposit amount.
* 🧻 **"Paper Hands" Early Withdrawal:** Users can bypass the 7-day lock by calling `withdrawEarly()`, which returns 80% of their deposit and retains a 20% penalty fee within the protocol. Safe from integer division truncation.
* 🛡️ **Two-Step Emergency Action:** Owner emergency withdrawals require a 24-hour timelock between the request and execution, preventing malicious front-running. The owner also has a panic-cancel function.
* ⛽ **Gas Optimized:** Extensively utilizes `memory` structs for read/writes to avoid expensive `SLOAD`/`SSTORE` operations, and leverages `delete` for maximum gas refunds during withdrawals.
* 🔒 **Reentrancy Safe:** Strictly adheres to the Checks-Effects-Interactions (CEI) pattern across all state-changing functions.


### Why weighted timestamp?

* Weighted timestamp refers to calculation of new virtual timestamp of deposit according to the weightage of deposit amounts
* Weighted timestamp is better option because weighted timestamp make sure user's timestamp doesn't get reset to new deposit timestamp, which can lead to unlock of tokens after 7 days from new deposit timestamp, even if the old locked deposit was left 1 day  to withdraw

..........................................................

*Example:*



***Day 1:** You deposit **100 tokens**. Your weighted timestamp is Day 1. You can withdraw on **Day 8**.*
**

***Day 4:** You decide to deposit another **100 tokens**.Since the new 100 tokens have 0 age and the old 100 tokens have 3 days of age, the "average age" is now 1.5 days.Your new weighted timestamp (**\$T\_{new}\$**) shifts to **Day 2.5**.Your new withdrawal date becomes **Day 9.5** (Day 2.5 + 7 days).**

................................................


## 🗃️ Installation

### Prerequisites
Ensure you have [Foundry](https://book.getfoundry.sh/) installed on your machine.

Clone the repository and install dependencies:
```bash
git clone [https://github.com/YOUR_USERNAME/timelock-vault.git](https://github.com/YOUR_USERNAME/timelock-vault.git)
cd timelock-vault
forge install 
```




## 🧪 Testing
This vault is heavily tested using Foundry's forge-std library, including extensive Fuzz Testing to ensure mathematical precision and overflow protection across millions of randomized inputs.

Run the test suite: 


```Bash
forge test
```

To view the gas optimization report:


```bash
forge test --gas-report
```
## ⚠️ Security Disclaimer
This codebase is provided for educational and portfolio purposes. While it implements strict security patterns and fuzz testing, it has not undergone a formal, paid security audit. Use at your own risk.

👤 Author
Anuj * Aspiring Web3 Developer.

# TimeLock
# TimeLock
# TimeLock
