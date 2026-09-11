# CurseForge listing

Source text for the project page. Paste the summary into the "Summary"
field and the description into the description editor (Markdown mode).

## Summary

Shows shamans a compact list of their active totems with draining timers, and alerts them with a pulsing icon and a voice cue as each one is about to expire or gets killed.

## Description

**Totem HUD** is a compact timer list for shamans: one bar per totem you have down, draining as it runs out, with a clear alert as each one is about to expire. Drop your totems, glance at the panel, re-drop before they're gone.

**Features**

- **One bar per active totem.** Each bar shows the totem's icon, its name, and the time left, and drains as the totem runs out. Bars are tinted for their element.
- **Stable layout.** Always four rows in the default totem bar's order (earth, fire, water, air), dimmed where nothing is down, so a totem never jumps around and the panel never resizes.
- **Three-part expiry alert.** Under ten seconds the timer turns red, a quest "!" pulses beside the row, and a short voice cue plays, once per totem.
- **Death alert.** The same voice cue plays when a totem is killed early, so you know to re-drop it. Re-dropping over an old totem or recalling with Totemic Call stays quiet.
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
- Play a sound when a totem is about to expire
- Play a sound when a totem is killed before it expires
- Hide the default totem timers under the player frame

**Commands**

- `/th` — open the settings panel
- `/th lock` / `/th unlock` — lock the HUD, or unlock it to drag it
- `/th reset` — move the HUD back to its default spot
- `/th list` — print your totems and their remaining time

Built for TBC Anniversary (2.5.6).
