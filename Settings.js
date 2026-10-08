.pragma library

// The one list of settings. tools/gen-manifest.js writes manifest.json from it, and the
// panel's Settings tab is built from it, grouped in the order below.
//   type "palette" is a UI-only row (the custom colour picker); it is not saved or put in the manifest.
//   ui "hidden" rows are saved but have no row of their own (the custom colours use the picker).
var GROUPS = ["Look", "Listening", "Notifications", "History"];

// Swatches offered by the custom colour picker (dark backgrounds, light text, a few accents).
var PALETTE = [
    "#141414", "#1d1510", "#1a1b26", "#282a36", "#2e3440", "#2d353b", "#1f1f28", "#3b2a1f",
    "#e0e0e0", "#eadbc8", "#ffffff", "#c0caf5", "#d8dee9", "#dcd7ba", "#f8f8f2", "#e0def4",
    "#d4a35a", "#c8925a", "#7aa2f7", "#cba6f7", "#a7c080", "#88c0d0", "#fabd2f", "#ff6a1f"
];

var SCHEMA = [
    { key: "theme", group: "Look", type: "enum", label: "Theme",
      options: ["follow", "custom", "mono"], labels: ["Follow Omarchy", "Custom", "Monochrome"], defaultValue: "follow",
      description: "Follow Omarchy changes the moment you switch Omarchy's theme. Custom lets you choose every colour. Monochrome is plain grey." },
    { key: "customPalette", group: "Look", type: "palette", label: "Custom colours", showWhen: "custom",
      description: "Choose which colour to change, then pick a swatch or type your own hex code." },
    { key: "customBackground", group: "Look", type: "string", ui: "hidden", label: "Custom background", defaultValue: "#141414",
      description: "Background colour used with the Custom theme." },
    { key: "customText", group: "Look", type: "string", ui: "hidden", label: "Custom text", defaultValue: "#e0e0e0",
      description: "Text colour used with the Custom theme." },
    { key: "customAccent", group: "Look", type: "string", ui: "hidden", label: "Custom accent", defaultValue: "#d4a35a",
      description: "Accent colour used with the Custom theme." },
    { key: "barIcon", group: "Look", type: "string", label: "Bar icon", defaultValue: "♪",
      description: "Up to 8 characters shown on the bar." },
    { key: "barShowResult", group: "Look", type: "boolean", label: "Show last song on the bar", defaultValue: true,
      description: "Show the last song found next to the icon." },

    { key: "source", group: "Listening", type: "enum", label: "Listen to",
      options: ["system", "microphone"], labels: ["This computer", "Microphone"], defaultValue: "system",
      description: "This computer records what is playing. Microphone listens to the room." },
    { key: "duration", group: "Listening", type: "integer", label: "Listen length", unit: "s", min: 4, max: 20, step: 1, defaultValue: 5,
      description: "How long to record before identifying. 4 to 6 seconds is usually enough; longer is slower but more reliable in noisy rooms." },

    { key: "notify", group: "Notifications", type: "boolean", label: "Notify when a song is found", defaultValue: true,
      description: "Send a desktop notification with the song title and artist." },
    { key: "notifyCover", group: "Notifications", type: "boolean", label: "Cover photo in notification", defaultValue: true,
      description: "Include the album cover when one is available." },
    { key: "notifyTimeout", group: "Notifications", type: "integer", label: "Notification time", unit: "s", min: 2, max: 30, step: 1, defaultValue: 8,
      description: "How long the notification stays on screen." },

    { key: "historySize", group: "History", type: "integer", label: "Songs to keep", min: 5, max: 100, step: 5, defaultValue: 20,
      description: "How many songs the History tab remembers." }
];

// Saved settings only (the picker row is not a setting).
function realSettings() {
    return SCHEMA.filter(function(d) { return d.type !== "palette" })
}

function defaults() {
    var out = {}, s = realSettings()
    for (var i = 0; i < s.length; i++) out[s[i].key] = s[i].defaultValue
    return out
}
