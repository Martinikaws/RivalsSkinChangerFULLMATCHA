# Rivals Changer (full, in-game GUI)

Everything in Matcha, with a menu inside the game. No website needed: the item
lists are read from the running game, so new skins, wraps, finishers and charms
appear as soon as Rivals ships them, including cosmetics that exist in the files
before release.

Only you see the changes. Nothing is sent to the server.

## Files

| File | What it is |
| --- | --- |
| `gui.lua` | The menu. Edits `rivals_config.lua` and runs the changer. |
| `main.lua` | The changer itself. Works on its own, with or without the GUI. |

The site-driven version, where the config is built on a web page instead, lives
in [RivalsSkinChangerSITEBASED](https://github.com/Martinikaws/RivalsSkinChangerSITEBASED).

## Getting started

1. Put `main.lua` in `C:\matcha\workspace` as `RivalsSkinSwapper.lua`.
2. Run `gui.lua` from Matcha while you are in Rivals.
3. Open the **Rivals Changer** tab, choose what you want, then **Save & Apply**.

## Applying on every join

Put a file in `C:\matcha\autoexec` that runs the menu:

```lua
loadstring(readfile("RivalsSkinGui.lua"))()
```

(`gui.lua` saved in your workspace as `RivalsSkinGui.lua`.)

With **Auto-apply on join** switched on in the menu, that is all you need: the
menu waits for Rivals to load, applies your saved config by itself, once per
server, and the tab is there if you want to change something. The setting is
remembered in `rivals_gui.settings`, and defaults to on when the menu finds
itself in the autoexec folder.

Only `gui.lua` belongs in autoexec. Keeping the changer there as well just runs
it twice; the second run is refused by its own lock.

## What the menu covers

- **Skins** - a skin for each weapon.
- **Swaps** - equip a skin you own and it looks like another skin of the same
  weapon.
- **Wraps**, **Finishers**, **Charms** - the one you own looks like another.
  Season charms also ask which rank, from Unranked to Archnemesis.
- **Skybox** - the skies the game ships with, plus the classic Roblox sky.
- **Lighting** - a darker preset.

Choices are written to `rivals_config.lua` (the previous file is kept as
`rivals_config.backup.lua`), so the changer runs the same with or without the
menu, including from autoexec.

## When things apply

| Change | When you see it |
| --- | --- |
| Skins, swaps, wraps | Straight away; re-equip the weapon |
| Charms | Next time you equip the weapon |
| Finishers | The next time the finisher plays |
| Skybox | Next map or area load |
| Lighting | Straight away, and it survives map changes |

Run it once per server. A first run takes about three seconds.

## Notes

- Rivals only. It stops quietly in any other game.
- One run at a time: a second start while one is running is refused, because two
  at once can corrupt the weapon models.
- A finisher swap also changes how that finisher looks when other players use
  it, since the game loads one copy per name.
