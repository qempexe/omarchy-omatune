# Contributing

Omatune is small: one file of pure logic, one list of settings, and the QML that shows
them. Most changes touch one or two of them.

```
qml/BarWidget.qml        the bar button, recording and identifying, notifications, history
qml/panel/Panel.qml      the window: Listen, History, Settings and About
qml/js/Model.js          pure logic: reading SongRec's answer, colours, settings, history
qml/js/Settings.js       every setting, in the order and groups the Settings tab shows
qml/js/Art.js, qml/core/ArtCache.qml   covers, made safe before they are shown
```

## A new setting

1. Add it to `SCHEMA` in `qml/js/Settings.js`: a `key` that never changes once released, a
   `group` from `GROUPS`, a `type` (`boolean`, `integer`, `enum` or `string`), a
   `label`, a `defaultValue` and a one-sentence `description`. An `integer` takes
   `min`, `max` and `step`; an `enum` takes `options` and `labels`.
2. Read it as `cfg.<key>` in `qml/BarWidget.qml` or `root.cfg.<key>` in `qml/panel/Panel.qml`. The
   value is already clamped to what the schema allows (`Model.normalizeSettings`).
3. Write the manifest again: `node tools/gen-manifest.js`.

The Settings tab builds its row from the entry by itself.

## Rules

- `qml/js/Model.js` stays pure: no Qt, so the tests run in node.
- Anything read from a file or from SongRec is checked before it's used: songs through
  `Model.parseRecognition()` and `Model.cleanSongs()`, settings through
  `Model.normalizeSettings()`, links through `Model.safeUrl()`.
- A cover is never shown from its address. `qml/core/ArtCache.qml` downloads it with limits and
  makes a small PNG of it in a limited process; show only `pathFor()`.
- Every `Text` sets `textFormat: Text.PlainText`.
- Helper commands are argument arrays. A shell script only gets its values as
  arguments (`"sh", "-c", script, "sh", value...`), never pasted into the script.
- ES6 JavaScript: `const` and `let`, and arrow functions for callbacks.

## Tests

```bash
node tests/test_model.js
```

They need nothing but node: the parsing, the history, the colours, the cover limits,
and that `manifest.json` matches `Settings.js`.

Everyone taking part is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).
