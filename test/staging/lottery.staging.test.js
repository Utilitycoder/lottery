const { assert, expect } = require("chai")
const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

// Run if we're not on a development chain
developmentChains.includes(network.name)
    ? describe.skip
    : describe("Lottery", async () => {
          let lottery, deployer, entranceFee

          beforeEach(async () => {
              deployer = (await getNamedAccounts()).deployer
              lottery = await ethers.getContract("Lottery", deployer)
              entranceFee = await lottery.getEntranceFee()
          })
          describe("fulfill Random Words", () => {
              it("works with  live ChainLink kepper and VRF, and pick a winner", async () => {
                  const startingTimestamp = await lottery.getLatestTimeStamp()
                  const accounts = ethers.getSigners()

                  // Setup a listener
                  await new Promise(async (resolve, reject) => {
                      lottery.once("recentWinner", async () => {
                          console.log("Somebody Won!")

                          try {
                              const recentWinner = await lottery.getRecentWinner()
                              const lotteryState = await lottery.getLotteryState()
                              const endingTimestamp = await lottery.getLatestTimeStamp()
                              const numOfPlayers = await lottery.getNumOfPlayers()
                              const winnerEndingBalance = await accounts[0].getBalance()

                              await expect(lottery.getPlayer(0)).to.be.reverted
                              assert.equal(recentWinner.toString(), accounts[0].address)
                              assert.equal(lotteryState, 0)
                              assert
                                  .equal(
                                      winnerEndingBalance.toString(),
                                      winnerStartingBalance.add(entranceFee)
                                  )
                                  .toString()
                              assert(endingTimestamp > startingTimestamp)
                              resolve()
                          } catch (e) {
                              reject(e)
                          }
                          
                      })
                      await lottery.enterLottery({ value: entranceFee })
                      const winnerStartingBalance = await accounts[0].getBalance()
                  })
              })
          })
      })
