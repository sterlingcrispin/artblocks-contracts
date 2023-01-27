import { constants, expectRevert } from "@openzeppelin/test-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";

import EthersAdapter from "@gnosis.pm/safe-ethers-lib";
import Safe from "@gnosis.pm/safe-core-sdk";
import { SafeTransactionDataPartial } from "@gnosis.pm/safe-core-sdk-types";
import { getGnosisSafe } from "../../util/GnosisSafeNetwork";
import { isCoreV3, deployAndGet } from "../../util/common";

/**
 * These tests are intended to check common MinterSetPriceV4 functionality.
 * The tests are intended to be run on the any MinterSetPriceV4 contract (not other version contracts).
 * (this includes V2ERC20 contracts)
 * @dev assumes common BeforeEach to populate accounts, constants, and setup
 */
export const MinterSetPriceV4_Common = async () => {
  describe("purchase_H4M", async function () {
    it("allows `purchase_H4M` by default", async function () {
      await this.minter
        .connect(this.accounts.user)
        .purchase_H4M(this.projectZero, {
          value: this.pricePerTokenInWei,
        });
    });

    describe("payment splitting", async function () {
      beforeEach(async function () {
        this.deadReceiver = await deployAndGet.call(
          this,
          "DeadReceiverMock",
          []
        );
      });

      it("requires successful payment to render provider", async function () {
        // update render provider address to a contract that reverts on receive
        // call appropriate core function to update render provider address
        if (this.isEngine) {
          await this.genArt721Core
            .connect(this.accounts.deployer)
            .updateProviderSalesAddresses(
              this.deadReceiver.address,
              this.accounts.additional.address,
              this.accounts.artist2.address,
              this.accounts.additional2.address
            );
        } else {
          await this.genArt721Core
            .connect(this.accounts.deployer)
            .updateArtblocksPrimarySalesAddress(this.deadReceiver.address);
        }
        // expect revert when trying to purchase
        await expectRevert(
          this.minter.connect(this.accounts.user).purchase(this.projectZero, {
            value: this.pricePerTokenInWei,
          }),
          "Render Provider payment failed"
        );
      });
      it("requires successful payment to platform provider", async function () {
        // update render provider address to a contract that reverts on receive
        // only relevant for engine core contracts
        if (this.isEngine) {
          await this.genArt721Core
            .connect(this.accounts.deployer)
            .updateProviderSalesAddresses(
              this.accounts.artist.address,
              this.accounts.additional.address,
              this.deadReceiver.address,
              this.accounts.additional2.address
            );
          await expectRevert(
            this.minter
              .connect(this.accounts.user)
              .purchaseTo(this.accounts.additional.address, this.projectZero, {
                value: this.pricePerTokenInWei,
              }),
            "Platform Provider payment failed"
          );
        } else {
          // @dev no-op for non-engine contracts
        }
      });

      it("requires successful payment to artist", async function () {
        // update artist address to a contract that reverts on receive
        await this.genArt721Core
          .connect(this.accounts.deployer)
          .updateProjectArtistAddress(
            this.projectZero,
            this.deadReceiver.address
          );
        // expect revert when trying to purchase
        await expectRevert(
          this.minter.connect(this.accounts.user).purchase(this.projectZero, {
            value: this.pricePerTokenInWei,
          }),
          "Artist payment failed"
        );
      });

      it("requires successful payment to artist additional payee", async function () {
        // update artist additional payee to a contract that reverts on receive
        const proposedAddressesAndSplits = [
          this.projectZero,
          this.accounts.artist.address,
          this.deadReceiver.address,
          // @dev 50% to additional, 50% to artist, to ensure additional is paid
          50,
          this.accounts.additional2.address,
          // @dev split for secondary sales doesn't matter for this test
          50,
        ];
        await this.genArt721Core
          .connect(this.accounts.artist)
          .proposeArtistPaymentAddressesAndSplits(
            ...proposedAddressesAndSplits
          );
        await this.genArt721Core
          .connect(this.accounts.deployer)
          .adminAcceptArtistAddressesAndSplits(...proposedAddressesAndSplits);
        // expect revert when trying to purchase
        await expectRevert(
          this.minter.connect(this.accounts.user).purchase(this.projectZero, {
            value: this.pricePerTokenInWei,
          }),
          "Additional Payee payment failed"
        );
      });

      it("handles zero platform and artist payment values", async function () {
        // update platform to zero percent
        // route to appropriate core function
        if (this.isEngine) {
          await this.genArt721Core
            .connect(this.accounts.deployer)
            .updateProviderPrimarySalesPercentages(0, 0);
        } else {
          await this.genArt721Core
            .connect(this.accounts.deployer)
            .updateArtblocksPrimarySalesPercentage(0);
        }
        // update artist primary split to zero
        const proposedAddressesAndSplits = [
          this.projectZero,
          this.accounts.artist.address,
          this.accounts.additional.address,
          // @dev 100% to additional, 0% to artist, to induce zero artist payment
          100,
          this.accounts.additional2.address,
          // @dev split for secondary sales doesn't matter for this test
          50,
        ];
        await this.genArt721Core
          .connect(this.accounts.artist)
          .proposeArtistPaymentAddressesAndSplits(
            ...proposedAddressesAndSplits
          );
        await this.genArt721Core
          .connect(this.accounts.deployer)
          .adminAcceptArtistAddressesAndSplits(...proposedAddressesAndSplits);
        // expect successful purchase
        await this.minter
          .connect(this.accounts.user)
          .purchase(this.projectZero, {
            value: this.pricePerTokenInWei,
          });
      });
    });
  });

  describe("additional payee payments", async function () {
    it("handles additional payee payments", async function () {
      const valuesToUpdateTo = [
        this.projectZero,
        this.accounts.artist2.address,
        this.accounts.additional.address,
        50,
        this.accounts.additional2.address,
        51,
      ];
      await this.genArt721Core
        .connect(this.accounts.artist)
        .proposeArtistPaymentAddressesAndSplits(...valuesToUpdateTo);
      await this.genArt721Core
        .connect(this.accounts.deployer)
        .adminAcceptArtistAddressesAndSplits(...valuesToUpdateTo);

      await this.minter.connect(this.accounts.user).purchase(this.projectZero, {
        value: this.pricePerTokenInWei,
      });
    });
  });
};