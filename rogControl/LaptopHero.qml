import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Widgets
import "laptop.js" as Laptop

// Illustration of this laptop: an original SVG (generated in laptop.js, chassis
// colour swappable) with live layers on top: the real wallpaper on screen, the
// keyboard glowing with the current Aura effect, and the Slash strip on the lid.
Item {
    id: hero
    required property var ctl
    property string screenName: ""
    readonly property string wallpaper: ctl.wallpaperFor(screenName)
    readonly property bool wallpaperIsColour: wallpaper.startsWith("#")

    width: parent ? parent.width : 460
    height: Math.max(front.height, lidView.height + lidLabel.height + 4) + 6

    readonly property var chassis: ({ r: ctl.chassisColour.r, g: ctl.chassisColour.g, b: ctl.chassisColour.b })
    readonly property real frontW: Math.min(hero.width > 600 ? 640 : 320, (width - Theme.spacingL) * (ctl.hasSlash ? 0.68 : 0.8))
    readonly property real s: frontW / Laptop.FRONT_W

    // Only animate while the popout is actually open: DMS keeps popout content
    // loaded in the background, so `visible` stays true when it's hidden.
    property bool active: false
    readonly property bool running: active && visible

    // ── Animation clock (cheap: effects below read `phase`, no repaints) ─
    property real phase: 0
    readonly property real speedMul: ctl.kbSpeed === "High" ? 2.2 : ctl.kbSpeed === "Low" ? 0.5 : 1.0
    readonly property bool kbAnimated: ctl.kbOn && [1, 2, 3, 10].indexOf(ctl.kbMode) !== -1
    readonly property bool slashAnimated: ctl.hasSlash && ctl.slashEnabled && ctl.slashModeName(ctl.slashMode) !== "Static"
    Timer {
        interval: 50   // 20 fps is plenty for a small preview
        repeat: true
        running: hero.running && (hero.kbAnimated || hero.slashAnimated)
        onTriggered: hero.phase = (hero.phase + 0.05) % 10000
    }

    readonly property real kbLevel: ctl.kbOn ? ctl.kbBrightness / 3 : 0
    readonly property bool lightChassis: (0.2126 * chassis.r + 0.7152 * chassis.g + 0.0722 * chassis.b) > 0.5
    // Masks only depend on these; repainted rarely.
    readonly property var maskKey: [chassisLight(), s]
    function chassisLight() { return lightChassis; }
    onMaskKeyChanged: { keyMask.requestPaint(); slashMask.requestPaint(); }

    // Uniform colour for every mode except Wave (which uses a moving gradient).
    readonly property color uniformColour: {
        const m = ctl.kbMode;
        const t = phase * speedMul;
        const c1 = ctl.kbDisplayColour1, c2 = ctl.kbDisplayColour2;
        if (m === 1) {
            const k = (Math.sin(t * 2.2) + 1) / 2;
            return Qt.rgba(c1.r + (c2.r - c1.r) * k, c1.g + (c2.g - c1.g) * k, c1.b + (c2.b - c1.b) * k, 1);
        }
        if (m === 2)
            return Qt.hsva((t * 0.12) % 1, 1, 1, 1);
        return c1;
    }
    readonly property real kbPulse: ctl.kbMode === 10 ? 0.3 + 0.7 * (Math.sin(phase * 3) + 1) / 2 : 1

    // ── Front view (open) ────────────────────────────────────────────
    Item {
        id: front
        width: hero.frontW
        height: Laptop.FRONT_H * hero.s
        x: ctl.hasSlash ? 0 : (hero.width - width) / 2
        y: 2

        Image {
            anchors.fill: parent
            source: Laptop.dataUrl(Laptop.frontSvg(hero.chassis))
            sourceSize.width: Math.round(front.width * 2)
            smooth: true
            mipmap: true
        }

        // Screen: live wallpaper + glass glare
        Item {
            x: Laptop.SCREEN.x * hero.s
            y: Laptop.SCREEN.y * hero.s
            width: Laptop.SCREEN.w * hero.s
            height: Laptop.SCREEN.h * hero.s
            clip: true

            Rectangle {
                anchors.fill: parent
                color: hero.wallpaperIsColour ? hero.wallpaper : "#101014"
            }
            Image {
                anchors.fill: parent
                visible: !hero.wallpaperIsColour && hero.wallpaper !== ""
                source: visible ? "file://" + hero.wallpaper : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 640
                asynchronous: true
                cache: true
            }
            // a hint of the bar so it reads as "your desktop"
            Rectangle {
                width: parent.width
                height: Math.max(3, parent.height * 0.035)
                color: Theme.withAlpha(Theme.surfaceContainer, 0.9)
            }
            Image {
                anchors.fill: parent
                source: Laptop.dataUrl(Laptop.glareSvg())
                sourceSize.width: 400
            }
        }

        // Keyboard backlight: white glow mask painted once, tinted on the GPU.
        Canvas {
            id: keyMask
            anchors.fill: parent
            visible: false
            renderStrategy: Canvas.Cooperative
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.scale(hero.s, hero.s);
                const light = hero.lightChassis;
                const ks = Laptop.keys();
                for (let i = 0; i < ks.length; i++) {
                    const p = ks[i].pts;
                    ctx.beginPath();
                    ctx.moveTo(p[0][0], p[0][1]);
                    ctx.lineTo(p[1][0], p[1][1]);
                    ctx.lineTo(p[2][0], p[2][1]);
                    ctx.lineTo(p[3][0], p[3][1]);
                    ctx.closePath();
                    ctx.shadowColor = "rgba(255,255,255,0.9)";
                    ctx.shadowBlur = 5;
                    ctx.strokeStyle = light ? "rgba(255,255,255,0.45)" : "rgba(255,255,255,0.65)";
                    ctx.lineWidth = 0.9;
                    ctx.stroke();
                    ctx.shadowBlur = 0;
                    ctx.fillStyle = light ? "rgba(255,255,255,0.2)" : "rgba(255,255,255,0.13)";
                    ctx.fill();
                    const cx = (p[0][0] + p[1][0] + p[2][0] + p[3][0]) / 4;
                    const cy = (p[0][1] + p[1][1] + p[2][1] + p[3][1]) / 4;
                    const w = Math.min(4.5, (p[1][0] - p[0][0]) * 0.34);
                    ctx.shadowColor = "rgba(255,255,255,1)";
                    ctx.shadowBlur = 2.5;
                    ctx.fillStyle = "rgba(255,255,255,1)";
                    ctx.fillRect(cx - w / 2, cy - 1.1, w, 2.2);
                }
            }
        }

        // Tint the mask in strips: one strip for uniform effects, 16 columns (or
        // 6 rows) for Wave, each with its own hue. All GPU, no repaints.
        Item {
            id: kbTint
            anchors.fill: parent
            visible: hero.kbLevel > 0
            opacity: (0.4 + 0.6 * hero.kbLevel) * hero.kbPulse
            readonly property bool wave: hero.ctl.kbMode === 3
            readonly property bool vertical: hero.ctl.kbDirection === "Up" || hero.ctl.kbDirection === "Down"
            readonly property int strips: wave ? (vertical ? 6 : 16) : 1
            readonly property real dirSign: (hero.ctl.kbDirection === "Left" || hero.ctl.kbDirection === "Up") ? 1 : -1

            Repeater {
                model: kbTint.strips
                Item {
                    required property int index
                    readonly property real sw: kbTint.vertical && kbTint.wave ? kbTint.width : kbTint.width / kbTint.strips
                    readonly property real sh: kbTint.vertical && kbTint.wave ? kbTint.height / kbTint.strips : kbTint.height
                    x: kbTint.vertical && kbTint.wave ? 0 : index * sw
                    y: kbTint.vertical && kbTint.wave ? index * sh : 0
                    width: sw
                    height: sh
                    ShaderEffectSource {
                        id: strip
                        anchors.fill: parent
                        visible: false
                        sourceItem: keyMask
                        sourceRect: Qt.rect(parent.x, parent.y, parent.width, parent.height)
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: strip
                        colorization: 1.0
                        colorizationColor: kbTint.wave
                            ? Qt.hsva((((hero.phase * hero.speedMul * 0.15 * kbTint.dirSign) + index / kbTint.strips) % 1 + 1) % 1, 1, 1, 1)
                            : hero.uniformColour
                    }
                }
            }
        }
    }

    // ── Lid from above with the Slash strip ──────────────────────────
    Item {
        id: lidView
        visible: hero.ctl.hasSlash
        width: Math.min(hero.width > 600 ? 260 : 150, hero.width - front.width - Theme.spacingL)
        height: width * Laptop.LID_H / Laptop.LID_W
        anchors.right: parent.right
        y: front.y + (front.height - height - lidLabel.height) / 2
        readonly property real ls: width / Laptop.LID_W

        Image {
            anchors.fill: parent
            source: Laptop.dataUrl(Laptop.lidSvg(hero.chassis))
            sourceSize.width: Math.round(lidView.width * 2)
            smooth: true
            mipmap: true
        }

        // All LED segments: dim "off" dashes (always) + a white mask for the lit state.
        Canvas {
            id: slashMask
            anchors.fill: parent
            visible: false
            renderStrategy: Canvas.Cooperative
            property bool dim: false
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.scale(lidView.ls, lidView.ls);
                const S = Laptop.SLASH;
                const ang = Math.atan2(S.y2 - S.y1, S.x2 - S.x1);
                const segs = Laptop.slashSegments();
                for (let i = 0; i < segs.length; i++) {
                    ctx.save();
                    ctx.translate(segs[i].x, segs[i].y);
                    ctx.rotate(ang + Math.PI / 3.2);
                    ctx.shadowColor = "rgba(255,255,255,1)";
                    ctx.shadowBlur = 5;
                    ctx.fillStyle = "white";
                    ctx.fillRect(-3.2, -0.9, 6.4, 1.8);
                    ctx.restore();
                }
            }
        }
        MultiEffect {   // unlit LEDs
            anchors.fill: parent
            source: slashMask
            colorization: 1.0
            colorizationColor: "#808084"
            opacity: hero.ctl.slashEnabled ? 0.15 : 0.35
        }

        // Lit LEDs: the mask cut into strips along the bar, each faded by the pattern.
        Item {
            id: slashLit
            anchors.fill: parent
            visible: hero.ctl.slashEnabled
            opacity: 0.3 + 0.7 * hero.ctl.slashBrightness / 255
            readonly property string mode: hero.ctl.slashModeName(hero.ctl.slashMode)
            readonly property real t: hero.phase * (1.4 - hero.ctl.slashInterval * 0.18)
            readonly property real head: mode === "Bounce" ? (Math.sin(t * 1.3) + 1) / 2 : (t * 0.45) % 1
            readonly property int strips: 18
            readonly property real x0: Laptop.SLASH.x1 * lidView.ls - 4
            readonly property real x1: Laptop.SLASH.x2 * lidView.ls + 4
            function lit(pos) {
                if (mode === "Static")
                    return 1;
                if (mode === "Loading" || mode === "Ramp")
                    return pos <= head ? 1 : 0;
                if (mode === "Bounce")
                    return Math.max(0, 1 - Math.abs(pos - head) * 5);
                return Math.max(0, (Math.sin(t * 2.4 - pos * 12) + 1) / 2);
            }
            Repeater {
                model: slashLit.strips
                ShaderEffectSource {
                    required property int index
                    readonly property real sw: (slashLit.x1 - slashLit.x0) / slashLit.strips
                    x: slashLit.x0 + index * sw
                    y: 0
                    width: sw
                    height: slashLit.height
                    sourceItem: slashMask
                    sourceRect: Qt.rect(x, y, width, height)
                    opacity: slashLit.lit((index + 0.5) / slashLit.strips)
                }
            }
        }
    }
    StyledText {
        id: lidLabel
        visible: hero.ctl.hasSlash
        anchors.top: lidView.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: lidView.horizontalCenter
        text: hero.ctl.slashEnabled ? "Slash · " + hero.ctl.slashModeName(hero.ctl.slashMode) : "Slash off"
        font.pixelSize: Theme.fontSizeSmall - 1
        color: Theme.surfaceVariantText
    }
}
