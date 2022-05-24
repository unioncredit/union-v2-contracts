const {ethers, upgrades, waffle} = require("hardhat");

const {expect} = require("chai");
require("chai").should();
const {signDaiPermit, signERC2612Permit} = require("eth-permit");
const {parseEther} = require("ethers").utils;
const {waitNBlocks} = require("../../utils");

const AddressZero = ethers.constants.AddressZero;

const maxOverdue = "1000";

const effectiveCount = 3;

describe("User Manager Contract", () => {
    before(async function () {
        [ADMIN, ALICE, BOB, TOM, MEMBER1, MEMBER2, MEMBER3, MEMBER4] = await ethers.getSigners();

        const AssetManager = await ethers.getContractFactory("AssetManagerMock");
        const Comptroller = await ethers.getContractFactory("ComptrollerMock");
        const ERC20 = await ethers.getContractFactory("FaucetERC20");

        const UnionToken = await ethers.getContractFactory("UnionTokenMock");
        UserManager = await ethers.getContractFactory("UserManager");
        UToken = await ethers.getContractFactory("UTokenMock");

        assetManager = await upgrades.deployProxy(AssetManager, [], {
            initializer: "__AssetManager_init()"
        });
        //name must be Dai Stablecoin, otherwise call signDaiPermit will error
        erc20 = await upgrades.deployProxy(ERC20, ["Dai Stablecoin", "DAI"], {
            initializer: "__FaucetERC20_init(string,string)"
        });
        unionToken = await UnionToken.deploy("Union Token", "unionToken");
        comptroller = await Comptroller.deploy();
        comptroller = await upgrades.deployProxy(Comptroller, [], {
            initializer: "__ComptrollerMock_init()"
        });
        //mock transfer reward
        await comptroller.setRewardsInfo(unionToken.address, 0);
        uToken = await upgrades.deployProxy(UToken, [], {
            initializer: "__UToken_init()"
        });

        const amount = parseEther("1000000");
        await erc20.mint(assetManager.address, amount);
        await erc20.mint(ADMIN.address, amount);
        await erc20.mint(MEMBER1.address, amount);
        await erc20.mint(MEMBER2.address, amount);
        await erc20.mint(MEMBER3.address, amount);
        await erc20.mint(MEMBER4.address, amount);
    });

    beforeEach(async () => {
        userManager = await upgrades.deployProxy(
            UserManager,
            [
                assetManager.address,
                unionToken.address,
                erc20.address,
                comptroller.address,
                ADMIN.address,
                maxOverdue,
                effectiveCount
            ],
            {
                initializer: "__UserManager_init(address,address,address,address,address,uint256,uint256)"
            }
        );
        await expect(userManager.setUToken(AddressZero)).to.be.reverted;
        await userManager.setUToken(uToken.address);
        await userManager.addMember(MEMBER1.address);
        await userManager.addMember(MEMBER2.address);
        await userManager.addMember(MEMBER3.address);
        await userManager.addMember(MEMBER4.address);
        await uToken.setUserManager(userManager.address);
    });

    it("Stake amount more than individual limit should revert", async () => {
        const memberFee = parseEther("0.1");
        await userManager.setNewMemberFee(memberFee);
        const maxStakeAmount = await userManager.maxStakeAmount();
        const stakeAmount = parseEther("100001");

        stakeAmount.should.be.gt(maxStakeAmount);

        await erc20.connect(MEMBER1).approve(userManager.address, stakeAmount);
        await expect(userManager.connect(MEMBER1).stake(stakeAmount)).to.be.revertedWith("StakeLimitReached()");
    });

    it("Total stake amount more than individual limit should revert even for multiple steps", async () => {
        const memberFee = parseEther("0.1");
        await userManager.setNewMemberFee(memberFee);
        const maxStakeAmount = await userManager.maxStakeAmount();
        const stakeAmount1 = parseEther("4000");
        const stakeAmount2 = parseEther("1001");
        const stakeAmount3 = parseEther("1000");

        stakeAmount1.should.be.lt(maxStakeAmount);
        stakeAmount1.add(stakeAmount2).should.be.gt(maxStakeAmount);
        stakeAmount1.add(stakeAmount3).should.be.lte(maxStakeAmount);

        await erc20.connect(MEMBER1).approve(userManager.address, stakeAmount1.add(stakeAmount2).add(stakeAmount3));

        userManager.connect(MEMBER1).stake(stakeAmount1);
        await expect(userManager.connect(MEMBER1).stake(stakeAmount2)).to.be.revertedWith("StakeLimitReached()");
        userManager.connect(MEMBER1).stake(stakeAmount3);
    });

    it("Add trust and apply for new member", async () => {
        //set member fee
        const memberFee = parseEther("0.1");
        await userManager.setNewMemberFee(memberFee);
        const fee = await userManager.newMemberFee();
        fee.toString().should.eq(memberFee.toString());
        const stakeAmount = parseEther("1000");
        const trustAmount = parseEther("500");
        let isMember = await userManager.connect(BOB).checkIsMember(BOB.address);
        isMember.should.eq(false);
        await unionToken.transfer(BOB.address, memberFee);
        await unionToken.connect(BOB).approve(userManager.address, memberFee);
        //Set up three guarantors
        await erc20.connect(MEMBER1).approve(userManager.address, stakeAmount);
        await userManager.connect(MEMBER1).stake(stakeAmount);

        await erc20.connect(MEMBER2).approve(userManager.address, stakeAmount);
        await userManager.connect(MEMBER2).stake(stakeAmount);

        await erc20.connect(MEMBER3).approve(userManager.address, stakeAmount);
        await userManager.connect(MEMBER3).stake(stakeAmount);

        //not enough effective stakers
        await userManager.connect(MEMBER1).updateTrust(BOB.address, trustAmount);
        await userManager.connect(MEMBER2).updateTrust(BOB.address, trustAmount);
        await expect(userManager.connect(BOB).registerMember(BOB.address)).to.be.revertedWith("NotEnoughStakers()");
        //balance not enough
        await userManager.connect(MEMBER3).updateTrust(BOB.address, trustAmount);
        await userManager.setNewMemberFee(parseEther("1000000000000"));
        await expect(userManager.connect(BOB).registerMember(BOB.address)).to.be.revertedWith(
            "ERC20: burn amount exceeds allowance"
        );

        //register member
        await userManager.setNewMemberFee(memberFee);
        await userManager.connect(BOB).registerMember(BOB.address);
        isMember = await userManager.checkIsMember(BOB.address);
        isMember.should.eq(true);

        //Cannot register twice
        await expect(userManager.connect(BOB).registerMember(BOB.address)).to.be.revertedWith("NoExistingMember()");
    });

    it("Add trust and apply for new member with permit", async () => {
        const memberFee = parseEther("0.1");
        await userManager.setNewMemberFee(memberFee);

        const stakeAmount = parseEther("1000");
        const trustAmount = parseEther("500");

        await unionToken.transfer(BOB.address, memberFee);

        await erc20.connect(MEMBER1).approve(userManager.address, stakeAmount);
        await userManager.connect(MEMBER1).stake(stakeAmount);
        await erc20.connect(MEMBER2).approve(userManager.address, stakeAmount);
        await userManager.connect(MEMBER2).stake(stakeAmount);
        await erc20.connect(MEMBER3).approve(userManager.address, stakeAmount);
        await userManager.connect(MEMBER3).stake(stakeAmount);

        await userManager.connect(MEMBER1).updateTrust(BOB.address, trustAmount);
        await userManager.connect(MEMBER2).updateTrust(BOB.address, trustAmount);
        await userManager.connect(MEMBER3).updateTrust(BOB.address, trustAmount);

        const result = await signERC2612Permit(
            waffle.provider._hardhatNetwork.provider,
            {
                name: "Union Token",
                chainId: "31337",
                version: "1",
                verifyingContract: unionToken.address
            },
            BOB.address,
            userManager.address,
            memberFee.toString()
        );

        await userManager
            .connect(BOB)
            .registerMemberWithPermit(BOB.address, memberFee, result.deadline, result.v, result.r, result.s);

        isMember = await userManager.checkIsMember(BOB.address);
        isMember.should.eq(true);
    });

    it("Credit limit", async () => {
        const vouchAmount1 = parseEther("1");
        const vouchAmount2 = parseEther("100");
        const vouchAmount3 = parseEther("200");
        await userManager.addMember(BOB.address);

        await erc20.connect(MEMBER1).approve(userManager.address, parseEther("10000"));
        await userManager.connect(MEMBER1).stake(parseEther("1000"));
        await erc20.connect(MEMBER2).approve(userManager.address, parseEther("10000"));
        await userManager.connect(MEMBER2).stake(parseEther("1000"));
        await erc20.connect(MEMBER3).approve(userManager.address, parseEther("10000"));
        await userManager.connect(MEMBER3).stake(parseEther("1000"));

        await userManager.connect(MEMBER1).updateTrust(BOB.address, vouchAmount1);
        await userManager.connect(MEMBER2).updateTrust(BOB.address, vouchAmount2);
        await userManager.connect(MEMBER3).updateTrust(BOB.address, vouchAmount3);

        //MEMBER1 1, MEMBER2 100, MEMBER3 200
        let creditLimit = await userManager.getCreditLimit(BOB.address);
        creditLimit.toString().should.eq(vouchAmount1.add(vouchAmount2).add(vouchAmount3).toString());

        //MEMBER1 1 MEMBER2 100, MEMBER3 200, MEMBER4 200
        await userManager.connect(MEMBER4).updateTrust(BOB.address, vouchAmount3);
        creditLimit = await userManager.getCreditLimit(BOB.address);
        creditLimit.toString().should.eq(parseEther("301").toString()); //because MEMBER4 stake amount is 0, so = 1 + 100 + 200
        await erc20.connect(MEMBER4).approve(userManager.address, parseEther("1000"));
        await userManager.connect(MEMBER4).stake(parseEther("1000"));
        creditLimit = await userManager.getCreditLimit(BOB.address);
        creditLimit.toString().should.eq(parseEther("501").toString());

        //MEMBER1 100, MEMBER2 100, MEMBER3 200
        await userManager.connect(MEMBER1).updateTrust(BOB.address, vouchAmount2);
        await userManager.connect(BOB).cancelVouch(MEMBER4.address, BOB.address);
        creditLimit = await userManager.getCreditLimit(BOB.address);
        creditLimit.toString().should.eq(parseEther("400").toString());

        let locked = await userManager.getLockedStake(MEMBER1.address, BOB.address);
        locked.toString().should.eq("0");
        let locked2 = await userManager.getLockedStake(MEMBER2.address, BOB.address);
        locked2.toString().should.eq("0");
        let locked3 = await userManager.getLockedStake(MEMBER3.address, BOB.address);
        locked3.toString().should.eq("0");

        await uToken.connect(BOB).borrow(creditLimit);
        locked = await userManager.getLockedStake(MEMBER1.address, BOB.address);
        locked.toString().should.eq(parseEther("100").toString());
        locked2 = await userManager.getLockedStake(MEMBER2.address, BOB.address);
        locked.toString().should.eq(parseEther("100").toString());
        locked3 = await userManager.getLockedStake(MEMBER3.address, BOB.address);
        locked.toString().should.eq(parseEther("100").toString());
    });

    it("Test member cancel connection", async () => {
        const vouchAmount1 = parseEther("1");
        const vouchAmount2 = parseEther("100");
        const vouchAmount3 = parseEther("200");
        await erc20.connect(MEMBER1).approve(userManager.address, parseEther("10000"));
        await erc20.connect(MEMBER2).approve(userManager.address, parseEther("10000"));
        await erc20.connect(MEMBER3).approve(userManager.address, parseEther("10000"));

        await userManager.connect(MEMBER1).stake(parseEther("1000"));
        await userManager.connect(MEMBER3).stake(parseEther("1000"));

        await userManager.addMember(BOB.address);
        await userManager.connect(MEMBER1).updateTrust(BOB.address, vouchAmount1);
        await userManager.connect(MEMBER2).updateTrust(BOB.address, vouchAmount2);
        await userManager.connect(MEMBER3).updateTrust(BOB.address, vouchAmount3);

        await expect(userManager.connect(BOB).cancelVouch(MEMBER1.address, ALICE.address)).to.be.revertedWith(
            "AuthFailed()"
        );

        //in order to members[staker].creditLines[token].borrowerAddresses length > 1
        await userManager.connect(MEMBER1).updateTrust(ALICE.address, 1);

        await userManager.setEffectiveCount(0);

        await userManager.connect(BOB).cancelVouch(MEMBER1.address, BOB.address);

        //test not exist branche,not duplicate code
        await userManager.connect(BOB).cancelVouch(MEMBER1.address, BOB.address);
    });

    it("Pausable and unpause", async () => {
        await userManager.pause();
        await userManager.addMember(BOB.address);
        await expect(userManager.connect(MEMBER1).updateTrust(BOB.address, 1)).to.be.revertedWith("Controller: paused");
        await userManager.unpause();
    });

    it("Total credit used", async () => {
        await userManager.connect(MEMBER1).updateTrust(BOB.address, 1);
        let totalAmount = await userManager.getTotalLockedStake(MEMBER1.address);
        totalAmount.toString().should.eq("0");
        totalAmount = await userManager.getTotalLockedStake(TOM.address);
        totalAmount.toString().should.eq("0");
    });

    xit("Total frozen amount", async () => {
        // TODO: there is a todo in User manager to fix frozen values
        await erc20.connect(MEMBER1).approve(userManager.address, parseEther("10000"));
        await erc20.connect(MEMBER2).approve(userManager.address, parseEther("10000"));
        await erc20.connect(MEMBER3).approve(userManager.address, parseEther("10000"));
        await userManager.connect(MEMBER1).stake(parseEther("1"));
        await userManager.connect(MEMBER2).stake(parseEther("1"));
        await userManager.connect(MEMBER3).stake(parseEther("1"));
        await userManager.addMember(BOB.address);
        await userManager.connect(MEMBER1).updateTrust(BOB.address, parseEther("1"));
        await userManager.connect(MEMBER2).updateTrust(BOB.address, parseEther("1"));
        await userManager.connect(MEMBER3).updateTrust(BOB.address, parseEther("1"));
        let totalAmount = await userManager.getTotalFrozenAmount(MEMBER1.address);
        totalAmount.toString().should.eq("0");

        const creditLimit = await userManager.getCreditLimit(BOB.address);
        //Simulate user loan default
        await uToken.setIsOverdue(true);
        await uToken.connect(BOB).borrow(creditLimit);
        await uToken.setBorrowed(creditLimit);
        await uToken.updateOverdueInfo(BOB.address, true);

        let totalFrozen = await userManager.totalFrozen();
        totalFrozen.toString().should.eq(creditLimit.toString());
        totalAmount = await userManager.getTotalFrozenAmount(MEMBER1.address);
        totalAmount.toString().should.eq(parseEther("1").toString());

        //Restore simulation settings
        await uToken.setIsOverdue(false);
    });

    it("Vouching amount", async () => {
        let vouchAmount = await userManager.getVouchingAmount(ADMIN.address, BOB.address);
        vouchAmount.toString().should.eq("0");

        await erc20.connect(MEMBER1).approve(userManager.address, parseEther("10000"));
        await userManager.connect(MEMBER1).stake(parseEther("1000"));

        await userManager.connect(MEMBER1).updateTrust(MEMBER3.address, parseEther("200"));

        vouchAmount = await userManager.getVouchingAmount(MEMBER1.address, MEMBER3.address);
        vouchAmount.toString().should.eq(parseEther("200").toString());

        const balance = await userManager.getStakerBalance(MEMBER2.address);

        await userManager.connect(MEMBER2).updateTrust(MEMBER3.address, parseEther("20000"));
        vouchAmount = await userManager.getVouchingAmount(MEMBER2.address, MEMBER3.address);
        vouchAmount.toString().should.eq(balance.toString());
    });

    it("Trust self", async () => {
        await expect(userManager.connect(MEMBER1).updateTrust(MEMBER1.address, 1)).to.be.revertedWith(
            "ErrorSelfVouching()"
        );
    });

    it("Trust only member", async () => {
        await expect(userManager.connect(ALICE).updateTrust(MEMBER1.address, 1)).to.be.revertedWith("AuthFailed()");
    });

    it("Trust amount cannot be less than the locked amount", async () => {
        await userManager.addMember(ADMIN.address);
        await erc20.approve(userManager.address, parseEther("10000"));
        await userManager.stake(parseEther("1000"));
        await userManager.updateTrust(BOB.address, 10);

        await uToken.connect(BOB).borrow(10);

        await expect(userManager.updateTrust(BOB.address, 1)).to.be.revertedWith("TrustAmountTooSmall()");
    });

    it("Withdraw rewards", async () => {
        const amount = parseEther("1000");
        await erc20.connect(MEMBER1).approve(userManager.address, amount);
        await userManager.connect(MEMBER1).stake(amount);
        await unionToken.transfer(comptroller.address, amount);
        //mock transfer reward
        await comptroller.setRewardsInfo(unionToken.address, amount);
        await userManager.connect(MEMBER1).withdrawRewards();
        //Restore simulation settings
        await comptroller.setRewardsInfo(unionToken.address, 0);
    });

    it("Get staker balance", async () => {
        const balance = await userManager.getStakerBalance(BOB.address);
        balance.toString().should.eq("0");
    });

    it("Stake and unstake", async () => {
        let bobBalance;
        await erc20.transfer(ALICE.address, 100);
        await erc20.connect(ALICE).approve(userManager.address, 100);
        await userManager.connect(ALICE).stake(100);
        bobBalance = await erc20.balanceOf(ALICE.address);
        bobBalance.toString().should.eq("0");
        await userManager.connect(ALICE).unstake(100);

        bobBalance = await erc20.balanceOf(ALICE.address);
        bobBalance.toString().should.eq("100");
    });

    it("Is the reward correct after stake and unstake ", async () => {
        const expectedRewardPerBlock = parseEther("0.75");
        const expectedReward = (expectedRewardPerBlock * 2).toString();
        await erc20.transfer(ALICE.address, 100);
        await erc20.connect(ALICE).approve(userManager.address, 100);
        await unionToken.transfer(comptroller.address, parseEther("100"));
        await userManager.connect(ALICE).stake(100);
        bobBalanceStart = await unionToken.balanceOf(ALICE.address);
        await waitNBlocks(1);
        //mock transfer reward
        await comptroller.setRewardsInfo(unionToken.address, expectedReward);
        await userManager.connect(ALICE).unstake(100);
        bobBalanceEnd = await unionToken.balanceOf(ALICE.address);
        bobBalanceEnd.sub(bobBalanceStart).toString().should.eq(expectedReward); //2 block
        //Restore simulation settings
        await comptroller.setRewardsInfo(unionToken.address, 0);
    });

    it("Stake: not enough allowance to repay", async () => {
        const stakeAmount = parseEther("1");
        await erc20.connect(BOB).approve(userManager.address, 0);
        await expect(userManager.connect(BOB).stake(stakeAmount)).to.be.revertedWith(
            "ERC20: transfer amount exceeds balance"
        );
    });

    it("Unstake: amount exceeded the limit", async () => {
        const stakeAmount = parseEther("1");
        await erc20.connect(MEMBER1).approve(userManager.address, stakeAmount);
        await userManager.connect(MEMBER1).stake(stakeAmount);

        await userManager.connect(MEMBER1).updateTrust(BOB.address, 10);

        await expect(userManager.connect(MEMBER1).unstake(parseEther("2000"))).to.be.revertedWith(
            "InsufficientBalance()"
        );
    });

    // TODO: this should only be a function of permit supporting uTokens
    xit("stake with permit", async () => {
        await erc20.connect(MEMBER1).approve(userManager.address, 0);
        const result = await signDaiPermit(
            waffle.provider._hardhatNetwork.provider,
            {
                name: "Dai Stablecoin",
                version: "1",
                chainId: "31337",
                verifyingContract: erc20.address
            },
            MEMBER1.address,
            userManager.address
        );
        await userManager
            .connect(MEMBER1)
            .stakeWithPermit(100, result.nonce, result.expiry, result.v, result.r, result.s);
    });

    // TODO: this should only be a function of permit supporting uTokens
    xit("stake with ERC20 permit", async () => {
        const ERC20 = await ethers.getContractFactory("FaucetERC20_ERC20Permit");
        const erc20 = await upgrades.deployProxy(ERC20, ["Dai Stablecoin", "DAI"], {
            initializer: "__FaucetERC20_ERC20Permit_init(string,string)"
        });
        await erc20.mint(MEMBER1.address, parseEther("10000"));
        userManager = await upgrades.deployProxy(
            UserManager,
            [
                assetManager.address,
                unionToken.address,
                erc20.address,
                creditLimitModel.address,
                comptroller.address,
                ADMIN.address
            ],
            {
                initializer: "__UserManager_init(address,address,address,address,address,address)"
            }
        );
        await userManager.setUToken(uToken.address);
        await userManager.addMember(MEMBER1.address);
        await userManager.addMember(MEMBER2.address);
        await userManager.addMember(MEMBER3.address);
        await userManager.addMember(MEMBER4.address);
        await erc20.connect(MEMBER1).approve(userManager.address, 0);
        const stakeAmount = 100;
        const result = await signERC2612Permit(
            waffle.provider._hardhatNetwork.provider,
            {
                name: "Dai Stablecoin",
                version: "1",
                chainId: "31337",
                verifyingContract: erc20.address
            },
            MEMBER1.address,
            userManager.address,
            stakeAmount
        );
        await userManager
            .connect(MEMBER1)
            .stakeWithERC20Permit(stakeAmount, result.deadline, result.v, result.r, result.s);
    });

    xit("Update overdue info", async () => {
        let res;
        //prevent after simulating totalFrozen data， totalStaked - totalFrozen < 0
        await erc20.connect(MEMBER1).approve(userManager.address, 1000);
        await userManager.connect(MEMBER1).stake(1000);

        await expect(userManager.connect(BOB).updateTotalFrozen(MEMBER1.address, false)).to.be.revertedWith(
            "AuthFailed()"
        );

        //isOverdue false totalFrozen <= amount
        await userManager.updateTotalFrozen(MEMBER1.address, false);
        res = await userManager.totalFrozen();
        res.toString().should.eq("0");

        //isOverdue true
        await userManager.batchUpdateTotalFrozen([MEMBER1.address], [true]);
        res = await userManager.totalFrozen();
        res.toString().should.eq("0");

        //totalFrozen add ADMIN frozen amount
        await userManager.updateTotalFrozen(ADMIN.address, true);
        res = await userManager.totalFrozen();
        res.toString().should.eq("0");

        //isOverdue false totalFrozen > amount
        await userManager.batchUpdateTotalFrozen([BOB.address], [false]);
        res = await userManager.totalFrozen();
        res.toString().should.eq("0");
    });

    xit("Debt write off", async () => {
        await erc20.connect(MEMBER1).approve(userManager.address, parseEther("10000"));
        await erc20.connect(MEMBER2).approve(userManager.address, parseEther("10000"));
        await erc20.connect(MEMBER3).approve(userManager.address, parseEther("10000"));
        await userManager.connect(MEMBER1).stake(parseEther("1"));
        await userManager.connect(MEMBER2).stake(parseEther("1"));
        await userManager.connect(MEMBER3).stake(parseEther("1"));
        await userManager.addMember(TOM.address);
        await userManager.connect(MEMBER1).updateTrust(TOM.address, parseEther("1"));
        await userManager.connect(MEMBER2).updateTrust(TOM.address, parseEther("1"));
        await userManager.connect(MEMBER3).updateTrust(TOM.address, parseEther("1"));

        const creditLimit = await userManager.getCreditLimit(TOM.address);
        //Simulate user loan default
        await uToken.setIsOverdue(true);
        await uToken.updateLockedData(TOM.address, creditLimit);
        await uToken.updateOverdueInfo(TOM.address, true);

        let stakeAmount = await userManager.stakers(MEMBER1.address);
        let lockedAmount = await userManager.getLockedStake(MEMBER1.address, TOM.address);
        stakeAmount.toString().should.eq(parseEther("1").toString());
        lockedAmount.toString().should.eq(parseEther("1").toString());

        await userManager.connect(MEMBER1).debtWriteOff(TOM.address, parseEther("1"));

        stakeAmount = await userManager.stakers(MEMBER1.address);
        lockedAmount = await userManager.getLockedStake(MEMBER1.address, TOM.address);
        stakeAmount.toString().should.eq("0");
        lockedAmount.toString().should.eq("0");

        //Restore simulation settings
        await uToken.setIsOverdue(false);
    });

    it("set max stake amount", async () => {
        const amount = parseEther("1");
        await userManager.setMaxStakeAmount(amount);
        const res = await userManager.maxStakeAmount();
        res.should.eq(amount);
        await expect(userManager.connect(MEMBER1).stake(parseEther("2"))).to.be.revertedWith("StakeLimitReached()");
    });
});
