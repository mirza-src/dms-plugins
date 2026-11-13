import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: tab
    required property var ctl
    width: parent ? parent.width : 0
    spacing: Theme.spacingM

    // ── Keyboard ─────────────────────────────────────────────────────
    SectionCard {
        visible: tab.ctl.hasKeyboard
        title: "Keyboard"
        icon: "keyboard"
        trailing: Component {
            DankToggle {
                hideText: true
                checked: tab.ctl.kbOn
                onToggled: tab.ctl.toggleKeyboard()
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS
            SubLabel { text: "Brightness" }
            DankButtonGroup {
                size: "small"
                model: tab.ctl.kbSupportedBrightness.map(l => tab.ctl.brightnessNames[l] || String(l))
                currentIndex: tab.ctl.kbSupportedBrightness.indexOf(tab.ctl.kbBrightness)
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        tab.ctl.setKbBrightness(tab.ctl.kbSupportedBrightness[index]);
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS
            SubLabel { text: "Effect" }
            Grid {
                id: modeGrid
                width: parent.width
                columns: 3
                spacing: Theme.spacingS
                Repeater {
                    model: tab.ctl.kbSupportedModes
                    Chip {
                        required property var modelData
                        width: (modeGrid.width - modeGrid.spacing * (modeGrid.columns - 1)) / modeGrid.columns
                        icon: (tab.ctl.modeInfo[modelData] || {}).icon || "keyboard"
                        text: (tab.ctl.modeInfo[modelData] || {}).name || ("Mode " + modelData)
                        selected: tab.ctl.kbMode === modelData
                        onClicked: tab.ctl.applyEffect({ mode: modelData })
                    }
                }
            }
        }

        Column {
            visible: tab.ctl.currentModeInfo.colours > 0
            width: parent.width
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingM
                ColourButton {
                    label: tab.ctl.currentModeInfo.colours > 1 ? "Colour 1" : "Colour"
                    value: tab.ctl.kbDisplayColour1
                    onPicked: c => tab.ctl.applyEffect({ colour1: c })
                }
                ColourButton {
                    visible: tab.ctl.currentModeInfo.colours > 1
                    label: "Colour 2"
                    value: tab.ctl.kbDisplayColour2
                    onPicked: c => tab.ctl.applyEffect({ colour2: c })
                }
            }

            Row {
                spacing: Theme.spacingS
                Repeater {
                    model: [Theme.primary, Theme.secondary, Theme.tertiary, "#ffffff", "#ff0033", "#ff7a00", "#00e5ff", "#b000ff"]
                    Rectangle {
                        required property var modelData
                        readonly property bool current: tab.ctl.hex(color) === tab.ctl.hex(tab.ctl.kbDisplayColour1)
                        width: 28
                        height: 28
                        radius: 14
                        color: modelData
                        border.width: current ? 3 : 1
                        border.color: current ? Theme.surfaceText : Theme.outlineStrong
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tab.ctl.applyEffect({ colour1: parent.color })
                        }
                    }
                }
            }

            Hint {
                visible: tab.ctl.followTheme
                text: "Following the DMS theme accent: colours update when the wallpaper palette changes."
            }
        }

        Column {
            visible: tab.ctl.currentModeInfo.speed
            width: parent.width
            spacing: Theme.spacingXS
            SubLabel { text: "Speed" }
            DankButtonGroup {
                size: "small"
                model: tab.ctl.speeds
                currentIndex: tab.ctl.speeds.indexOf(tab.ctl.kbSpeed)
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        tab.ctl.applyEffect({ speed: tab.ctl.speeds[index] });
                }
            }
        }

        Column {
            visible: tab.ctl.currentModeInfo.dir
            width: parent.width
            spacing: Theme.spacingXS
            SubLabel { text: "Direction" }
            DankButtonGroup {
                size: "small"
                model: tab.ctl.directions
                currentIndex: tab.ctl.directions.indexOf(tab.ctl.kbDirection)
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        tab.ctl.applyEffect({ direction: tab.ctl.directions[index] });
                }
            }
        }

        Repeater {
            model: tab.ctl.kbPowerZones
            Column {
                id: zoneCol
                required property var modelData
                width: parent.width
                spacing: Theme.spacingXS
                SubLabel { text: "Lit during · " + (tab.ctl.powerZoneNames[zoneCol.modelData] || ("Zone " + zoneCol.modelData)) }
                Row {
                    id: powerRow
                    width: parent.width
                    spacing: Theme.spacingS
                    Repeater {
                        model: tab.ctl.powerStateNames
                        Chip {
                            required property var modelData
                            required property int index
                            width: (powerRow.width - powerRow.spacing * 3) / 4
                            text: modelData
                            selected: ((tab.ctl.kbPower[zoneCol.modelData] || [])[index]) === true
                            onClicked: tab.ctl.setKbPower(zoneCol.modelData, index, !selected)
                        }
                    }
                }
            }
        }
    }

    // ── LED colour correction ────────────────────────────────────────
    SectionCard {
        visible: tab.ctl.hasKeyboard
        title: "Colour correction"
        collapsedByDefault: true
        icon: "palette"
        subtitle: tab.ctl.correctionActive ? "Active: adjusting colours sent to the LEDs" : "Off: colours are sent as picked"
        trailing: Component {
            DankActionButton {
                visible: tab.ctl.correctionActive
                iconName: "restart_alt"
                iconColor: Theme.surfaceVariantText
                buttonSize: 28
                tooltipText: "Reset correction"
                onClicked: tab.ctl.setCorrection(100, 100)
            }
        }

        Hint {
            text: "RGB LEDs look brighter and more washed out than the colour on screen. Raise saturation to deepen colours, and gamma to darken mid-tones so pastels don't turn white."
        }

        AttrSlider {
            label: "Saturation boost"
            unit: "%"
            minimum: 100
            maximum: 300
            step: 5
            value: tab.ctl.ledSaturation
            onCommitted: v => tab.ctl.setCorrection(v, tab.ctl.ledGamma)
        }

        AttrSlider {
            label: "Gamma  (100 = linear, 220 ≈ sRGB)"
            unit: ""
            minimum: 100
            maximum: 300
            step: 5
            value: tab.ctl.ledGamma
            onCommitted: v => tab.ctl.setCorrection(tab.ctl.ledSaturation, v)
        }

        // Picked -> sent preview
        Row {
            visible: tab.ctl.currentModeInfo.colours > 0
            spacing: Theme.spacingS
            Repeater {
                model: tab.ctl.currentModeInfo.colours > 1 ? [tab.ctl.kbDisplayColour1, tab.ctl.kbDisplayColour2] : [tab.ctl.kbDisplayColour1]
                Row {
                    required property var modelData
                    spacing: Theme.spacingXS
                    Rectangle { width: 24; height: 24; radius: 12; color: modelData; border.width: 1; border.color: Theme.outlineStrong }
                    DankIcon { name: "arrow_forward"; size: 16; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 24; height: 24; radius: 12; color: tab.ctl.correct(modelData); border.width: 1; border.color: Theme.outlineStrong }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.ctl.hex(tab.ctl.correct(modelData)).toUpperCase()
                        font.family: "monospace"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        rightPadding: Theme.spacingM
                    }
                }
            }
        }
    }

    // ── Slash ledbar ─────────────────────────────────────────────────
    SectionCard {
        visible: tab.ctl.hasSlash
        title: "Slash"
        icon: "linear_scale"
        trailing: Component {
            DankToggle {
                hideText: true
                checked: tab.ctl.slashEnabled
                onToggled: checked => tab.ctl.setSlashEnabled(checked)
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS
            opacity: tab.ctl.slashEnabled ? 1 : 0.5
            SubLabel { text: "Animation" }
            DankDropdown {
                id: slashDropdown
                width: parent.width
                dropdownWidth: parent.width
                options: tab.ctl.slashModes.map(m => m.name)
                onValueChanged: value => {
                    const v = tab.ctl.slashModeValue(value);
                    if (v >= 0 && v !== tab.ctl.slashMode)
                        tab.ctl.setSlashMode(v);
                }
            }
            Binding {
                target: slashDropdown
                property: "currentValue"
                value: tab.ctl.slashModeName(tab.ctl.slashMode)
            }
        }

        AttrSlider {
            label: "Brightness"
            unit: "%"
            minimum: 0
            maximum: 100
            value: Math.round(tab.ctl.slashBrightness / 2.55)
            leftIcon: "brightness_low"
            rightIcon: "brightness_high"
            opacity: tab.ctl.slashEnabled ? 1 : 0.5
            onCommitted: v => tab.ctl.setSlashBrightness(Math.round(v * 2.55))
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS
            opacity: tab.ctl.slashEnabled ? 1 : 0.5
            SubLabel { text: "Animation interval" }
            DankButtonGroup {
                size: "small"
                model: ["0", "1", "2", "3", "4", "5"]
                currentIndex: tab.ctl.slashInterval
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        tab.ctl.setSlashInterval(index);
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS
            SubLabel { text: "Show animation on" }
            Grid {
                id: flagGrid
                width: parent.width
                columns: 3
                spacing: Theme.spacingS
                Repeater {
                    model: tab.ctl.slashFlagDefs
                    Chip {
                        required property var modelData
                        width: (flagGrid.width - flagGrid.spacing * (flagGrid.columns - 1)) / flagGrid.columns
                        icon: modelData.icon
                        text: modelData.label
                        selected: tab.ctl.slashFlags[modelData.key] === true
                        onClicked: tab.ctl.setSlashFlag(modelData.key, !selected)
                    }
                }
            }
        }
    }
}
