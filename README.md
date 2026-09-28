# Rivals Changer (full, in-game GUI)

Everything in Matcha, with a window drawn over the game: every weapon with a
picture of each skin, your wraps, finishers and charms, skyboxes, lighting and
sounds. The pictures and skin lists come from the
[config site](https://martinikaws.github.io/rivals-skins/); weapons, finishers
and charms the site doesn't list yet are read from the running game.

Only you see the changes. Nothing is sent to the server.

## Files

| File | What it is |
| --- | --- |
| `gui.lua` | The window. Edits `rivals_config.lua` and runs the changer. |
| `main.lua` | The changer itself. Works on its own, with or without the GUI. |
| `autoexec.lua` | Put this in `C:\matcha\autoexec` to load the window on every join. |

The site-driven version, where the config is built on a web page instead, lives
in [RivalsSkinChangerSITEBASED](https://github.com/Martinikaws/RivalsSkinChangerSITEBASED).

## Getting started

1. Put `main.lua` in `C:\matcha\workspace` as `RivalsSkinSwapper.lua`.
2. Run `gui.lua` from Matcha while you are in Rivals.
3. Pick a weapon, choose its skin, then press **Save & Apply**.

**Right Shift** shows and hides the window. You can pick another key, and the
accent color, in its **Settings** tab.

## Applying on every join

Save `gui.lua` in your workspace as `RivalsSkinGui.lua`, then put `autoexec.lua`
in `C:\matcha\autoexec`. It waits for Rivals to load, opens the window from your
workspace, and falls back to the copy in this repo if the file is missing.

With **Auto-apply on join** switched on (Settings tab), that is all you need: it
applies your saved config by itself, once per server, and the window is there
if you want to change something. Settings are remembered in
`rivals_gui_settings.txt`.

Keep the changer itself out of that folder. Two launchers in autoexec means it
starts twice; the second start is refused by its own lock.

## What the window covers

- **Skins** - every weapon, grouped Primary / Secondary / Melee / Utility like
  the game's loadout. Pick one to choose its look:
  - **Switch** - what the default weapon looks like. No skin needed.
  - **Swap** - equip a skin you own and it looks like another skin of the same
    weapon.
- **Cosmetics** - wraps, finishers and charms: the one you own looks like
  another. Season charms also ask which rank, from Unranked to Archnemesis.
- **Visuals** - every skybox (the game's own and the uploaded ones) and
  lighting: normal, dark, or matched to the sky.
- **Sounds** - hit, headshot and kill sounds, from a library or any audio id,
  with a preview.

Lists scroll by dragging them or their scrollbar, or with Page Up / Page Down
and the arrow keys (Matcha can't read the mouse wheel).

Choices are written to `rivals_config.lua` (the previous file is kept as
`rivals_config.backup.lua`), so the changer runs the same with or without the
window, including from autoexec.

## When things apply

| Change | When you see it |
| --- | --- |
| Skins, swaps, wraps | Straight away; re-equip the weapon |
| Skin effects (beams, tracers, explosions) | After you respawn |
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

## Credits

- Skin changer by Martini
- mr.vage - Main Contributor for the GUI (sorta copied from Gain's external)
- dantekarati - Contributor for the idea
- Main testers/supporters: choperr0333 aka @Giounis
- Gain's Discord: https://discord.gg/RHbxDSe8Z
