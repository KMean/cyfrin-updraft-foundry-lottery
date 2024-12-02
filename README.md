# Foundry Lottery

A decentralized lottery smart contract built with Foundry, following [Cyfrin Updrafts](https://www.cyfrin.io/updraft) course. This project demonstrates how to create a secure and efficient lottery system on the Ethereum blockchain using Chainlink VRF for randomness.

---

## Features

- **Decentralized Lottery System**: Secure and transparent entry process.
- **Random Winner Selection**: Uses Chainlink VRF for unbiased randomness.
- **Automation**: Employs Chainlink Automation for periodic upkeep and lottery resets.
- **Customizable**: Adjustable lottery parameters like entry fee and duration.

---

## Prerequisites

Before you begin, ensure you have the following installed:

- [Foundry](https://getfoundry.sh/)
- [Node.js](https://nodejs.org/) and npm
- A blockchain wallet (e.g., MetaMask)
- Access to a testnet like Sepolia or Polygon Amoy

---

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/KMean/foundry-lottery.git
   cd foundry-lottery
   ```

2. Install Dependencies
    ```bash
    forge install
    ```
3. Set up environment variables: Create a .env file with the following:
    ```env
    SEPOLIA_RPC_URL=your-sepolia-rpc-url
    AMOY_RPC_URL=your-amoy-rpc-url
    ```
4. Compile Contracts:
    ```bash
    forge build
    ```
5. Create an account with cast
    ```bash
    cast wallet import your-account-name --interactive
    Enter private key:
    Enter password:
    `your-account-name` keystore was saved successfully. Address: address-corresponding-to-private-key
    ```
## Deployment
To deploy the contract on Sepolia, run:
```bash
forge script script/DeployRaffle.s.sol --rpc-url $SEPOLIA_RPC_URL --account your-account-name --broadcast
```

## Testing 
Run unit tests to ensure everything is working:
```bash
forge test
```

For coverage:
```bash
forge coverage
```

## Usage
1. Enter the Lottery: Users can enter by sending the required entry fee to the contract.

2. Automated Winner Selection: The lottery uses Chainlink Automation to trigger the winner selection when the interval time has passed.

3. Winner Selection: The winner is selected using Chainlink VRF and receives the full lottery balance.


## Acknowledgments
[Cyfrin Updrafts](https://www.cyfrin.io/updraft): For providing great courses and comprehensive course materials.
[Foundry](https://github.com/foundry-rs/foundry): For the robust development framework.
[Chainlink](https://chain.link/): For secure randomness and automation.
[Alchemy](https://www.alchemy.com/): For providing excellent node-as-a-service for testing.
## License
This project is licensed under the MIT License. 
