# Totem HUD

WoW TBC Anniversary (2.5.6, Interface 20506) addon for shamans: a small
on-screen list of the totems you have down, one draining bar per totem
with its icon, name, and time left. It is always four rows, dimmed
where nothing is down, and can hide when no totem is out. On any other
class it loads and does nothing.

## Files

- `TotemHud.toc` — addon manifest (must stay at the repo root — WoW looks
  for it at the top of the addon folder)
- `src/Core.lua` — SavedVariables, the shaman gate, the totem slot table
  and scan, event wiring, slash commands
- `src/Hud.lua` — the HUD panel: one element-colored bar per totem down,
  ticking on a throttled OnUpdate while anything is out
- `src/BlizzardTotems.lua` — hides and restores the default totem timers
  under the player frame, per the option
- `src/Options.lua` — settings panel (Options -> AddOns -> Totem HUD):
  checkboxes, the font size slider, the alert-side dropdown, and the
  reset-position button
- `assets/` — `logo.png` is the project art; `logo.tga` (addon list icon)
  is baked from it by `etc/logo.py` (Python + Pillow); `CascadiaMono.ttf`
  is the bar text's font (see `assets/LICENSE-CascadiaMono.txt`);
  `tote.ogg` is the expiry sound, built from a voice recording by
  `etc/tote.py` (Python + ffmpeg): trimmed to the word, compressed, run
  through a short synthetic room reverb, and peak-normalized

## How it works

The client keeps four totem slots (fire, earth, water, air) and reports
each one through `GetTotemInfo`: whether a totem is down, its name, when
it was placed, how long it lasts, and its icon. `PLAYER_TOTEM_UPDATE`
fires whenever a slot changes, whether you dropped a totem, recalled it,
it expired, or something killed it. The HUD re-reads all four slots on
that event and lays out one row per slot in the default totem bar's
order (earth, fire, water, air): a bar for a slot with a totem, a dimmed
row naming the element for one without. The panel is always four rows
tall, so a totem never moves and the panel never resizes as others come
and go. In combat, the quest "!" sits steadily beside each empty row,
since a missing totem matters in a fight; it appears when combat starts
(`PLAYER_REGEN_DISABLED`) and clears when it ends. By default the whole panel hides while no totem is down; an
option keeps it up.

While anything is down, a tenth-of-a-second ticker drains each bar from
the totem's start time and duration and updates the time text. Under ten
seconds the time turns red, the quest "!" icon pulses just outside the
panel beside the row (on the left, or the right by option), and `assets/tote.ogg` (Ryan saying "tote") plays
once on the Master channel. The sound fires once per totem, keyed on the
totem's start time, so a re-layout can't replay it. The same clip plays
when a totem is killed early: each scan remembers what every slot held,
and a slot that has gone empty while its totem still had more than ten
seconds left means something killed it (under ten seconds the expiry
alert already played). A slot holding a different totem was re-dropped,
and slots emptied within a second of a Totemic Call (spotted by its
`UNIT_SPELLCAST_SUCCEEDED`) were recalled; neither counts. The memory
is cleared on `PLAYER_ENTERING_WORLD`, since totems don't survive a
loading screen. When the last totem goes, the ticker stops. The rank suffix on totem names ("Mana Spring Totem
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

`python etc/tote.py <recording>` rebuilds `assets/tote.ogg` from the
source recording (kept outside the repo). Its trim points, reverb length,
and dry/wet mix are constants at the top of the script.

## Releasing

Releases are built by the [BigWigs packager](https://github.com/BigWigsMods/packager)
via GitHub Actions (`.github/workflows/release.yml`). Pushing a tag like
`v0.1.0` packages the addon (with `@project-version@` in the .toc replaced
by the tag) and uploads it to CurseForge using the `CF_API_KEY` repo secret
and the `## X-Curse-Project-ID` in the .toc.

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
- Hide the HUD while no totems are down (on by default; off, the panel
  stays up with its four dimmed rows)
- Show a border around the HUD (on by default; off leaves just the
  translucent background behind the bars)
- Color each bar by its element (on by default; off, the rows are just
  icon, name, and time on the panel background)
  - Color the whole bar, dim where drained (on by default; off, only the
    remaining-time fill is colored). Only applies while the option above
    is on
- Font size, 6 to 16 (7 by default). Rows grow to fit a large font
- Alert icon side, left or right (left by default): which side of the
  HUD the "!" hangs off
- Play a sound when a totem is about to expire (on by default)
- Play a sound when a totem is killed before it expires (on by default).
  Re-dropping a totem over an old one, or recalling them with Totemic
  Call, doesn't count
- Hide the default totem timers under the player frame (off by default).
  The default frame stops updating and stays hidden; unchecking brings it
  back without a reload. The change waits for combat to end
