# Changelog

All notable changes to Omatune. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [1.2.1] - 2026-10-28

### Security

- The clip is recorded into a folder only you can open (`~/.cache/omatune/capture`,
  0700), as a file only you can read (0600), so another account on the computer can't
  open it while it is recorded or identified. Omatune won't record if that folder is a
  link or isn't yours.
- The history, favourites and settings folders are made private (0700) at every start,
  and a clip left behind by a crash, or by 1.1 and before, is removed.

## [1.2.0] - 2026-10-28

### Added

- **Pop out**: Omatune can leave the bar and become a window you can move, resize and
  tile, and **Dock** puts it back. **Open as** picks which one the bar button opens.
- Many new settings, in tabs with a search box: color schemes (Follow theme, Window
  borders, Custom, Monochrome) and the text color; card style, spacing, roundness, text
  size and the cover in the Listen tab; window size, outline, tint and opacity; what the
  bar button shows and what a middle click does. Each has its own reset, and
  **Reset all** puts everything back.
- An **About** tab with the logo, the version and a link to more plugins, and the logo
  in the window's header.
- Tests for the parsing, the history, the settings, the border colors, the cover limits and the manifest:
  `node tests/test_model.js`.
- A contributing guide and a code of conduct.

### Changed

- Covers are shown only as small copies made in a separate, limited process: `curl`
  fetches them over https only, with a size and a time limit, and `vipsthumbnail` makes
  a clean PNG of them. Needs `vipsthumbnail` (libvips), which Omarchy already has.
- A new window: header card, underlined tabs, one content
  card, and a footer with the shortcuts. **Alt+←/→** switches tabs.
- The colors follow the bar and the theme straight from the shell, instead of reading
  Omarchy's theme files with a script.
- Settings saved by 1.1 keep working under their new names.
- The files live in `qml/` folders: `core/`, `panel/`, `controls/` and `js/`.
- The JavaScript is written in ES6: `const` and `let`, and arrow functions.
- The README follows a new layout, with screenshots and a new preview.

### Fixed

- Custom colours are used exactly as picked, no longer swapped for black or white.
- On a light custom background, a text color you never picked is dark, and a color left
  over from 1.1 no longer mixes with the ones picked since. Text on a dark accent stays
  readable.
- The About page no longer runs into the tabs in a short or narrow window: it starts at
  the top and scrolls when it doesn't fit, and the settings tabs scroll sideways instead
  of overlapping.
- Songs read back from the history and favourites files are checked, so a hand-edited
  file can't bring in odd links or fields.
- The plugin's description no longer offers a SongRec install; it says SongRec needs to be installed.

## [1.1.0] - 2026-10-12

### Changed

- A new look: its own rounded window with a thin border, a header card with the
  continuous-listening switch, underlined tabs, one card per tab, switches for on and
  off settings, and a Listen tab that grows so nothing overlaps the footer.
- Settings apply at once and are saved locally, without `omarchy bar set`, so changing
  a setting no longer freezes the shell.

### Fixed

- The bar icon and hex colour fields no longer read the clipboard in the background;
  paste is a single, bounded Ctrl+V.

## [1.0.1] - 2026-10-08

### Added

- A notice in the Listen tab when SongRec is missing.

### Fixed

- The click actions in the README, and the description's wording.

## [1.0.0] - 2026-10-08

### Added

- First release: song recognition in the bar. Click to listen, then see the song,
  artist and cover in a notification and in the history.

[1.2.1]: https://github.com/qempexe/omarchy-omatune/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/qempexe/omarchy-omatune/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/qempexe/omarchy-omatune/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/qempexe/omarchy-omatune/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/qempexe/omarchy-omatune/releases/tag/v1.0.0
