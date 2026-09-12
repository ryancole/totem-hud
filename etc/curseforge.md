# CurseForge listing

Source text for the project page. Paste the summary into the "Summary"
field and the description into the description editor (Markdown mode).

## Summary

Shows shamans a compact list of their active totems with draining timers, and alerts them with a pulsing icon as each one is about to expire and a voice cue when it is gone.

## Description

**Totem HUD** is a compact timer list for shamans: one bar per totem you have down, draining as it runs out, with a clear alert as each one is about to expire and a voice cue when it goes. Drop your totems, glance at the panel, re-drop when you hear it.

**Features**

- **One bar per active totem.** Each bar shows the totem's icon, its name, and the time left, and drains as the totem runs out. Bars are tinted for their element.
- **Stable layout.** Always four rows in the default totem bar's order (earth, fire, water, air), dimmed where nothing is down, so a totem never jumps around and the panel never resizes.
- **Expiry warning.** Under ten seconds the timer turns red and a quest "!" pulses beside the row.
- **Missing-totem reminder.** In combat, the same "!" sits beside any element you have nothing down for, so a dead or forgotten totem doesn't go unnoticed mid-fight.
- **Out-of-range alert.** When a buff totem's buff leaves you, you've walked out of its range: a red X pulses beside the row and a voice says "totem distance" once. Works everywhere, dungeons and raids included, since it watches your buffs rather than positions.
- **Voice cue when a totem goes.** The moment a totem is gone, a voice says "totem expiring" if it ran out or "totem dead" if something killed it, so you know to re-drop. Re-dropping over an old totem or recalling with Totemic Call stays quiet.
- **Out of the way.** The panel hides while no totem is down (or stays up, if you prefer) and updates freely in combat. Lock it in place, or unlock it to drag it wherever you like.
- **Replaces the default timers.** One option hides the stock totem icons under the player frame, since the HUD covers them.
- **Your look.** Choose the font size, whether bars are colored by element (the whole bar, or only the time remaining), and whether to show the border. Text is set in Cascadia Mono, bundled with the addon.
- **Shaman only, zero setup.** On any other class it loads and does nothing. No libraries, no configuration needed to get started.

**Options** live under Options -> AddOns -> Totem HUD, or `/th`:

- Lock the HUD in place (unlocked, it shows a sample bar per element so you can see where it is)
- Hide the HUD while no totems are down
- Show a border around the HUD
- Color each bar by its element, and whether the color covers the whole bar or only the time remaining
- Font size, 6 to 16
- Which side of the HUD the alert icons hang off, left or right
- Play a sound when a totem expires or is killed, or you leave its range
- Hide the default totem timers under the player frame

**Commands**

- `/th` — open the settings panel
- `/th lock` / `/th unlock` — lock the HUD, or unlock it to drag it
- `/th reset` — move the HUD back to its default spot
- `/th list` — print your totems and their remaining time

Built for TBC Anniversary (2.5.6).
