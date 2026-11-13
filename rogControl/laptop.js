.pragma library

// Original vector illustration of a 14" ROG Zephyrus-style laptop, generated as SVG
// so chassis colours can be swapped at runtime. Coordinates:
//   front view  viewBox 0 0 700 490   (open, straight-on, slight deck perspective)
//   lid view    viewBox 0 0 500 353   (closed lid from above, with the Slash strip)
// Live elements (screen content, key glow, Slash segments) are drawn by QML on top,
// using the same coordinates exported here.

var FRONT_W = 700, FRONT_H = 490;
var LID_W = 500, LID_H = 353;

// Screen opening inside the bezel.
var SCREEN = { x: 80, y: 10, w: 540, h: 308, r: 3 };

// Slash strip on the lid: centre line and segment count.
var SLASH = { x1: 60, y1: 48, x2: 432, y2: 300, width: 9, segments: 64 };

function mix(a, b, t) {
    return {
        r: a.r + (b.r - a.r) * t,
        g: a.g + (b.g - a.g) * t,
        b: a.b + (b.b - a.b) * t
    };
}
function css(c, alpha) {
    var h = function (v) {
        var s = Math.max(0, Math.min(255, Math.round(v * 255))).toString(16);
        return s.length < 2 ? "0" + s : s;
    };
    return "#" + h(c.r) + h(c.g) + h(c.b);
}
function shade(c, k) { // k < 1 darker, > 1 lighter (toward white)
    return k <= 1 ? { r: c.r * k, g: c.g * k, b: c.b * k } : mix(c, { r: 1, g: 1, b: 1 }, k - 1);
}
function isLight(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b > 0.5; }

// ── Keyboard layout (in front-view coordinates) ──────────────────────
// Rows are defined in key units; the deck perspective narrows the top rows.
var KB = { top: 362, bottom: 428, leftTop: 92, rightTop: 608, leftBottom: 70, rightBottom: 630 };
var ROWS = [
    { h: 0.7, keys: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1] },
    { h: 1, keys: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2] },
    { h: 1, keys: [1.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5] },
    { h: 1, keys: [1.75, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.25] },
    { h: 1, keys: [2.25, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.75] },
    { h: 1, keys: [1, 1, 1, 1, 6, 1, 1, 1, 1, 1] }
];

function edgeX(y, side) {
    var t = (y - KB.top) / (KB.bottom - KB.top);
    return side === 0 ? KB.leftTop + (KB.leftBottom - KB.leftTop) * t
                      : KB.rightTop + (KB.rightBottom - KB.rightTop) * t;
}

// Returns [{pts:[[x,y]x4], row, col, u}] quads for every key.
var _keys = null;
function keys() {
    if (_keys)
        return _keys;
    var out = [];
    var totalH = 0;
    ROWS.forEach(function (r) { totalH += r.h; });
    var gapY = 3.0, gapX = 3.8;
    var unitY = (KB.bottom - KB.top - gapY * (ROWS.length - 1)) / totalH;
    var y = KB.top;
    ROWS.forEach(function (row, ri) {
        var h = row.h * unitY;
        var y0 = y, y1 = y + h;
        var units = 0;
        row.keys.forEach(function (u) { units += u; });
        var acc = 0, col = 0;
        row.keys.forEach(function (u) {
            // x positions at top and bottom edge of this row (perspective)
            var ax = function (yy, frac) {
                var l = edgeX(yy, 0), rr = edgeX(yy, 1);
                return l + (rr - l) * frac;
            };
            var f0 = acc / units, f1 = (acc + u) / units;
            var g = gapX / 2 / (KB.rightBottom - KB.leftBottom);
            out.push({
                pts: [[ax(y0, f0 + g), y0], [ax(y0, f1 - g), y0], [ax(y1, f1 - g), y1], [ax(y1, f0 + g), y1]],
                row: ri, col: col, u: u
            });
            acc += u;
            col++;
        });
        y = y1 + gapY;
    });
    _keys = out;
    return out;
}

function quadPath(p) {
    return "M" + p[0][0].toFixed(1) + "," + p[0][1].toFixed(1)
        + "L" + p[1][0].toFixed(1) + "," + p[1][1].toFixed(1)
        + "L" + p[2][0].toFixed(1) + "," + p[2][1].toFixed(1)
        + "L" + p[3][0].toFixed(1) + "," + p[3][1].toFixed(1) + "Z";
}

