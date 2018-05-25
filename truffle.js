// npm install truffle-hdwallet-provider
const HDWalletProvider = require("truffle-hdwallet-provider");

module.exports = {
	networks: {
		development: {
			provider: new HDWalletProvider(
				"12 mimic words",
				"https://rinkeby.infura.io/***key***"
			),
			network_id: "*", // Match any network (determined by provider)
			gas: 7000000,
			gasPrice: 20000000000 // 20 GWei
		},
		// https://www.npmjs.com/package/solidity-coverage
		coverage: {
			host: "localhost",
			network_id: "*",
			port: 8555,
			gas: 0xfffffffffff,
			gasPrice: 1
		},
		test: {
			host: "localhost",
			network_id: "*",
			port: 8666,
			gas: 7000000,
			gasPrice: 1
		}
	},
	mocha: {
		enableTimeouts: false
	},
/*
	solc: {
		optimizer: {
			enabled: true,
			runs: 200 // default is 200, however for function execution the effect is noticeable up to 20000
		}
	}
*/
};
