pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets as DCommon
import "Modes.js" as Modes

// Popout / Control Center detail: modes, then each daemon's settings.
// Everything shown is read back from the daemons; changing a setting by hand
// marks the active mode as modified.
Column {
    id: root

    readonly property var z: Zephyrus

    width: 440
    spacing: Theme.spacingL

    component Title: StyledText {
        width: parent.width
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.surfaceVariantText
    }

    component Note: StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    // Writes after the slider settles, not on every step.
    component Limit: Column {
        id: limit
        required property string attr
        required property string label
        property string unit: " W"
        readonly property var info: root.z.armoury[attr]
        visible: !!info && info.max > info.min
        width: parent.width
        spacing: 2

        StyledText {
            text: limit.label + (limit.info ? "  " + limit.info.current + limit.unit.trim() : "")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
        }
        DankSlider {
            id: slider
            width: parent.width
            minimum: limit.info?.min ?? 0
            maximum: limit.info?.max ?? 1
            step: limit.info?.step ?? 1
            value: limit.info?.current ?? 0
            unit: limit.unit
            onSliderValueChanged: newValue => write.restart()
        }
        Timer {
            id: write
            interval: 400
            onTriggered: root.z.tweak(() => root.z.setLimit(limit.attr, slider.value))
        }
    }

    // ── Modes ────────────────────────────────────────────────────────
    Column {
        width: parent.width
        spacing: Theme.spacingS

        Row {
            width: parent.width
            spacing: Theme.spacingS

            Repeater {
                model: root.z.modes

                StyledRect {
                    id: tile
                    required property var modelData
                    readonly property bool active: root.z.activeMode === modelData.id
                    width: (root.width - Theme.spacingS * (root.z.modes.length - 1)) / root.z.modes.length
                    height: 64
                    radius: Theme.cornerRadius
                    color: active ? Theme.primary : Theme.surfaceContainerHigh

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        DankIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: tile.modelData.icon
                            size: Theme.iconSize
                            color: tile.active ? Theme.primaryText : Theme.surfaceText
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.name
                            font.pixelSize: Theme.fontSizeSmall
                            color: tile.active ? Theme.primaryText : Theme.surfaceText
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.z.selectMode(tile.modelData.id)
                    }
                }
            }
        }

        Note {
            text: (root.z.activeModeInfo?.description ?? "") + "\nOn AC: " + (Modes.byId(root.z.modeFor("ac"))?.name ?? "?") + " · on battery: " + (Modes.byId(root.z.modeFor("battery"))?.name ?? "?") + (root.z.modified ? " · changed by hand, the next plug/unplug restores the mode" : "")
        }
    }

    // ── Graphics (cardwire) ──────────────────────────────────────────
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.z.cardwireUp

        Title {
            text: "GRAPHICS"
        }
        DankButtonGroup {
            id: gpuGroup
            readonly property var values: root.z.gpuModes
            model: values.map(v => Modes.GPU_NAMES[v] ?? String(v))
            currentIndex: values.indexOf(root.z.gpuMode)
            enabled: !root.z.gpuSwitching
            onSelectionChanged: (index, selected) => {
                if (selected && values[index] !== root.z.gpuMode)
                    root.z.tweak(() => root.z.setGpuMode(values[index]));
            }
        }
        Note {
            text: {
                const parts = [];
                if (root.z.muxCapable)
                    parts.push("panel on " + (root.z.panelGpu === "dgpu" ? "dGPU" : "iGPU") + (root.z.muxState && root.z.muxState !== "idle" ? " (" + root.z.muxState + ")" : ""));
                if (root.z.dgpuPower)
                    parts.push((root.z.dgpuName || "dGPU") + ": " + (root.z.dgpuAwake ? "awake, " : "asleep, ") + root.z.dgpuPower);
                if (root.z.gpuSwitching)
                    parts.push("switching…");
                return parts.join("\n") + (root.z.muxError ? "\n" + root.z.muxError : "");
            }
        }
        DankButton {
            visible: root.z.muxState === "pending"
            text: "Move the panel to the dGPU now"
            onClicked: root.z.applyPendingMux()
        }
    }

    // ── Power (asusd) ────────────────────────────────────────────────
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.z.asusdUp

        Title {
            text: "POWER"
        }
        DankButtonGroup {
            readonly property var values: root.z.profileChoices
            model: values.map(v => ({
                        "text": Modes.PROFILE_NAMES[v] ?? String(v),
                        "icon": Modes.PROFILE_ICONS[v] ?? ""
                    }))
            currentIndex: values.indexOf(root.z.profile)
            onSelectionChanged: (index, selected) => {
                if (selected && values[index] !== root.z.profile)
                    root.z.tweak(() => root.z.setProfile(values[index]));
            }
        }

        StyledText {
            text: "Charge limit  " + root.z.chargeLimit + "%"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
        }
        Row {
            width: parent.width
            spacing: Theme.spacingS
            DankSlider {
                id: charge
                width: parent.width - fullCharge.width - Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                minimum: 20
                maximum: 100
                step: 5
                value: root.z.chargeLimit
                unit: "%"
                onSliderValueChanged: newValue => chargeWrite.restart()
                Timer {
                    id: chargeWrite
                    interval: 400
                    onTriggered: root.z.setChargeLimit(charge.value)
                }
            }
            DankButton {
                id: fullCharge
                anchors.verticalCenter: parent.verticalCenter
                text: "Full once"
                variant: "tonal"
                tooltipText: "Charge to 100% this time, then back to the limit"
                onClicked: root.z.fullChargeOnce()
            }
        }
    }

    // ── Limits (asus-armoury) ────────────────────────────────────────
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: Object.keys(root.z.armoury).length > 0

        Title {
            text: "LIMITS (" + (root.z.onBattery ? "battery" : "AC") + ")"
        }
        Limit {
            attr: "ppt_pl1_spl"
            label: "CPU sustained (SPL)"
        }
        Limit {
            attr: "ppt_pl2_sppt"
            label: "CPU short boost (SPPT)"
        }
        Limit {
            attr: "ppt_pl3_fppt"
            label: "CPU fast boost (FPPT)"
        }
        Limit {
            attr: "nv_tgp"
            label: "dGPU power (TGP)"
        }
        Limit {
            attr: "nv_dynamic_boost"
            label: "dGPU dynamic boost"
        }
        Limit {
            attr: "nv_temp_target"
            label: "dGPU temperature target"
            unit: " °C"
        }
        Note {
            text: "Limits that can't change right now (e.g. dGPU power on battery) are hidden."
        }
    }

    // ── Fans (asusd) ─────────────────────────────────────────────────
    Column {
        id: fans
        width: parent.width
        spacing: Theme.spacingS
        visible: root.z.hasFans && root.z.profile >= 0

        readonly property var curves: root.z.fanCurves[root.z.profile] ?? []

        Title {
            text: "FANS"
        }
        Row {
            width: parent.width
            spacing: Theme.spacingS
            DankToggle {
                width: parent.width - reset.width - Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                text: "Custom curves for " + (Modes.PROFILE_NAMES[root.z.profile] ?? "this profile")
                description: "Off: the firmware's curve for the profile"
                checked: fans.curves.length > 0 && fans.curves.every(c => c.enabled)
                onToggled: checked => root.z.setFanCurvesEnabled(root.z.profile, checked)
            }
            DankButton {
                id: reset
                anchors.verticalCenter: parent.verticalCenter
                text: "Reset"
                variant: "tonal"
                tooltipText: "Set this profile's curves back to the firmware defaults"
                onClicked: root.z.resetFanCurves(root.z.profile)
            }
        }
    }

    // ── Keyboard (asusd Aura) ────────────────────────────────────────
    Column {
        id: kb
        width: parent.width
        spacing: Theme.spacingS
        visible: root.z.auraPath !== ""

        readonly property var brightnessNames: ["Off", "Low", "Medium", "High"]
        readonly property var modeNames: ({
                "0": "Static",
                "1": "Breathe",
                "2": "Cycle",
                "3": "Wave",
                "10": "Pulse"
            })
        readonly property var swatches: ["#ffffff", "#ff2a2a", "#ff8a00", "#ffd400", "#2aff5c", "#00c8ff", "#3a5bff", "#c040ff"]

        Title {
            text: "KEYBOARD"
        }
        DankButtonGroup {
            readonly property var values: root.z.kbBrightnessLevels
            model: values.map(v => kb.brightnessNames[v] ?? String(v))
            currentIndex: values.indexOf(root.z.kbBrightness)
            onSelectionChanged: (index, selected) => {
                if (selected && values[index] !== root.z.kbBrightness)
                    root.z.setKbBrightness(values[index]);
            }
        }
        DankButtonGroup {
            readonly property var values: root.z.kbModes
            model: values.map(v => kb.modeNames[v] ?? String(v))
            currentIndex: values.indexOf(root.z.kbMode)
            onSelectionChanged: (index, selected) => {
                if (selected && values[index] !== root.z.kbMode)
                    root.z.setKbMode(values[index]);
            }
        }
        Row {
            spacing: Theme.spacingS
            visible: !!root.z.kbModeData
            Repeater {
                model: kb.swatches
                DCommon.DColorButton {
                    required property string modelData
                    swatchColor: modelData
                    selected: {
                        const c = root.z.kbModeData?.[2];
                        if (!c)
                            return false;
                        const s = Qt.color(modelData);
                        return Math.round(s.r * 255) === c[0] && Math.round(s.g * 255) === c[1] && Math.round(s.b * 255) === c[2];
                    }
                    onClicked: root.z.setKbColour(Qt.color(modelData))
                }
            }
        }
    }

    Note {
        visible: !root.z.busReady || !root.z.asusdUp || !root.z.cardwireUp
        color: Theme.error
        text: !root.z.busReady ? "Not connected to the DMS backend (D-Bus bridge)." : [!root.z.asusdUp ? "asusd is not running." : "", !root.z.cardwireUp ? "cardwired is not running." : ""].filter(s => s).join(" ")
    }
}
