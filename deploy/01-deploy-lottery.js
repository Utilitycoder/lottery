const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")

module.exports = async ({getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const {deployer} = await getNamedAccounts()

    if(developmentChains.includes(network.name)) {
        
    }

    const lottery = await deploy("Lottery", {
        from: deployer,
        args: [],
        log: true, 
        waitConfirmations: network.config.blockConfirmations || 1,

    })
}