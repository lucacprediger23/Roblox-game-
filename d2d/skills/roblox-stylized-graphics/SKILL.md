---
name: roblox-stylized-graphics
description: Make a Roblox game look clean, bright and satisfying (Clean a Painting / top-simulator style) - lighting & sky, uncluttered layout, smooth materials, painted UI icons, per-level colour, and game-feel juice - then verify with in-Studio screenshots.
---

# Roblox stylized graphics (clean simulator look)

Use when a Roblox game looks crowded, flat, "AI-sloppy", too bright/shiny, or the user asks for
better graphics, UI, lighting, sky, assets or "make it feel satisfying". Distilled from:
TabooHarmony/roblox-brain (roblox-lighting, roblox-building, roblox-gui, roblox-animation-vfx),
gamedev-skills/awesome-gamedev-agent-skills (game-feel, game-ui-ux), opusgamelabs/game-creator
(game-designer visual catalog) and hands-on iteration on D2D.

## 0. Set up to see what players see
- Studio > File > Studio Settings > Rendering: **Editor Quality Level = Level 21**, Auto FRM Level = 21.
  (Check again after Studio updates - it can reset to Automatic.)
- Build the place from code, open it, press Play, then frame shots with the command bar (Ctrl+Enter runs):
  `local c=workspace.CurrentCamera;local h=game.Players.LocalPlayer.Character.HumanoidRootPart;c.CameraType=Enum.CameraType.Scriptable;c.CFrame=CFrame.lookAt(<eye>,<target>)`
  Reset with `CameraType=Enum.CameraType.Custom`.
- When choosing a look, render 3-5 options from the SAME camera and show a labelled contact sheet; let the user pick.

## 1. Lighting & sky (one preset module, switchable live)
Keep every look in one `LightingPresets` module with `Apply(name, skyOverride)` that rebuilds
Sky/Atmosphere/Bloom/ColorCorrection/SunRays/DepthOfField/Clouds. Tested defaults for a bright simulator:

| Setting | Value | Why |
|---|---|---|
| ClockTime / Latitude | 14 / 25 | high sun, short soft shadows |
| Brightness | 2.2-2.6 | >3 washes out |
| Exposure | -0.1..0.1 | lower if the ground glares |
| Ambient / OutdoorAmbient | ~(100,106,124) / (132,142,168) | never black; slightly cool |
| ShadowSoftness | 0.2-0.4 | |
| EnvironmentSpecularScale | 0.3 | kills plastic glare on floors |
| Atmosphere | Density 0.18-0.26, Offset 0.25-0.3, Haze 0.5-0.7, Glare 0 | blends horizon into sky |
| Bloom | Intensity 0.1-0.3, Threshold >= 2 | overdone bloom = "smeared lens" |
| ColorCorrection | Saturation 0.15-0.25, Contrast 0.05-0.1 | glue the palette |
| DepthOfField | FarIntensity 0.12, FocusDistance 60, InFocusRadius 140 | softens jagged distance |

- Sky: a cartoon skybox (find via Studio Assistant "search the Creator Store", insert into ServerStorage, print the 6 Skybox* ids, then hard-code them in the preset). Bright blue + soft clouds is the simulator norm.
- Never let walls/cliffs block the horizon: use low rolling hills (Part + SpecialMesh Sphere ellipsoids, half buried) with round trees, getting bigger/paler with distance.
- Limit shadow-casting local lights; let sun + ambient do the work (mobile).

## 2. Layout: fewer, bigger, clearer things
- One clear path per loop step. Example (Clean a Painting style): building at the front -> open back doorway -> lot behind it -> delivery truck backed into the far end, so items visibly come from it.
- Remove anything that doesn't help play: floor platforms under displayed items, posters, sofas, barrels, benches, bins, extra signs, dense street trees. If in doubt, delete it.
- Growing buildings: anchor the side that touches the next area (e.g. back wall fixed at the lot) and grow toward the road so the flow never breaks.
- Generous spacing; player ~5 studs, paths 6+ studs, doorways 14-18 studs wide.

## 3. Materials & colour
- Default everything to **SmoothPlastic** (tiled Concrete/Brick/DiamondPlate textures look grainy/pixelated). Keep Glass and Neon; keep Wood/DiamondPlate only on hero props that need it (crates).
- Reflectance 0 on floors and metals. Large surfaces: mid tones, not white (white + bloom = glare).
- Define a palette module; give each progression tier its own unmistakable colour
  (e.g. crates 1-10: light wood, orange wood, dark wood, silver, blue, green, purple, red, gold, black+cyan glow).
- "Dirty/dusty" = a soft see-through film (cloned part, +2.5% size, SmoothPlastic, Transparency 0.3) plus dulled paint that fades back as you clean - never lumps of parts.

## 4. UI
- Mobile first: ScreenInsets = CoreUISafeInsets, UIScale from viewport, anchor to corners, big tap targets.
- Use **painted icons**, not text: generate a matching set with Blueprint Studio asset-generator
  (one batch, same style prompt: "chunky glossy 3D cartoon, bold dark outline, single object, no text, transparent background").
  Get files: `download_asset(preview=true)` gives a 768px alpha WebP in tool results -> convert to 512px PNG -> commit to the PC -> Studio Asset Manager > Import (type the quoted filenames in the dialog) -> read IDs from the Asset Manager list -> `Icons.Images`.
- Picture-first cards (icon + small level badge + price strip) instead of words.
- World labels: short, stud-sized BillboardGuis with small MaxDistance (20-45). One NEXT objective pill + a guide arrow/beam beats paragraphs of instructions.
- Reference sites for layouts: Game UI Database (gameuidatabase.com), Interface In Game, top Roblox simulators.

## 5. Juice (scaled to importance)
- Tiers: small (pop UI 0.12) / medium (pop 0.2 + shake 0.3) / large (pop 0.3 + shake 0.6). Assign every event a tier.
- Shake = decaying trauma^2 applied to `Humanoid.CameraOffset` (smooth sin, never random per frame, never move the body).
- Pops = UIScale tween with EasingStyle.Back Out. Everything eases; nothing linear.
- Bursts = ParticleEmitter Rate 0 + `:Emit(n)`, cleaned with Debris. Arcs (truck -> slot) via a NumberValue-driven quadratic bezier + ScaleTo; disappear = hop, spin, shrink, puff.
- Juice must return to rest; don't pop on every 1-second income tick.

## 6. Verify before saying done
Play the loop end to end, take before/after shots from fixed cameras, check: horizon open? anything glaring? any label you can't read? anything that could be removed? Then commit.
