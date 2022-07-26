import { constants, expectRevert } from "@openzeppelin/test-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import { ONE_MINUTE, ONE_HOUR, ONE_DAY } from "../../../util/constants";

import { Minter_Common } from "../../Minter.common";

/**
 * These tests are intended to check common DAExp functionality.
 * @dev assumes common BeforeEach to populate accounts, constants, and setup
 */
export const MinterDAExp_Common = async () => {
  describe("common minter tests", async () => {
    Minter_Common();
  });

  describe("purchase", async function () {
    it("disallows purchase before auction begins", async function () {
      await ethers.provider.send("evm_mine", [this.startTime + ONE_HOUR / 2]);
      await expectRevert(
        this.minter.connect(this.accounts.user).purchase(this.projectZero, {
          value: this.startingPrice.toString(),
          gasPrice: 0,
        }),
        "Auction not yet started"
      );
    });

    it("calculates the price correctly", async function () {
      for (let i = 1; i <= 5; i++) {
        let ownerBalance = await this.accounts.user.getBalance();
        let price = this.startingPrice;
        for (let j = 0; j < i; j++) {
          price = price.div(2);
        }

        await ethers.provider.send("evm_setNextBlockTimestamp", [
          this.startTime +
            this.auctionStartTimeOffset +
            i * this.defaultHalfLife,
        ]);
        await this.minter
          .connect(this.accounts.user)
          .purchase(this.projectZero, {
            value: price.toString(),
            gasPrice: 0,
          });
        // Test that price isn't too low

        await expectRevert(
          this.minter.connect(this.accounts.user).purchase(this.projectZero, {
            value: ((price.toBigInt() * BigInt(100)) / BigInt(101)).toString(),
            gasPrice: 0,
          }),
          "Must send minimum value to mint!"
        );
        let ownerDelta = (await this.accounts.user.getBalance()).sub(
          ownerBalance
        );
        expect(ownerDelta.mul("-1").lte(price)).to.be.true;
      }
    });

    it("calculates the price before correctly", async function () {
      await this.minter
        .connect(this.accounts.deployer)
        .resetAuctionDetails(this.projectZero);
      await this.minter
        .connect(this.accounts.artist)
        .setAuctionDetails(
          this.projectZero,
          this.startTime + this.auctionStartTimeOffset,
          this.defaultHalfLife,
          this.startingPrice,
          this.basePrice
        );

      let contractPriceInfo = await this.minter
        .connect(this.accounts.user)
        .getPriceInfo(this.projectZero);
      expect(contractPriceInfo.tokenPriceInWei).to.be.equal(this.startingPrice);
    });

    it("calculates the price after correctly ", async function () {
      await this.minter
        .connect(this.accounts.deployer)
        .resetAuctionDetails(this.projectZero);
      await this.minter
        .connect(this.accounts.artist)
        .setAuctionDetails(
          this.projectZero,
          this.startTime + this.auctionStartTimeOffset,
          this.defaultHalfLife,
          this.startingPrice,
          this.basePrice
        );

      await ethers.provider.send("evm_mine", [this.startTime + 5 * ONE_HOUR]);

      let contractPriceInfo = await this.minter
        .connect(this.accounts.user)
        .getPriceInfo(this.projectZero);
      expect(contractPriceInfo.tokenPriceInWei).to.be.equal(this.basePrice);
    });
  });

  describe("setAuctionDetails", async function () {
    it("cannot be modified mid-auction", async function () {
      await ethers.provider.send("evm_mine", [
        this.startTime + 2 * this.auctionStartTimeOffset,
      ]);
      await expectRevert(
        this.minter
          .connect(this.accounts.artist)
          .setAuctionDetails(
            this.projectZero,
            this.startTime + this.auctionStartTimeOffset,
            this.defaultHalfLife,
            this.startingPrice,
            this.basePrice
          ),
        "No modifications mid-auction"
      );
    });

    it("allows artist to set auction details", async function () {
      await this.minter
        .connect(this.accounts.deployer)
        .resetAuctionDetails(this.projectZero);
      await this.minter
        .connect(this.accounts.artist)
        .setAuctionDetails(
          this.projectZero,
          this.startTime + this.auctionStartTimeOffset,
          this.defaultHalfLife,
          this.startingPrice,
          this.basePrice
        );
    });

    it("disallows whitelisted and non-artist to set auction details", async function () {
      await this.minter
        .connect(this.accounts.deployer)
        .resetAuctionDetails(this.projectZero);
      await expectRevert(
        this.minter
          .connect(this.accounts.additional)
          .setAuctionDetails(
            this.projectZero,
            this.startTime + this.auctionStartTimeOffset,
            this.defaultHalfLife,
            this.startingPrice,
            this.basePrice
          ),
        "Only Artist"
      );

      await this.minter
        .connect(this.accounts.deployer)
        .resetAuctionDetails(this.projectZero);
      await expectRevert(
        this.minter
          .connect(this.accounts.deployer)
          .setAuctionDetails(
            this.projectZero,
            this.startTime + this.auctionStartTimeOffset,
            this.defaultHalfLife,
            this.startingPrice,
            this.basePrice
          ),
        "Only Artist"
      );
    });

    it("disallows higher resting price than starting price", async function () {
      await this.minter
        .connect(this.accounts.deployer)
        .resetAuctionDetails(this.projectZero);
      await expectRevert(
        this.minter
          .connect(this.accounts.artist)
          .setAuctionDetails(
            this.projectZero,
            this.startTime + this.auctionStartTimeOffset,
            this.defaultHalfLife,
            this.basePrice,
            this.startingPrice
          ),
        "Auction start price must be greater than auction end price"
      );
    });
  });

  describe("resetAuctionDetails", async function () {
    it("allows whitelisted to reset auction details", async function () {
      await expect(
        this.minter
          .connect(this.accounts.deployer)
          .resetAuctionDetails(this.projectZero)
      )
        .to.emit(this.minter, "ResetAuctionDetails")
        .withArgs(this.projectZero);
    });

    it("disallows artist to reset auction details", async function () {
      await expectRevert(
        this.minter
          .connect(this.accounts.artist)
          .resetAuctionDetails(this.projectZero),
        "Only Core whitelisted"
      );
    });

    it("disallows non-whitelisted non-artist to reset auction details", async function () {
      await expectRevert(
        this.minter
          .connect(this.accounts.additional)
          .resetAuctionDetails(this.projectZero),
        "Only Core whitelisted"
      );
    });

    it("invalidates unpaused, ongoing auction (prevents price of zero)", async function () {
      // prove this.projectZero is mintable
      await ethers.provider.send("evm_mine", [
        this.startTime + this.auctionStartTimeOffset,
      ]);
      await this.minter.connect(this.accounts.user).purchase(this.projectZero, {
        value: this.startingPrice,
      });
      // resetAuctionDetails for this.projectZero
      await this.minter
        .connect(this.accounts.deployer)
        .resetAuctionDetails(this.projectZero);
      // prove this.projectZero is no longer mintable
      await expectRevert(
        this.minter.connect(this.accounts.user).purchase(this.projectZero, {
          value: this.startingPrice,
        }),
        "Only configured auctions"
      );
      // prove this.projectZero is no longer mintable with zero value
      // (always true given prior check, but paranoid so adding test)
      await expectRevert(
        this.minter.connect(this.accounts.user).purchase(this.projectZero),
        "Only configured auctions"
      );
    });
  });

  describe("enforce and broadcasts auction half-life", async function () {
    it("enforces half-life min/max constraint", async function () {
      await this.minter
        .connect(this.accounts.deployer)
        .resetAuctionDetails(this.projectZero);
      // expect revert when creating a new project with
      const invalidHalfLifeSecondsMin = ONE_MINUTE;
      await expectRevert(
        this.minter
          .connect(this.accounts.artist)
          .setAuctionDetails(
            this.projectZero,
            this.startTime + this.auctionStartTimeOffset,
            invalidHalfLifeSecondsMin,
            this.startingPrice,
            this.basePrice
          ),
        "Price decay half life must fall between min and max allowable values"
      );

      // expect revert when creating a new project with
      const invalidHalfLifeSecondsMax = ONE_DAY;
      await expectRevert(
        this.minter
          .connect(this.accounts.artist)
          .setAuctionDetails(
            this.projectZero,
            this.startTime + this.auctionStartTimeOffset,
            invalidHalfLifeSecondsMax,
            this.startingPrice,
            this.basePrice
          ),
        "Price decay half life must fall between min and max allowable values"
      );
    });

    it("emits event when allowable half life range is updated", async function () {
      const newMinSeconds = 60;
      const newMaxSeconds = 6000;
      // emits event when allowable half life range is updated
      await expect(
        this.minter
          .connect(this.accounts.deployer)
          .setAllowablePriceDecayHalfLifeRangeSeconds(
            newMinSeconds,
            newMaxSeconds
          )
      )
        .to.emit(this.minter, "AuctionHalfLifeRangeSecondsUpdated")
        .withArgs(newMinSeconds, newMaxSeconds);
    });

    it("validate setAllowablePriceDecayHalfLifeRangeSeconds guards", async function () {
      await expectRevert(
        this.minter
          .connect(this.accounts.deployer)
          .setAllowablePriceDecayHalfLifeRangeSeconds(600, 60),
        "Maximum half life must be greater than minimum"
      );
      await expectRevert(
        this.minter
          .connect(this.accounts.deployer)
          .setAllowablePriceDecayHalfLifeRangeSeconds(0, 600),
        "Half life of zero not allowed"
      );
    });

    it("validate setAllowablePriceDecayHalfLifeRangeSeconds ACL", async function () {
      await expectRevert(
        this.minter
          .connect(this.accounts.additional)
          .setAllowablePriceDecayHalfLifeRangeSeconds(60, 600),
        "Only Core whitelisted"
      );
    });
  });
};