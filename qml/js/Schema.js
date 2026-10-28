.pragma library

// Every setting, in the groups and order the Settings tab shows them. tools/gen-manifest.js
// writes manifest.json from this, and resolve() turns what is saved into clean values.
//
//   kind     enum, int, bool, string, or palette (a few colors edited together)
//   control  how an enum is drawn: scheme, tiles, seg or chips (seg or chips when left out)
//   section  a heading the row sits under, inside its tab
//   when     the row is dimmed unless another setting has one of these values

const PALETTE = [
    "#141414", "#1d1510", "#1a1b26", "#282a36", "#2e3440", "#2d353b", "#1f1f28", "#3b2a1f",
    "#e0e0e0", "#eadbc8", "#ffffff", "#c0caf5", "#d8dee9", "#dcd7ba", "#f8f8f2", "#e0def4",
    "#d4a35a", "#c8925a", "#7aa2f7", "#cba6f7", "#a7c080", "#88c0d0", "#fabd2f", "#ff6a1f"
];

const groups = [
    {
        title: "Colors",
        items: [
            { key: "colorMode", label: "Colors", kind: "enum", fallback: "theme", control: "scheme", section: "Scheme",
              options: ["theme", "borders", "custom", "monochrome"],
              labels: { theme: "Follow theme", borders: "Window borders", custom: "Custom", monochrome: "Monochrome" },
              hint: "Follow theme matches your Omarchy theme live. Window borders takes the accent from your theme's window border. Custom lets you choose the background, text and accent. Monochrome removes every hue." },
            { key: "customColors", label: "Custom colors", kind: "palette", section: "Scheme", presets: PALETTE,
              when: [{ key: "colorMode", is: ["custom"] }],
              fallback: { customBg: "#141414", customFg: "#e0e0e0", accentColor: "#d4a35a" },
              targets: [{ key: "customBg", label: "Background" }, { key: "customFg", label: "Text" }, { key: "accentColor", label: "Accent" }],
              hint: "Background, text and accent, used exactly as you pick them." },
            { key: "textColor", label: "Text", kind: "enum", fallback: "auto", section: "Text",
              options: ["auto", "theme", "custom"],
              labels: { auto: "Always readable", theme: "Theme", custom: "My text color" },
              hint: "Always readable keeps your theme's text color, and switches to black or white when the window is too light or too dark for it. My text color uses the Text color from Custom colors. Custom colors always use their own text color." }
        ]
    },
    {
        title: "Appearance",
        items: [
            { key: "cardStyle", label: "Card style", kind: "enum", fallback: "soft", control: "tiles",
              options: ["soft", "outline", "flat"], labels: { soft: "Soft", outline: "Outline", flat: "Flat" },
              hint: "Soft fills cards lightly, outline draws a border only, flat has neither." },
            { key: "density", label: "Spacing", kind: "enum", fallback: "comfortable", control: "tiles",
              options: ["compact", "comfortable", "spacious"], labels: { compact: "Compact", comfortable: "Comfortable", spacious: "Spacious" },
              hint: "How much air there is between things." },
            { key: "cornerRadius", label: "Roundness", kind: "int", fallback: 4, min: 0, max: 20, step: 2,
              hint: "0 is square, 20 is very round." },
            { key: "fontScale", label: "Text size", kind: "int", fallback: 100, min: 80, max: 150, step: 5, divisor: 100, decimals: 2,
              hint: "1 is normal, 1.25 is a quarter bigger." },
            { key: "showCover", label: "Show the cover", kind: "bool", fallback: true,
              hint: "The last song's cover in the Listen tab." }
        ]
    },
    {
        title: "Window",
        items: [
            { key: "windowWidth", label: "Window width", kind: "int", fallback: 520, min: 400, max: 1200, step: 20, section: "Size",
              hint: "How wide Omatune opens." },
            { key: "windowHeight", label: "Window height", kind: "int", fallback: 600, min: 420, max: 1100, step: 20, section: "Size",
              hint: "How tall Omatune opens." },
            { key: "openAs", label: "Open as", kind: "enum", fallback: "panel", control: "tiles", section: "Layout",
              options: ["panel", "window"], labels: { panel: "Bar panel", window: "Own window" },
              hint: "Where the bar button opens Omatune. You can always pop it out or dock it back from the header." },
            { key: "frame", label: "Window outline", kind: "bool", fallback: false, section: "Look",
              hint: "Draw the edge in your window border's colors instead of a plain neutral line." },
            { key: "frameGradient", label: "Outline gradient", kind: "bool", fallback: true, section: "Look",
              when: [{ key: "frame", is: [true] }],
              hint: "Use the window border's whole gradient, at its angle, when it has more than one color." },
            { key: "frameColor", label: "Outline color", kind: "enum", fallback: "accent", section: "Look",
              options: ["accent", "first", "middle", "last"],
              labels: { accent: "Accent", first: "Border's first", middle: "Border's middle", last: "Border's last" },
              when: [{ key: "frame", is: [true] }],
              hint: "The one color the outline takes when it isn't a gradient." },
            { key: "surfaceTint", label: "Window tint", kind: "int", fallback: 0, min: 0, max: 30, step: 2, section: "Look",
              hint: "How much of the accent washes over the background. 0 keeps it plain." },
            { key: "opacity", label: "Window opacity", kind: "int", fallback: 97, min: 50, max: 100, step: 1, section: "Look",
              hint: "100 is solid." }
        ]
    },
    {
        title: "Listening",
        items: [
            { key: "source", label: "Listen to", kind: "enum", fallback: "system", control: "tiles",
              options: ["system", "microphone"], labels: { system: "This computer", microphone: "Microphone" },
              hint: "This computer records what is playing. Microphone listens to the room." },
            { key: "duration", label: "Listen length", kind: "int", fallback: 5, min: 4, max: 20, step: 1,
              hint: "Seconds to record before identifying. 4 to 6 is usually enough; longer is slower but finds more in noisy rooms." },
            { key: "notify", label: "Notify when a song is found", kind: "bool", fallback: true, section: "Notifications",
              hint: "A desktop notification with the title and the artist." },
            { key: "notifyCover", label: "Cover in the notification", kind: "bool", fallback: true, section: "Notifications",
              when: [{ key: "notify", is: [true] }],
              hint: "The album cover as the notification's picture, when there is one." },
            { key: "notifyTimeout", label: "Notification time", kind: "int", fallback: 8, min: 2, max: 30, step: 1, section: "Notifications",
              when: [{ key: "notify", is: [true] }],
              hint: "Seconds the notification stays on screen." },
            { key: "historySize", label: "Songs to keep", kind: "int", fallback: 20, min: 5, max: 100, step: 5, section: "History",
              hint: "How many songs the History tab remembers. Favourites are kept apart and don't count." }
        ]
    },
    {
        title: "Bar",
        items: [
            { key: "barDisplay", label: "Bar button shows", kind: "enum", fallback: "both",
              options: ["icon", "song", "both"], labels: { icon: "Icon", song: "Last song", both: "Both" },
              hint: "While listening it always shows the countdown." },
            { key: "barIcon", label: "Bar icon", kind: "string", fallback: "♪", maxLength: 8, presets: ["♪", "♫", "♬", "◉"],
              hint: "Up to 8 characters." },
            { key: "middleClick", label: "Middle click", kind: "enum", fallback: "history",
              options: ["history", "listen", "none"], labels: { history: "History", listen: "Listen now", none: "Nothing" },
              hint: "What clicking the bar button with the middle mouse button does." }
        ]
    }
];

