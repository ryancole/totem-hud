# Totem HUD

WoW TBC Anniversary (2.5.6, Interface 20506) addon for shamans: a small
on-screen list of the totems you have down, one draining bar per totem
with its icon, name, and time left. On any other class it loads and does
nothing.

## Files

- `TotemHud.toc` — addon manifest (must stay at the repo root — WoW looks
  for it at the top of the addon folder)
- `src/Core.lua` — SavedVariables, the shaman gate, the totem slot table
  and scan, event wiring, slash commands
- `src/Hud.lua` — the HUD panel: one element-colored bar per totem down,
  ticking on a throttled OnUpdate while anything is out
- `src/BlizzardTotems.lua` — hides and restores the default totem timers
  under the player frame, per the option
- `src/Options.lua` — settings panel (Options -> AddOns -> Totem HUD)
- `assets/` — `logo.png` is the project art; `logo.tga` (addon list icon)
  is baked from it by `etc/logo.py` (Python + Pillow); `CascadiaMono.ttf`
  is the bar text's font (see `assets/LICENSE-CascadiaMono.txt`)

## How it works

The client keeps four totem slots (fire, earth, water, air) and reports
each one through `GetTotemInfo`: whether a totem is down, its name, when
it was placed, how long it lasts, and its icon. `PLAYER_TOTEM_UPDATE`
fires whenever a slot changes, whether you dropped a totem, recalled it,
it expired, or something killed it. The HUD re-reads all four slots on
that event and lays out a bar for each slot that has a totem, in the
default totem bar's order (earth, fire, water, air) so a totem never
moves when another comes or goes.

While anything is down, a tenth-of-a-second ticker drains each bar from
the totem's start time and duration and updates the time text. Under ten
seconds the time turns red and the quest "!" icon pulses just left of
the row, outside the panel. When the last totem goes, the ticker stops
and the panel hides. The rank suffix on totem names ("Mana Spring Totem
IV") is dropped for room. Bar text is set in Cascadia Mono, bundled in
`assets`, since the game ships no monospace face; if the font fails to
load, the stock small font stands in at the same size.

The HUD is plain frames with no secure buttons, so it updates freely in
combat.

## Developing

WoW loads an addon from a folder whose name matches the `.toc`, so link this
repo into your AddOns directory as `TotemHud` (PowerShell, adjust the game
path):

```powershell
New-Item -ItemType Junction `
  -Path "C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\TotemHud" `
  -Target "C:\Users\Ryan\source\repos\totem-hud"
```

`/reload` in-game picks up Lua changes; a full restart is only needed for
`.toc` changes.

`.\etc\check.ps1` runs luacheck and a LuaJIT parse over `src`; CI runs the
same luacheck on every push.

## Releasing

Releases are built by the [BigWigs packager](https://github.com/BigWigsMods/packager)
via GitHub Actions (`.github/workflows/release.yml`). Pushing a tag like
`v0.1.0` packages the addon (with `@project-version@` in the .toc replaced
by the tag) and attaches the zip to a GitHub release. To also upload to
CurseForge, add a `## X-Curse-Project-ID` line to the .toc and a
`CF_API_KEY` repo secret.

```bash
git tag v0.1.0 && git push origin master --tags
```

## Commands

- `/th` (or `/totemhud`) — open the settings panel
- `/th lock` / `/th unlock` — lock the HUD in place (the default), or
  unlock it so it can be dragged. While unlocked it shows a sample bar per
  element so you can see where it is
- `/th reset` — move the HUD back to its default spot
- `/th list` — print your totems and their remaining time to chat

## Options

- Lock the HUD in place (on by default)
- Keep a dimmed row for each element with no totem down (off by default;
  on, the list is always four rows tall and never shifts)
- Show a border around the HUD (on by default; off leaves just the
  translucent background behind the bars)
- Color each bar by its element (on by default; off, the rows are just
  icon, name, and time on the panel background)
  - Color the whole bar, dim where drained (on by default; off, only the
    remaining-time fill is colored). Only applies while the option above
    is on
- Font size, 6 to 16 (7 by default). Rows grow to fit a large font
- Hide the default totem timers under the player frame (off by default).
  The default frame stops updating and stays hidden; unchecking brings it
  back without a reload. The change waits for combat to end
