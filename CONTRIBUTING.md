# Contributing

Omatune is small: one list of settings, one file of pure logic, and the QML that shows
them. Most changes touch one or two files.

```
qml/BarWidget.qml        the bar button, recording and identifying, notifications, history,
                         docking and popping out, and what the window asks of it (`ui.service`)
qml/core/UiState.qml     colors, spacing and the open tab, shared by both windows (`ui.*`)
qml/panel/TuneView.qml   the window: header, tabs, Listen, History, Settings, footer
qml/panel/SettingRow.qml one setting, drawn from its Schema.js entry
qml/js/Schema.js         every setting, in the tabs and order the Settings tab shows
qml/js/Model.js          pure logic: reading SongRec's answer, the history, favourites
qml/js/Art.js, qml/core/ArtCache.qml   covers, made safe before they are shown
```

## A new setting

1. Add it to a group in `qml/js/Schema.js`: a `key` that never changes once released, a
   `kind` (`bool`, `int`, `enum`, `string` or `palette`), a `label`, a `fallback` and a
   one-sentence `hint`. An `int` takes `min`, `max` and `step`; an `enum` takes
   `options` and `labels`, and `control: "tiles"` to draw it as tiles (add its picture
   to `qml/panel/TileArt.qml`). `section` puts it under a heading, `when` dims it
   unless another setting has one of the given values.
2. Read it as `cfg.<key>` in `qml/BarWidget.qml` or `ui.cfgSafe.<key>` in the window. The
   value is already clean (`Schema.resolve`).
3. Write the manifest again: `node tools/gen-manifest.js`.

The Settings tab builds its row, its search entry and its reset by itself.

## Rules

- `qml/js/Model.js` stays pure: no Qt, so the tests run in node.
- Anything read from a file or from SongRec is checked before it's used: songs through
  `Model.parseRecognition()` and `Model.cleanSongs()`, settings through
  `Schema.resolve()`, theme files through `Theme.parseBorder()`, links through `Model.safeUrl()`.
- A cover is never shown from its address. `qml/core/ArtCache.qml` downloads it with limits and
  makes a small PNG of it in a limited process; show only `pathFor()`.
- Text goes through `controls/Txt.qml`, which is plain text only. A text field is
  `controls/PasteInput.qml`, never a `TextInput`, so the clipboard is only read on
  Ctrl+V, capped.
- Helper commands are argument arrays. A shell script only gets its values as
  arguments (`"sh", "-c", script, "sh", value...`), never pasted into the script.
- ES6 JavaScript: `const` and `let`, and arrow functions for callbacks.

## Tests

```bash
node tests/test_model.js
```

They need nothing but node: the parsing, the history, the settings and their old
names, the border colors, the cover limits, and that `manifest.json` matches `Schema.js`.

Everyone taking part is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).
