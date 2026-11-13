import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: tab
    required property var ctl
    width: parent ? parent.width : 0
    spacing: Theme.spacingM

    readonly property var choices: ctl.profileChoicesSorted

    component ProfilePicker: Row {
        id: picker
        property int current: -1
        signal picked(int profile)
        width: parent ? parent.width : 0
        spacing: Theme.spacingS
        Repeater {
            model: tab.choices
            Chip {
                required property var modelData
                width: (picker.width - picker.spacing * (tab.choices.length - 1)) / Math.max(1, tab.choices.length)
                icon: tab.ctl.profileIcon(modelData)
                text: tab.ctl.profileName(modelData)
                selected: picker.current === modelData
                onClicked: picker.picked(modelData)
            }
        }
    }

    // ── Active profile ───────────────────────────────────────────────
    SectionCard {
        visible: tab.ctl.hasPlatform
        title: "Profile"
        icon: "speed"
        subtitle: "Now: " + tab.ctl.profileName(tab.ctl.platformProfile) + (tab.ctl.onAc ? " · on AC" : " · on battery")

        ProfilePicker {
            current: tab.ctl.platformProfile
            onPicked: p => tab.ctl.setPlatform("PlatformProfile", "u", p)
        }

        // Auto switching on power source change
        Repeater {
            model: [
                { label: "On AC power", icon: "power", prop: "PlatformProfileOnAc", toggle: "ChangePlatformProfileOnAc" },
                { label: "On battery", icon: "battery_std", prop: "PlatformProfileOnBattery", toggle: "ChangePlatformProfileOnBattery" }
            ]
            Column {
                id: autoCol
                required property var modelData
                width: parent.width
                spacing: Theme.spacingXS
                Item {
                    width: parent.width
                    height: autoToggle.height
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS
                        DankIcon { name: autoCol.modelData.icon; size: Theme.iconSizeSmall; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                        SubLabel { text: autoCol.modelData.label + ": switch automatically"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    DankToggle {
                        id: autoToggle
                        anchors.right: parent.right
                        hideText: true
                        checked: tab.ctl.platform[autoCol.modelData.toggle] === true
                        onToggled: checked => tab.ctl.setPlatform(autoCol.modelData.toggle, "b", checked)
                    }
                }
                ProfilePicker {
                    visible: tab.ctl.platform[autoCol.modelData.toggle] === true
                    current: tab.ctl.platform[autoCol.modelData.prop] ?? -1
                    onPicked: p => tab.ctl.setPlatform(autoCol.modelData.prop, "u", p)
                }
            }
        }
    }

    // ── Energy performance preference ────────────────────────────────
    SectionCard {
        visible: tab.ctl.hasPlatform && tab.ctl.platform.PlatformProfileLinkedEpp !== undefined
        title: "CPU energy preference"
        collapsedByDefault: true
        icon: "energy_program_saving"
        trailing: Component {
            DankToggle {
                hideText: true
                checked: tab.ctl.platform.PlatformProfileLinkedEpp === true
                onToggled: checked => tab.ctl.setPlatform("PlatformProfileLinkedEpp", "b", checked)
            }
        }

        Hint { text: "When on, each profile also sets the CPU's EPP (amd-pstate / intel_pstate energy preference)." }

        Repeater {
            model: tab.ctl.platform.PlatformProfileLinkedEpp === true ? tab.ctl.eppProps : []
            Column {
                id: eppCol
                required property var modelData
                width: parent.width
                spacing: Theme.spacingXS
                SubLabel { text: eppCol.modelData.label }
                DankDropdown {
                    id: eppDrop
                    width: parent.width
                    dropdownWidth: parent.width
                    options: tab.ctl.eppNames
                    onValueChanged: value => {
                        const i = tab.ctl.eppNames.indexOf(value);
                        if (i >= 0 && i !== tab.ctl.platform[eppCol.modelData.prop])
                            tab.ctl.setPlatform(eppCol.modelData.prop, "u", i);
                    }
                }
                Binding {
                    target: eppDrop
                    property: "currentValue"
                    value: tab.ctl.eppNames[tab.ctl.platform[eppCol.modelData.prop]] || ""
                }
            }
        }
    }

    // ── Tuning: CPU PPT + NVIDIA limits ──────────────────────────────
    SectionCard {
        visible: tab.ctl.tuningAttrs.length > 0
        title: "Power limits"
        icon: "tune"
        subtitle: "Tuning for " + tab.ctl.profileName(tab.ctl.platformProfile) + (tab.ctl.onAc ? " on AC" : " on battery")
        trailing: Component {
            DankToggle {
                hideText: true
                enabled: tab.ctl.tuningEnabled || tab.ctl.activeProfileHasCustomFans
                checked: tab.ctl.tuningEnabled
                onToggled: checked => tab.ctl.setTuning(checked)
            }
        }

        Hint {
            visible: !tab.ctl.tuningEnabled
            text: tab.ctl.activeProfileHasCustomFans
                ? "Enable tuning to override the firmware's CPU/GPU power limits for this profile."
                : "asusd needs a custom fan curve enabled for the active profile before power limits can be tuned (Fans tab)."
        }

        Repeater {
            model: tab.ctl.tuningAttrs
            Column {
                id: attrCol
                required property var modelData
                width: parent.width
                AttrSlider {
                    visible: attrCol.modelData.range
                    enabled: tab.ctl.tuningEnabled
                    label: attrCol.modelData.label
                    unit: attrCol.modelData.unit
                    minimum: attrCol.modelData.min
                    maximum: attrCol.modelData.max
                    step: Math.max(1, attrCol.modelData.step)
                    value: attrCol.modelData.value
                    defaultValue: attrCol.modelData.def
                    onCommitted: v => tab.ctl.setArmoury(attrCol.modelData.attr, v)
                    onResetRequested: tab.ctl.restoreArmoury(attrCol.modelData.attr)
                }
                // read-only values (e.g. base TGP)
                Item {
                    visible: !attrCol.modelData.range
                    width: parent.width
                    height: roText.implicitHeight
                    SubLabel { text: attrCol.modelData.label }
                    StyledText {
                        id: roText
                        anchors.right: parent.right
                        text: attrCol.modelData.value + " " + attrCol.modelData.unit
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }
                }
            }
        }
    }

    // ── NVIDIA ───────────────────────────────────────────────────────
    SectionCard {
        visible: tab.ctl.hasPlatform && tab.ctl.platform.DisableNvidiaPowerdOnBattery !== undefined
        title: "NVIDIA"
        collapsedByDefault: true
        icon: "developer_board"
        DankToggle {
            width: parent.width
            text: "Stop nvidia-powerd on battery"
            description: "Saves power by disabling Dynamic Boost's daemon when unplugged."
            checked: tab.ctl.platform.DisableNvidiaPowerdOnBattery === true
            onToggled: checked => tab.ctl.setPlatform("DisableNvidiaPowerdOnBattery", "b", checked)
        }
    }
}
