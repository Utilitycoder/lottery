const { assert, expect } = require("chai")
const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Lottery", async () => {
          let lottery, vrfCoordinatorV2Mock, deployer, entranceFee, interval

          beforeEach(async () => {
              deployer = (await getNamedAccounts()).deployer
              await deployments.fixture(["all"])
              lottery = await ethers.getContract("Lottery", deployer)
              vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock", deployer)
              entranceFee = await lottery.getEntranceFee()
              interval = await lottery.getInterval()
          })
          // Async keyword is not required for describe blocks
          describe("constructor", () => {
              it("initializes the lottery correctly", async () => {
                  const lotteryState = await lottery.getLotteryState()
                  assert.equal(lotteryState.toString(), "0")
                  assert.equal(interval.toString(), "30")
              })
          })

          describe("enterLottery", () => {
              it("reverts if you don't pay enough", async () => {
                  await expect(
                      lottery.enterLottery({ value: ethers.utils.parseEther("0.01") })
                  ).to.be.revertedWith("Lottery__sendMoreEth()")
              })
              it("records player when they enter", async () => {
                  const play = await lottery.enterLottery({ value: entranceFee })
                  const player = await lottery.getPlayer(0)
                  expect(player).to.equal(deployer)
              })
              //   Test if the contract emits an event as it should.
              it("Emits event when a player enters", async () => {
                  await expect(lottery.enterLottery({ value: entranceFee })).to.emit(
                      lottery,
                      "newPlayer"
                  )
              })
              it("Deny new playes when raffle is calculating", async () => {
                  await lottery.enterLottery({ value: entranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.send("evm_mine", [])
                  // pretend to be chainlink keeper
                  await lottery.performUpkeep([])
                  await expect(lottery.enterLottery({ value: entranceFee })).to.be.revertedWith(
                      "Lottery__NotAvailable()"
                  )
              })
          })
          describe("CheckUpkeep", () => {
              it("Returns false if no user has sent ETH", async () => {
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.send("evm_mine", [])
                  //callStatic simulates calling a transaction to see its response.
                  const { upkeepNeeded } = await lottery.callStatic.checkUpkeep([])
                  assert(!upkeepNeeded)
              })
              it("Returns false if Lottery is not Open", async () => {
                  await lottery.enterLottery({ value: entranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.send("evm_mine", [])
                  await lottery.performUpkeep([])
                  const lotteryState = await lottery.getLotteryState()
                  const { upkeepNeeded } = await lottery.callStatic.checkUpkeep([])
                  assert.equal(lotteryState.toString(), "1")
                  assert.equal(upkeepNeeded, false)
              })
              it("Returns false if enough Time hasn't passed", async () => {
                  await lottery.enterLottery({ value: entranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() - 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  const { upkeepNeeded } = await lottery.callStatic.checkUpkeep("0x")
                  assert(!upkeepNeeded)
              })
              it("Returns true if enough time has passed, ETH, has players and isOpen", async () => {
                  await lottery.enterLottery({ value: entranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  const { upkeepNeeded } = await lottery.callStatic.checkUpkeep("0x")
                  assert(upkeepNeeded)
              })
          })
          describe("PerformUpkeep", () => {
              // Found a way not to run before each for each unit test
              //   let executeBeforeEach = true
              //   if (executeBeforeEach) {
              //       beforeEach(async () => {
              //           await lottery.enterLottery({ value: entranceFee })
              //           await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
              //           await network.provider.request({ method: "evm_mine", params: [] })
              //       })
              //   }
              it("It runs if checkUpkeep is true", async () => {
                  await lottery.enterLottery({ value: entranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  const tx = await lottery.performUpkeep([])
                  assert(tx)
              })
              it("it reverts if Checkupkeep is false", async () => {
                  executeBeforeEach = false
                  await expect(lottery.performUpkeep([])).to.be.revertedWith(
                      "Lottery__UpkeepNotNeeded"
                  )
              })
              it("updates the lottery state, emits an event, and calls the vrf coordinator", async () => {
                  await lottery.enterLottery({ value: entranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  const txResponse = await lottery.performUpkeep([])
                  const txReceipt = await txResponse.wait(1)
                  const requestId = txReceipt.events[1].args.requestId
                  const lotteryState = await lottery.getLotteryState()
                  console.log(lotteryState)
                  assert(requestId.toNumber() > 0)
                  assert(lotteryState == 1)
              })
          })
          describe("fulfillRandomWords", () => {
              beforeEach(async () => {
                  await lottery.enterLottery({ value: entranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.send("evm_mine", [])
              })
              it("Can only be called after performUpkeep", async () => {
                  await expect(
                      vrfCoordinatorV2Mock.fulfillRandomWords(0, lottery.address)
                  ).to.be.revertedWith("nonexistent request")
                  await expect(
                      vrfCoordinatorV2Mock.fulfillRandomWords(1, lottery.address)
                  ).to.be.revertedWith("nonexistent request")
              })
              it("picks a winner, reset the lottery and send Ether", async () => {
                  const additionalEntrants = 3
                  const startingAccount = 1
                  const accounts = await ethers.getSigners()
                  // Loop over accounts and connects for 4 of them
                  for (let i = startingAccount; i < startingAccount + additionalEntrants; i++) {
                      const accountConnectedLottery = lottery.connect(accounts[i])
                      await accountConnectedLottery.enterLottery({ value: entranceFee })
                  }
                  const startingTimestamp = await lottery.getLatestTimeStamp()
                  // PerformUpkeep {use vrfMock as chain link keepers}
                  await new Promise(async (resolve, reject) => {
                      lottery.once("recentWinner", async () => {
                          // Print the below once we catch the event
                          console.log("Someone won!")
                          try {
                              const recentWinner = await lottery.getRecentWinner()
                              console.log(recentWinner)

                              const lotteryState = await lottery.getLotteryState()
                              const endingTimestamp = await lottery.getLatestTimeStamp()
                              const numOfPlayers = await lottery.getNumOfPlayers()
                              const winnerEndingBalance = await accounts[1].getBalance()
                              assert.equal(numOfPlayers.toString(), "0")
                              assert.equal(lotteryState.toString(), "0")
                              assert(endingTimestamp > startingTimestamp)
                              assert.equal(
                                  winnerEndingBalance.toString(),
                                  winnerStartingBalance
                                      .add(entranceFee.mul(additionalEntrants)
                                      .add(entranceFee))
                                      .toString()
                              )
                          } catch (e) {
                              reject(e)
                          }
                          resolve()
                      })
                      // Setting up the listener
                      // We will fire the event, and the listener will pick it up and resolve
                      const tx = await lottery.performUpkeep([])
                      const txReceipt = await tx.wait(1)
                      const winnerStartingBalance = await accounts[1].getBalance()
                      await vrfCoordinatorV2Mock.fulfillRandomWords(
                          txReceipt.events[1].args.requestId,
                          lottery.address
                      )
                  })
              })
          })
      })
