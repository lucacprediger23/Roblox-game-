# Steal a Squishy Egg 🥚

A Roblox game where you sneak into the egg field, grab eggs, run them home past the guardians, and hatch them into squishy food creatures that earn you coins. Other players can steal your squishies, so lock your base!

## How to open it in Roblox Studio

1. Download `build/StealASquishyEgg.rbxlx`.
2. In Roblox Studio, choose **File → Open from File** and pick the file.
3. Press **Play** to test it.

The whole map (bases, egg field, nests and guardians) is built by code when the game starts, so the Workspace looks empty until you press Play.

### Before you publish

- **Game Settings → Security → Enable Studio Access to API Services**: turn this on so progress saves while testing in Studio.
- **Game Settings → Places → Max Players**: set it to **8**, because there are 8 bases.

## How the game works

| Step | What happens |
|---|---|
| Grab | Hold **E** on an egg in the field. Farther zones have rarer eggs. |
| Run | Carrying slows you down. Guardians chase anyone carrying an egg in their zone. |
| Hatch | Bring the egg into your base. It goes on a pedestal and hatches after a few seconds. |
| Earn | Squishies earn coins every second. Step on the green pad to collect. |
| Upgrade | Buy speed to reach the far zones and escape faster. |
| Steal | Hold **E** on someone else's squishy and run it home. The owner can tag you to take it back. |
| Lock | Lock your base for 30 seconds (60-second cooldown). |

### Zones

| Zone | Eggs | Guardian |
|---|---|---|
| Candy Meadow | Common, Uncommon | Chef Bear |
| Kitchen Canyon | Uncommon, Rare, Epic | Grumpy Rolling Pin |
| Starlight Bakery | Rare, Epic, Legendary, Secret | Snow Yeti |

### Squishies

| Rarity | Squishies |
|---|---|
| Common | Dumpy, Mochi Mo, Toasty |
| Uncommon | Boba Bub, Sushi Roll-y, Puddin' |
| Rare | Taco Tilly, Ramen Noodle-Bear |
| Epic | Dino-Dumpling, Cupcake Cat |
| Legendary | Starlight Mochi |
| Secret | Golden Mega Dumpling |

Mutations (rolled at hatch): Glitter ×2, Frozen ×3, Spicy ×4, Rainbow ×6.

## Changing the game

All balance numbers (prices, speeds, rarities, income, zones and squishy designs) are in `src/shared/Config.lua`.

## Project layout

```
src/shared/Config.lua           all game settings and squishy designs
src/shared/PetModels.lua        builds squishies and eggs from parts
src/server/GameServer.server.lua main game logic
src/server/MapBuilder.lua       builds the map
src/server/DataService.lua      saving and loading
src/client/HUD.client.lua       player UI and effects
tools/build_place.py            packs src/ into build/StealASquishyEgg.rbxlx
default.project.json            Rojo project (optional, for live syncing)
```

After editing files in `src/`, rebuild the place file with `python3 tools/build_place.py`.
