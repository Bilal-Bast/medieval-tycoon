# Eight-player world layout

The world supports eight independent kingdom plots. Each plot stays at its full 480 × 480 studs. They form a compact 3 × 3 ring around the shared civic plaza, with the center cell left open and 20-stud gaps between neighboring plots. Eight paved royal roads connect the plaza directly to each gate; the farthest gates are about 565 studs from the plaza center, down from roughly 1,220 studs in the previous layout. The ground and landscape boundary are sized around the compact map.

The central plaza has a small blue-water royal fountain, colorful lanterns matched to the eight realm banners, and a warm sunset color grade. Eight flowered groves soften the transition between the kingdom ring and the hills. A dismissible first-steps panel explains how to claim a kingdom and follow its next-upgrade trail. Zombie defeats award 40 gold and increment the server leaderboard; the upgrade-derived Prosperity score is also shown there.

`tools/generate_kingdom_layout.py` rebuilds the eight plot folders, their rotated roads and production corridors, the world floor, the landscape boundary, and the plaza approach roads. Run it from the repository root after changing the master layout. `tools/validate_phase41.py` checks all eight plot transforms, routes, gates, roads, and world bounds.

## Set the published server capacity

Roblox stores a place's maximum player count in that place's Creator Dashboard settings; Rojo cannot set it in this source tree. Set **Max Players** to **8** for the start place before publishing. Keep eight plot folders and eight entries in `Config.PlotOffsets` so every allowed player has a claimable kingdom.

## Royal armory

Each kingdom has its own armory beside the barracks. The plot owner can buy each weapon once with their Cash; purchases are checked on the server and the weapons return to the player's inventory after respawning in the current server.

| Weapon | Price | Attack |
| --- | ---: | --- |
| Knight's Sword | 350 gold | Close-range steel blade |
| Force Laser | 1,800 gold | Long-range ray with damage and knockback |
| Plasma Sword | 5,000 gold | Close-range energized blade |

Player-versus-player damage is enabled outside a player's own kingdom. Each kingdom is a safe area, and the weapon service only damages player characters. Weapon ownership is session-only, consistent with the current Cash setup; it is not saved after leaving the server.

## Studio test

1. Build the place with the repository's pinned Rojo version and open the resulting `.rbxl` in Studio.
2. In **Test**, start a local server with eight players.
3. Claim each of the eight kingdoms. Confirm each player receives a different plot and is spawned at that plot after claiming.
4. Buy one production upgrade in every kingdom. Confirm resources travel to the matching collector and only that plot's owner receives the payout.
5. Claim a kingdom, buy each armory item using Cash, equip each weapon, and verify attacks work outside kingdom safe areas while players inside their own kingdom take no damage.
6. Upgrade one kingdom through later stages. Check that NPC counts match visible workers, guidance targets the next pad, and the eight-road hub remains clear.
7. Leave and rejoin with one test client. Confirm its plot releases cleanly and can be claimed again.
8. Check client frame rate and server heartbeat at the busiest state. Eight fully upgraded plot environments and their Level IV models contain about 12,968 BaseParts before the hub, outer landscape, NPCs, characters, production blocks, armories, and purchase pads. Run a real eight-client performance pass before publishing.
