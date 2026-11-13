import QtQuick
import qs.Common
import qs.Widgets

// 8-point fan curve graph. X = temperature (°C), Y = fan duty (PWM 0-255 shown as %).
// Points are draggable; each stays between its neighbours so the curve never
// decreases in temperature or speed.
Item {
    id: ed
    property var temps: [30, 40, 50, 60, 70, 80, 90, 100]
    property var pwms: [0, 30, 60, 90, 120, 160, 200, 255]
    property color accent: Theme.primary
    property bool active: true            // curve enabled in firmware
    property bool editable: true
    readonly property int tMin: 20
    readonly property int tMax: 100
    signal edited(var temps, var pwms)

    width: parent ? parent.width : 300
    height: 190

    readonly property real padL: 34
    readonly property real padB: 22
    readonly property real padT: 8
    readonly property real padR: 18
    readonly property real gw: width - padL - padR
    readonly property real gh: height - padT - padB

    function xOf(t) { return padL + (t - tMin) / (tMax - tMin) * gw; }
    function yOf(p) { return padT + (1 - p / 255) * gh; }
    function tAt(x) { return Math.round(tMin + (x - padL) / gw * (tMax - tMin)); }
    function pAt(y) { return Math.round((1 - (y - padT) / gh) * 255); }

    onTempsChanged: canvas.requestPaint()
    onPwmsChanged: canvas.requestPaint()
    onAccentChanged: canvas.requestPaint()
    onActiveChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const grid = Theme.withAlpha(Theme.surfaceVariantText, 0.18);
            ctx.strokeStyle = grid;
            ctx.lineWidth = 1;
            ctx.fillStyle = Theme.surfaceVariantText;
            ctx.font = "10px sans-serif";
            for (let p = 0; p <= 100; p += 25) {
                const y = ed.yOf(p * 2.55);
                ctx.beginPath(); ctx.moveTo(ed.padL, y); ctx.lineTo(ed.width - ed.padR, y); ctx.stroke();
                ctx.fillText(p + "%", 2, y + 3);
            }
            for (let t = ed.tMin; t <= ed.tMax; t += 20) {
                const x = ed.xOf(t);
                ctx.beginPath(); ctx.moveTo(x, ed.padT); ctx.lineTo(x, ed.padT + ed.gh); ctx.stroke();
                ctx.fillText(t + "°", x - 8, ed.height - 6);
            }
            const col = ed.active ? ed.accent : Theme.surfaceVariantText;
            // fill under curve
            ctx.beginPath();
            ctx.moveTo(ed.xOf(ed.temps[0]), ed.yOf(0));
            for (let i = 0; i < 8; i++)
                ctx.lineTo(ed.xOf(ed.temps[i]), ed.yOf(ed.pwms[i]));
            ctx.lineTo(ed.xOf(ed.temps[7]), ed.yOf(0));
            ctx.closePath();
            ctx.fillStyle = Theme.withAlpha(col, 0.15);
            ctx.fill();
            // curve
            ctx.beginPath();
            for (let i = 0; i < 8; i++) {
                const x = ed.xOf(ed.temps[i]), y = ed.yOf(ed.pwms[i]);
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
            }
            ctx.strokeStyle = col;
            ctx.lineWidth = 2;
            ctx.stroke();
        }
    }

    Repeater {
        model: 8
        Rectangle {
            id: handle
            required property int index
            readonly property bool hot: dragArea.containsMouse || dragArea.pressed
            width: hot ? 16 : 12
            height: width
            radius: width / 2
            x: ed.xOf(ed.temps[index]) - width / 2
            y: ed.yOf(ed.pwms[index]) - height / 2
            color: ed.active ? ed.accent : Theme.surfaceVariantText
            border.width: 2
            border.color: Theme.surfaceContainerHigh
            Behavior on width { NumberAnimation { duration: 80 } }

            StyledText {
                visible: handle.hot
                text: ed.temps[handle.index] + "° · " + Math.round(ed.pwms[handle.index] / 2.55) + "%"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.bottom: parent.top
                anchors.bottomMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                enabled: ed.editable
                cursorShape: ed.editable ? Qt.SizeAllCursor : Qt.ArrowCursor
                preventStealing: true
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    const p = mapToItem(ed, mouse.x, mouse.y);
                    const i = handle.index;
                    const t = ed.temps.slice(), w = ed.pwms.slice();
                    const tLo = i > 0 ? t[i - 1] : ed.tMin, tHi = i < 7 ? t[i + 1] : ed.tMax;
                    const pLo = i > 0 ? w[i - 1] : 0, pHi = i < 7 ? w[i + 1] : 255;
                    t[i] = Math.max(tLo, Math.min(tHi, ed.tAt(p.x)));
                    w[i] = Math.max(pLo, Math.min(pHi, ed.pAt(p.y)));
                    ed.temps = t;
                    ed.pwms = w;
                }
                onReleased: ed.edited(ed.temps, ed.pwms)
            }
        }
    }
}
