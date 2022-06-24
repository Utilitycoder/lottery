const networkConfig = {
    31337: {
        name: "localhost",
    },
    // Price Feed Address, values can be obtained at https://docs.chain.link/docs/reference-contracts
    // Default one is ETH/USD contract on Kovan
    42: {
        name: "kovan",
        ethUsdPriceFeed: "0x9326BFA02ADD2366b30bacB125260Af641031331",
    },
    4: {
        name: "rinkeby",
        vrfCoordinatorV2: "0x6168499c0cffcacd319c818142124b7a15e857ab",
    },
}

// Create a variable for local development
const developmentChains = ["hardhat", "localhost"]

// Export the two variables
module.exports = {
    networkConfig,
    developmentChains,
}