// every key that is saved: a palette row saves its targets
const items = [];
const settingKeys = [];
const defaults = {};
for (const g of groups) {
    for (const it of g.items) {
        items.push(it);
        if (it.kind === "palette") {
            for (const t of it.targets) { settingKeys.push(t.key); defaults[t.key] = it.fallback[t.key]; }
        } else {
            settingKeys.push(it.key);
            defaults[it.key] = it.fallback;
        }
    }
}
const itemByKey = {};
for (const it of items) itemByKey[it.key] = it;

function isHex(v) { return typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v); }

// one value, made safe: a known option, a whole number in range, a real boolean,
// a hex color, or plain text that is not too long. Anything else is the default.
function clean(key, v) {
    const it = itemByKey[key];
    if (!it) {
        // a palette color
        for (const p of items) if (p.kind === "palette" && p.fallback[key] !== undefined) return isHex(v) ? v.toLowerCase() : p.fallback[key];
        return undefined;
    }
    if (v === undefined || v === null) return it.fallback;
    if (it.kind === "enum") return it.options.map(String).indexOf(String(v)) >= 0 ? String(v) : it.fallback;
    if (it.kind === "bool") return v === true || v === "true" ? true : (v === false || v === "false" ? false : it.fallback);
    if (it.kind === "int") {
        const n = typeof v === "number" ? v : (typeof v === "string" && /^-?[0-9]{1,6}$/.test(v) ? parseInt(v, 10) : NaN);
        return isFinite(n) ? Math.max(it.min, Math.min(it.max, Math.round(n))) : it.fallback;
    }
    if (it.kind === "string") {
        const s = (typeof v === "string" ? v : "").replace(/[\u0000-\u001f<>]/g, "").trim().slice(0, it.maxLength || 64);
        return s !== "" ? s : it.fallback;
    }
    return it.fallback;
}

// Settings saved by Omatune 1.1 and before had other names; they are still read.
const OLD_NAMES = { customBackground: "customBg", customText: "customFg", customAccent: "accentColor" };
const OLD_THEMES = { follow: "theme", custom: "custom", mono: "monochrome" };
function migrate(saved) {
    const src = saved && typeof saved === "object" ? saved : {};
    const out = {};
    for (const k of settingKeys) if (src[k] !== undefined) out[k] = src[k];
    for (const old in OLD_NAMES) if (out[OLD_NAMES[old]] === undefined && src[old] !== undefined) out[OLD_NAMES[old]] = src[old];
    if (out.colorMode === undefined && OLD_THEMES[src.theme] !== undefined) out.colorMode = OLD_THEMES[src.theme];
    if (out.barDisplay === undefined && src.barShowResult === false) out.barDisplay = "icon";
    return out;
}

// every setting, clean. `saved` (the settings file) wins over `shell` (what the
// shell's bar settings hold for this widget).
function resolve(saved, shell) {
    const a = migrate(saved), b = migrate(shell);
    const out = {};
    for (const k of settingKeys) out[k] = clean(k, a[k] !== undefined ? a[k] : b[k]);
    return out;
}

function isSetting(key) { return settingKeys.indexOf(key) >= 0; }
