#!/usr/bin/env node
// Regenerates manifest.json from Settings.js:  node tools/gen-manifest.js
const fs = require("fs"), path = require("path");
const root = path.join(__dirname, "..");
const src = fs.readFileSync(path.join(root, "Settings.js"), "utf8").replace(".pragma library", "");
const { realSettings } = new Function(src + ";return { realSettings }")();
const settings = realSettings();

const manifest = {
  schemaVersion: 1,
  id: "io.github.qempexe.omatune",
  name: "Omatune",
  version: "1.0.0",
  author: "qempexe",
  license: "MIT",
  description: "SongRec in your Omarchy bar: click to listen, then see the song, artist and cover in a notification and in the history.",
  kinds: ["bar-widget"],
  entryPoints: { barWidget: "BarWidget.qml" },
  barWidget: {
    displayName: "Omatune",
    description: "Song recognition (SongRec) with theme, notification and history settings",
    category: "Media",
    aliases: ["songrec", "shazam", "song", "recognize", "music", "identify"],
    allowMultiple: false,
    defaultSection: "right",
    defaults: {},
    schema: []
  }
};

for (const d of settings) {
  manifest.barWidget.defaults[d.key] = d.defaultValue;
  const entry = { key: d.key, type: d.type, label: d.label, defaultValue: d.defaultValue, description: d.description };
  if (d.options) entry.options = d.options;
  if (d.min !== undefined) entry.min = d.min;
  if (d.max !== undefined) entry.max = d.max;
  if (d.step !== undefined) entry.step = d.step;
  manifest.barWidget.schema.push(entry);
}

fs.writeFileSync(path.join(root, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
console.log("manifest.json written with", settings.length, "settings");