// ── Front view SVG ───────────────────────────────────────────────────
function frontSvg(chassis) {
    var c = chassis;
    var light = isLight(c);
    var rimHi = css(shade(c, light ? 1.06 : 1.25)), rimLo = css(shade(c, light ? 0.86 : 0.7));
    var deckTop = css(shade(c, light ? 0.9 : 0.78)), deckMid = css(shade(c, light ? 1.03 : 1.1)), deckFront = css(shade(c, light ? 0.95 : 0.9));
    var lip = css(shade(c, light ? 0.78 : 0.55));
    var wellOpacity = light ? 0.06 : 0.22;
    var cap = light ? css(shade(c, 1.05)) : "#1d1e21";
    var capEdge = light ? css(shade(c, 0.82)) : "#0e0e10";
    var pad = css(shade(c, light ? 0.97 : 1.04)), padEdge = css(shade(c, light ? 0.84 : 0.72));

    var s = [];
    s.push('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 700 490">');
    s.push('<defs>');
    s.push('<linearGradient id="rim" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="' + rimHi + '"/><stop offset="1" stop-color="' + rimLo + '"/></linearGradient>');
    s.push('<linearGradient id="deck" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="' + deckTop + '"/><stop offset="0.12" stop-color="' + deckMid + '"/><stop offset="0.85" stop-color="' + deckMid + '"/><stop offset="1" stop-color="' + deckFront + '"/></linearGradient>');
    s.push('<linearGradient id="deckSheen" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#000" stop-opacity="0.10"/><stop offset="0.5" stop-color="#fff" stop-opacity="0.06"/><stop offset="1" stop-color="#000" stop-opacity="0.10"/></linearGradient>');
    s.push('<linearGradient id="hinge" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0.55"/><stop offset="1" stop-color="#000" stop-opacity="0"/></linearGradient>');
    s.push('<linearGradient id="shadow" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0.35"/><stop offset="1" stop-color="#000" stop-opacity="0"/></linearGradient>');
    s.push('</defs>');

    // soft ground shadow
    s.push('<ellipse cx="350" cy="489" rx="340" ry="5" fill="#000" opacity="0.25"/>');

    // Lid: thin metal rim around a black glass bezel
    s.push('<rect x="68" y="0" width="564" height="352" rx="14" fill="url(#rim)"/>');
    s.push('<rect x="70.5" y="2.5" width="559" height="347" rx="12" fill="#09090b"/>');
    // screen opening (content drawn by QML); dark fallback
    s.push('<rect x="' + SCREEN.x + '" y="' + SCREEN.y + '" width="' + SCREEN.w + '" height="' + SCREEN.h + '" rx="' + SCREEN.r + '" fill="#101014"/>');
    // camera
    s.push('<circle cx="350" cy="6" r="1.6" fill="#1e2530"/>');
    // chin wordmark (generic, not a logo)
    s.push('<text x="350" y="336" text-anchor="middle" font-family="sans-serif" font-size="7.5" letter-spacing="3.5" fill="#55565c">ZEPHYRUS</text>');

    // Deck
    s.push('<path d="M69,349 L631,349 L699,477 Q700,488 689,488 L11,488 Q0,488 1,477 Z" fill="url(#deck)"/>');
    s.push('<path d="M69,349 L631,349 L699,477 Q700,488 689,488 L11,488 Q0,488 1,477 Z" fill="url(#deckSheen)"/>');
    // hinge shadow under the lid
    s.push('<path d="M69,349 L631,349 L634,357 L66,357 Z" fill="url(#hinge)"/>');
    // front lip
    s.push('<path d="M1,480 L699,480 Q700,488 689,488 L11,488 Q0,488 1,480 Z" fill="' + lip + '" opacity="0.8"/>');
    s.push('<line x1="6" y1="480" x2="694" y2="480" stroke="#fff" stroke-opacity="' + (light ? 0.5 : 0.18) + '" stroke-width="0.8"/>');

    // keyboard well
    s.push('<path d="M' + (KB.leftTop - 5) + ',' + (KB.top - 3) + ' L' + (KB.rightTop + 5) + ',' + (KB.top - 3)
        + ' L' + (KB.rightBottom + 6) + ',' + (KB.bottom + 3) + ' L' + (KB.leftBottom - 6) + ',' + (KB.bottom + 3) + ' Z" fill="#000" fill-opacity="' + wellOpacity + '"/>');

    // keycaps
    var ks = keys();
    for (var i = 0; i < ks.length; i++) {
        s.push('<path d="' + quadPath(ks[i].pts) + '" fill="' + cap + '" stroke="' + capEdge + '" stroke-width="0.6"/>');
    }

    // touchpad
    s.push('<path d="M208,436 L492,436 L503,475 L197,475 Z" fill="' + pad + '" stroke="' + padEdge + '" stroke-width="0.9"/>');
    s.push('</svg>');
    return s.join("");
}

