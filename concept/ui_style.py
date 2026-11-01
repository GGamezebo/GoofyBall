"""Shared, editable SVG interface icons and readable UI typography."""
from generate_concepts import text as base_text

MUTED = "#A6B4D2"
PATHS = {
    "play": '<path d="M8 4l13 8-13 8z"/>',
    "friends": '<circle cx="9" cy="8" r="3"/><path d="M2 21v-3a7 7 0 0114 0v3M17 5a3 3 0 010 6M19 15a5 5 0 013 5"/>',
    "blob": '<path d="M3 17C1 10 6 3 12 3s11 7 9 14c-1 5-17 5-18 0z"/><path d="M8 10v2m8-2v2M9 16q3 3 6 0"/>',
    "shop": '<path d="M3 8h18l-2 13H5L3 8zM8 8V6a4 4 0 018 0v2"/>',
    "trophy": '<path d="M7 3h10v7a5 5 0 01-10 0V3zM7 5H3v3a5 5 0 005 5m9-8h4v3a5 5 0 01-5 5M12 15v6m-4 0h8"/>',
    "settings": '<circle cx="12" cy="12" r="4"/><path d="M9 3h6l1 3 3 1 2 5-2 5-3 1-1 3H9l-1-3-3-1-2-5 2-5 3-1z"/>',
    "back": '<path d="M14 4l-8 8 8 8M6 12h16"/>',
    "close": '<path d="M5 5l14 14M19 5L5 19"/>',
    "pause": '<path d="M8 4v16M16 4v16"/>',
    "smile": '<circle cx="12" cy="12" r="10"/><path d="M8 8v2m8-2v2M7 14q5 7 10 0"/>',
    "bot": '<rect x="3" y="6" width="18" height="15" rx="5"/><path d="M12 2v4M8 11v2m8-2v2M8 17h8"/>',
    "quest": '<rect x="4" y="4" width="16" height="18" rx="3"/><path d="M9 2h6v5H9zM8 12l2 2 5-4M8 18h8"/>',
    "share": '<circle cx="18" cy="4" r="3"/><circle cx="5" cy="12" r="3"/><circle cx="18" cy="20" r="3"/><path d="M8 10l7-4M8 14l7 4"/>',
    "exit": '<path d="M10 3H3v18h7m4-15l6 6-6 6M8 12h12"/>',
    "copy": '<rect x="8" y="8" width="13" height="14" rx="3"/><path d="M16 4V2H2v14h2"/>',
    "target": '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/>',
    "coin": '<circle cx="12" cy="12" r="10"/><path d="M10 7h4m-4 10h4M12 7v10"/>',
    "gem": '<path d="M2 8l5-5h10l5 5-10 14L2 8zM2 8h20M7 3l5 19 5-19"/>',
}
ALIASES = {"▶": "play", "👥": "friends", "🫧": "blob", "🏐": "play", "🛒": "shop", "🏆": "trophy", "⚙": "settings", "←": "back", "✕": "close", "⏸": "pause", "😀": "smile", "🤖": "bot", "📋": "quest", "📤": "share", "🚪": "exit", "📋": "quest", "🎯": "target", "🪙": "coin", "💎": "gem"}

def icon(name, cx, cy, size=32, color="#E8F0FF"):
    return (f'<svg x="{cx-size/2}" y="{cy-size/2}" width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{color}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'
            + PATHS.get(name, PATHS["blob"]) + '</svg>')

def text(x, y, value, size=28, col=None, anchor="middle", weight="bold", extra=""):
    value = str(value)
    size = max(size, 24 if len(value) > 3 else 22)
    if col == "#7A8BB5":
        col = MUTED
    if value in ALIASES:
        return icon(ALIASES[value], x, y-size*.34, size, col or "#E8F0FF")
    if value[:1] in ALIASES and value[1:].strip():
        label = value[1:].strip()
        width = sum(.32 if c in ' ilI·' else .59 for c in label)*size + size*1.4
        left = x if anchor == 'start' else x-width if anchor == 'end' else x-width/2
        return (icon(ALIASES[value[0]], left+size*.5, y-size*.34, size, col or '#E8F0FF')
                + base_text(left+size*1.4, y, label, size, col, 'start', weight, extra))
    return base_text(x, y, value, size, col, anchor, weight, extra)

def button_label(x, y, label, size, color, max_width):
    """Replace action emoji with consistent line icons; fit within the button."""
    first = label[:1]
    name = ALIASES.get(first)
    clean = label[1:].strip() if name else label
    estimate = sum(.32 if c in ' ilI·' else .59 for c in clean)
    actual = min(size, (max_width - (size*1.4 if name else 0)) / max(estimate, 1))
    width = estimate * actual
    left = x - (width + (actual*1.4 if name else 0))/2
    out = icon(name, left+actual*.5, y-actual*.34, actual, color) if name else ''
    return out + base_text(left+(actual*1.4 if name else 0), y, clean, actual, color, 'start')
