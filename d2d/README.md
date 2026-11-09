# D2D (Dust to Dealership)

A Roblox car-collecting tycoon. Open containers, wash the cars, roll engines, and fill your showroom so customers pay you.

## Open it
Open `build/D2D.rbxlx` in Roblox Studio (File → Open from File) and press **Play**.

To rebuild after editing the scripts:
```
python3 tools/build_place.py d2d D2D.rbxlx
```

## Layout
- `src/shared` → ReplicatedStorage.Shared: `Config` (all numbers, cars, odds) and `CarBuilder` (placeholder part-built cars and containers)
- `src/server` → ServerScriptService.Server: `GameServer`, `MapBuilder` (6 plots built at runtime), `DataService` (saving)
- `src/client` → StarterPlayerScripts: `Client` (HUD, truck timer, scrubbing, engine screen, Index)

## Notes
- Saving needs the place published with API access to DataStores turned on (Game Settings → Security).
- Cars are placeholders; they will be replaced with models made with Roblox's AI tools.
- All cars are original. No real brands or logos.