// Screen glare, drawn above the live screen content.
function glareSvg() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 608 304">'
        + '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
        + '<stop offset="0" stop-color="#fff" stop-opacity="0.16"/>'
        + '<stop offset="0.38" stop-color="#fff" stop-opacity="0.04"/>'
        + '<stop offset="0.39" stop-color="#fff" stop-opacity="0"/>'
        + '<stop offset="1" stop-color="#000" stop-opacity="0.10"/>'
        + '</linearGradient></defs>'
        + '<rect width="608" height="304" fill="url(#g)"/></svg>';
}

// ── Lid (closed, from above) ─────────────────────────────────────────
function lidSvg(chassis) {
    var c = chassis;
    var light = isLight(c);
    var hi = css(shade(c, light ? 1.05 : 1.22)), lo = css(shade(c, light ? 0.88 : 0.72));
    var edge = css(shade(c, light ? 0.8 : 0.55));
    var channel = light ? css(shade(c, 0.72)) : "#1b1c1f";
    var plate = light ? css(shade(c, 0.9)) : css(shade(c, 0.8));
    var mark = light ? "#8b8c90" : "#a9abb0";

    // Strip polygon around the slash centre line
    var dx = SLASH.x2 - SLASH.x1, dy = SLASH.y2 - SLASH.y1;
    var len = Math.sqrt(dx * dx + dy * dy);
    var nx = -dy / len * SLASH.width / 2, ny = dx / len * SLASH.width / 2;
    var strip = "M" + (SLASH.x1 + nx) + "," + (SLASH.y1 + ny) + " L" + (SLASH.x2 + nx) + "," + (SLASH.y2 + ny)
        + " L" + (SLASH.x2 - nx) + "," + (SLASH.y2 - ny) + " L" + (SLASH.x1 - nx) + "," + (SLASH.y1 - ny) + " Z";

    var s = [];
    s.push('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 353">');
    s.push('<defs>');
    s.push('<linearGradient id="lid" x1="0" y1="0" x2="0.6" y2="1"><stop offset="0" stop-color="' + hi + '"/><stop offset="1" stop-color="' + lo + '"/></linearGradient>');
    s.push('<radialGradient id="sheen" cx="0.25" cy="0.1" r="0.9"><stop offset="0" stop-color="#fff" stop-opacity="' + (light ? 0.35 : 0.12) + '"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>');
    s.push('</defs>');
    s.push('<rect x="0.5" y="0.5" width="499" height="352" rx="16" fill="url(#lid)" stroke="' + edge + '" stroke-width="1"/>');
    s.push('<rect x="0.5" y="0.5" width="499" height="352" rx="16" fill="url(#sheen)"/>');
    s.push('<path d="' + strip + '" fill="' + channel + '"/>');
    // badge plate (generic mark + text lines)
    s.push('<rect x="22" y="312" width="104" height="21" rx="2" fill="' + plate + '" stroke="' + mark + '" stroke-opacity="0.55" stroke-width="0.8"/>');
    s.push('<path d="M30,327 L38,317 L46,327" fill="none" stroke="' + mark + '" stroke-width="1.4"/>');
    s.push('<rect x="58" y="318" width="58" height="2.2" fill="' + mark + '" opacity="0.8"/>');
    s.push('<rect x="72" y="324" width="44" height="2.2" fill="' + mark + '" opacity="0.6"/>');
    s.push('</svg>');
    return s.join("");
}

// Slash LED segment centres + angle (lid coordinates).
function slashSegments() {
    var out = [];
    var n = SLASH.segments;
    for (var i = 0; i < n; i++) {
        var t = (i + 0.5) / n;
        out.push({ x: SLASH.x1 + (SLASH.x2 - SLASH.x1) * t, y: SLASH.y1 + (SLASH.y2 - SLASH.y1) * t, i: i });
    }
    return out;
}

function dataUrl(svg) {
    return "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svg);
}
