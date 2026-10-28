# Roblox shop setup

The Royal Shop sells digital items through Roblox's in-experience Robux checkout. The place file contains the shop UI and server receipt logic, but its catalog IDs start at `0`, so the purchase buttons stay disabled until the items exist in the Creator Dashboard.

## Create the catalog items

1. Publish the experience and open its Creator Dashboard page.
2. Under **Monetization**, create three Developer Products: Gold Pouch, Gold Chest, and Gold Vault.
3. Create two Passes: Prosperity Pass and Royal Style.
4. Copy each numeric asset ID into the matching `Id` field in `src/ReplicatedStorage/ShopConfig.luau`.
5. Build/import the place and test purchases with Roblox's supported test-purchase workflow before enabling the experience for players.

Gold packs grant 250, 1,000, or 3,000 Cash. Cash is persisted, and the server stores each Roblox receipt ID with the balance before acknowledging that receipt, so a retried receipt cannot grant the pack twice. Prosperity Pass doubles production payouts. Royal Style adds a gold outline and title. Pass ownership is checked by the server.

The menu fetches current Robux prices from Roblox at runtime. Do not add credit-card fields or an external payment link for these digital game benefits: Roblox checkout handles the purchase. Physical merchandise is a separate Commerce setup and is not part of this digital shop.

## Before release

- Confirm all five IDs are nonzero and belong to this experience.
- Check the listed Robux prices in the live menu and set fair prices in Creator Dashboard.
- Test first-time and duplicate Developer Product receipts, reconnecting after purchase, both passes, and the shop on mobile.
- Review Roblox's current [Developer Product](https://create.roblox.com/docs/production/monetization/developer-products) and [Pass](https://create.roblox.com/docs/production/monetization/passes) documentation before publishing changes to monetization.
