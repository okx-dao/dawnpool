# DawnPool Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

slither install：（option）Solidity static analysis framework.

please see https://github.com/crytic/slither.

Slither requires Python 3.8+. If you're not going to use one of the supported compilation frameworks, you need solc, the Solidity compiler; we recommend using solc-select to conveniently switch between solc versions.

npm install -g solc

npm install -g solc-cli

pip3 install solc-select

pip3 install slither-analyzer

Slither Run : yarn slither

## Development

You would have to define the `initialize` function for the contracts that don't have it when deploying for the first time.

1. Install dependencies:

   ```shell script
   yarn install
   ```
2. Compile optimized contracts: ( default --optimizer )

   ```shell script
   yarn compile
   ```
   
3. Update network parameters in `hardhat.config.js`. Learn more at [Hardhat config options](https://hardhat.org/config/).  

4. Deploy DawnPool contracts to the selected network:

   Copy [example.env](example.env) to .env file
   config .env var: NETWORK_URL and NETWORK_API_KEY
   replace hardhat.config.js file goerli -> accounts -> mnemonic
   
   ```shell script
   yarn deploy-contracts --network goerli
   ```
   
### License

The project is [GNU AGPL v3](./LICENSE).
