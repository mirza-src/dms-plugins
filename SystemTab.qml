import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: tab
    required property var ctl
    width: parent ? parent.width : 0
    spacing: Theme.spacingM

    property string confirmKey: ""
    Timer {
        id: confirmTimer
        interval: 4000
        onTriggered: tab.confirmKey = ""
    }
    // Two-tap confirmation for risky firmware switches.
    function guarded(key, needsConfirm, fn) {
        if (needsConfirm && confirmKey !== key) {
            confirmKey = key;
            confirmTimer.restart();
            return;
        }
        confirmKey = "";
        fn();
    }

    // ── Pending reboot ───────────────────────────────────────────────
    StyledRect {
        visible: tab.ctl.pendingReboot
        width: parent.width
        height: rebootRow.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.warning, 0.18)
        Row {
            id: rebootRow
            x: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS
            DankIcon { name: "restart_alt"; size: Theme.iconSize; color: Theme.warning; anchors.verticalCenter: parent.verticalCenter }
            StyledText {
                width: tab.width - Theme.spacingM * 2 - Theme.iconSize - Theme.spacingS
                wrapMode: Text.WordWrap
                text: "A firmware change is pending. Reboot to apply it."
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ── Battery ──────────────────────────────────────────────────────
    SectionCard {
        visible: tab.ctl.platform.ChargeControlEndThreshold !== undefined
        title: "Battery"
        icon: "battery_charging_full"
        subtitle: tab.ctl.powerSourceText

        AttrSlider {
            label: "Charge limit"
            unit: "%"
            minimum: 20
            maximum: 100
            value: tab.ctl.platform.ChargeControlEndThreshold || 100
            onCommitted: v => tab.ctl.setPlatform("ChargeControlEndThreshold", "y", v)
        }

        Row {
            spacing: Theme.spacingS
            Repeater {
                model: [60, 80, 100]
                Chip {
                    required property var modelData
                    width: 64
                    text: modelData + "%"
                    selected: tab.ctl.platform.ChargeControlEndThreshold === modelData
                    onClicked: tab.ctl.setPlatform("ChargeControlEndThreshold", "y", modelData)
                }
            }
            DankButton {
                text: "Charge to 100% once"
                iconName: "bolt"
                buttonHeight: 36
                backgroundColor: Theme.surfaceContainerHighest
                textColor: Theme.surfaceText
                onClicked: tab.ctl.oneShotCharge()
            }
        }
        Hint { text: "Keeping the limit at 60–80% slows battery wear. One-shot charges to full once, then returns to the limit." }
    }

    // ── GPU + firmware attributes ────────────────────────────────────
    Repeater {
        model: tab.ctl.systemAttrGroups
        SectionCard {
            id: groupCard
            required property var modelData
            title: modelData.title
            icon: modelData.icon
            stateKey: "fw:" + modelData.title

            Repeater {
                model: groupCard.modelData.attrs
                Column {
                    id: attrCol
                    required property var modelData
                    readonly property var a: modelData
                    width: parent.width
                    spacing: Theme.spacingXS

                    SubLabel { text: attrCol.a.label }
                    Hint { visible: attrCol.a.help !== ""; text: attrCol.a.help }

                    // enum → chips
                    Row {
                        id: enumRow
                        visible: attrCol.a.kind === "enum"
                        width: parent.width
                        spacing: Theme.spacingS
                        Repeater {
                            model: attrCol.a.kind === "enum" ? attrCol.a.values : []
                            Chip {
                                required property var modelData
                                readonly property string key: attrCol.a.attr + ":" + modelData.v
                                width: (enumRow.width - enumRow.spacing * (attrCol.a.values.length - 1)) / Math.max(1, attrCol.a.values.length)
                                text: tab.confirmKey === key ? "Tap to confirm" : modelData.label
                                accent: tab.confirmKey === key ? Theme.error : Theme.primary
                                selected: attrCol.a.value === modelData.v || tab.confirmKey === key
                                enabled: !attrCol.a.ro
                                onClicked: {
                                    if (attrCol.a.value === modelData.v)
                                        return;
                                    const v = modelData.v;
                                    tab.guarded(key, attrCol.a.confirm, () => tab.ctl.setArmoury(attrCol.a.attr, v));
                                }
                            }
                        }
                    }

                    AttrSlider {
                        visible: attrCol.a.kind === "range"
                        label: ""
                        unit: attrCol.a.unit
                        minimum: attrCol.a.min
                        maximum: attrCol.a.max
                        step: Math.max(1, attrCol.a.step)
                        value: attrCol.a.value
                        defaultValue: attrCol.a.def
                        onCommitted: v => tab.ctl.setArmoury(attrCol.a.attr, v)
                        onResetRequested: tab.ctl.restoreArmoury(attrCol.a.attr)
                    }

                    StyledText {
                        visible: attrCol.a.kind === "readonly"
                        text: attrCol.a.valueText
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                    }
                }
            }
        }
    }

    // ── About this laptop ────────────────────────────────────────────
    SectionCard {
        title: "This laptop"
        collapsedByDefault: true
        icon: "laptop_chromebook"

        Grid {
            columns: 2
            columnSpacing: Theme.spacingL
            rowSpacing: 4
            SubLabel { text: "Make" }
            StyledText { text: tab.ctl.vendor || "—"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
            SubLabel { text: "Model" }
            StyledText { text: tab.ctl.product || "—"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
            SubLabel { text: "Board" }
            StyledText { text: tab.ctl.board || "—"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
            SubLabel { text: "BIOS" }
            StyledText { text: tab.ctl.bios || "—"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
            SubLabel { text: "asusd" }
            StyledText { text: tab.ctl.platform.Version || "—"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS
            SubLabel { text: "Chassis colour (not reported by firmware, used for the illustration)" }
            Flow {
                width: parent.width
                spacing: Theme.spacingS
                Repeater {
                    model: tab.ctl.chassisOptions
                    Chip {
                        required property var modelData
                        width: implicitChipW.implicitWidth + 44
                        text: modelData.name
                        icon: "circle"
                        iconColor: modelData.colour
                        selected: tab.ctl.chassisName === modelData.name
                        onClicked: tab.ctl.setChassis(modelData.name)
                        StyledText { id: implicitChipW; visible: false; text: modelData.name; font.pixelSize: Theme.fontSizeSmall }
                    }
                }
            }
        }
    }
}
