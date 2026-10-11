# mantle-wallpaper

A swatch-deck wallpaper picker for [Mantle](https://github.com/anasgets111/mantle), ported from
[dhrruvsharma/qs-wallpaperpicker](https://github.com/dhrruvsharma/qs-wallpaperpicker), a
[Quickshell](https://quickshell.org) picker taken out of
[dhrruvsharma/shell](https://github.com/dhrruvsharma/shell). All credit for the design goes to
the original.

Every wallpaper is a paint-chip card in the colour scheme it would give your desktop. The cards
are fanned out like a hand along the bottom of the screen, the screen behind them previews the card
in front at full size, and the picker's own colours change to match it as you browse. The card you
set rises to the middle of the screen, lights up, and grows into the wallpaper.

## About this port

The port was written with [Claude Code](https://claude.com/claude-code) as an experiment: how far a
QML/Quickshell config translates 1:1 to a Lua-declared Mantle shell. Where Mantle couldn't express
something, the engine gained it rather than the port working around it: `on_key_release`,
`on_double_click`, drag velocity, `elide = "middle"`, file size in folder listings, `image_status`
and `image.playing` all came out of this port. The Lua is the result of that experiment, reviewed
but not battle-tested; expect rough edges.

## What it does

- **Local:** the wallpapers in your folder, sorted by name, colour (round the hue wheel: the deck
  becomes a spectrum) or newest first.
- **Favourites:** the ones you've hearted.
- Each card wears its wallpaper's Material scheme, read with Mantle's palette (quantize, score, a
  dark tonal-spot scheme: what matugen computes), cached in `~/.cache/mantle-wallpaper/`.
- A ribbon under the header shows the whole deck in colour; hover for a glimpse, click or drag to go.
- Mantle draws the wallpaper on every output, with 16 transitions (grow, tiles, scan, warp, fade,
  ink, glitch, fusuma, fan, glass, press, dust, rule, tide, lotus, fire), one chosen or random.
- Animated GIFs hold still until the live preview is on.
- Setting a wallpaper writes its colours (dark and light, every role) to
  `~/.cache/mantle-wallpaper/colors.json` and renders matugen-style templates you list in the
  settings.

## Requirements

- Mantle built from `main` (newer than 0.7.0: it needs `image_status`, `image.playing`,
  `on_key_release`, `on_double_click` and `elide = "middle"`).
- The Material Symbols Rounded font; JetBrainsMono Nerd Font for the chips' hex codes.

## Use

```sh
git clone https://github.com/anasgets111/mantle-wallpaper
mantle init -c mantle-wallpaper     # editor support: writes .luarc.json for lua-language-server
mantle -d -c mantle-wallpaper       # run it beside your own shell
```

Bind a key to open it, e.g. Hyprland: `bind = SUPER, W, exec, mantle call wallpaper.toggle`.
With several Mantle shells running, add `--pid` (`mantle list` shows them).

| Command | Does |
| --- | --- |
| `mantle call wallpaper.toggle` | Open or close the picker |
| `mantle call wallpaper.set <file>` | Set a wallpaper: an absolute path, `~/…`, `file://…` or a name in the folder |
| `mantle call wallpaper.current` | Print the wallpaper on screen |

Keys: ←→ browse, Home/End, PgUp/PgDn, R random, Enter set, F favourite, S sort, Space peek (hold,
or tap to keep), V live preview, Tab source, Esc close. Mouse: wheel or drag to browse (a flick
carries on), click a card to bring it to the front, click the front card or double-click any card
to set it, click the picture to peek.

Settings live in `~/.local/state/mantle-wallpaper/settings.json` (the gear edits most of them):
`dir` (default `~/Pictures/wallpapers`), `transition` (`"random"` or a name), `animate_choice`,
`live_preview`, `favorites`, and `templates`, a list of
`{ input = "~/x.tpl", output = "~/.config/x", hook = "shell command" }` rendered on each change with
`{{colors.<role>.<default|dark|light>.<hex|hex_stripped|rgb|rgba>}}`.

## Not ported

- Wallhaven search and download (planned).
- Video wallpapers and video preview: Mantle has no video decode. WebP animation: Mantle animates GIF.
- The external wallpaper command (swww, hyprpaper, …): Mantle draws the wallpaper itself.
- Pausing an animated wallpaper while windows cover it (Hyprland-specific in the original).
- matugen: replaced by Mantle's palette; per-theme transition selection: replaced by a setting.

## Known differences from the original

From a line-by-line parity review; to be closed in later passes.

- Toggling while the picker is closing doesn't reopen it.
- A chosen card starts its flight from the front slot, not from the card clicked, and doesn't
  unrotate.
- Dragging and ribbon scrubbing move the deck a card at a time; the original follows the pointer
  continuously, with scale and dim following the fractional position.
- Un-favouriting the front card in Favourites, or the folder changing while open, doesn't refocus.
- Switching source keeps the previous card instead of landing on the wallpaper on screen.
- The ribbon and hints fade in place instead of sliding with the header; chrome colours snap where
  the original fades them over 420 ms.
- The picker closes on a fixed delay after the bloom, not when the wallpaper is drawn.
- Choosing a card skips the transition on every output, not only the one under the picker.
- The colour scan runs when the picker opens, and its cache is saved when the scan finishes.

## License

GPL-3.0-or-later, as the original. See `LICENSE`.
