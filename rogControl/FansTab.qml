import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: tab
    required property var ctl
    width: parent ? parent.width : 0
    spacing: Theme.spacingM

    property int profile: -1
    property int fanIndex: 0
    property var draftTemps: null
    property var draftPwms: null
    property bool confirmReset: false

    readonly property int effectiveProfile: profile >= 0 ? profile : ctl.platformProfile
    readonly property var curves: ctl.fanCurvesFor(effectiveProfile)
    readonly property var curve: curves[Math.min(fanIndex, curves.length - 1)] || null
    readonly property bool dirty: draftTemps !== null
    readonly property bool anyEnabled: curves.some(c => c[3] === true)

    function discard() {
        draftTemps = null;
        draftPwms = null;
    }
    onEffectiveProfileChanged: discard()
    onFanIndexChanged: discard()

    Timer {
        id: confirmTimer
        interval: 4000
        onTriggered: tab.confirmReset = false
    }

    SectionCard {
        visible: tab.ctl.hasFans
        title: "Fan curves"
        icon: "mode_fan"
        subtitle: tab.anyEnabled ? "Custom curves active for " + tab.ctl.profileName(tab.effectiveProfile) : "Firmware default curves for " + tab.ctl.profileName(tab.effectiveProfile)
        trailing: Component {
            DankToggle {
                hideText: true
                checked: tab.anyEnabled
                onToggled: checked => tab.ctl.setFanCurvesEnabled(tab.effectiveProfile, checked)
            }
        }

        // Profile picker
        Row {
            id: profRow
            width: parent.width
            spacing: Theme.spacingS
            Repeater {
                model: tab.ctl.profileChoicesSorted
                Chip {
                    required property var modelData
                    width: (profRow.width - profRow.spacing * (tab.ctl.profileChoicesSorted.length - 1)) / Math.max(1, tab.ctl.profileChoicesSorted.length)
                    icon: tab.ctl.profileIcon(modelData)
                    text: tab.ctl.profileName(modelData) + (modelData === tab.ctl.platformProfile ? " •" : "")
                    selected: tab.effectiveProfile === modelData
                    onClicked: tab.profile = modelData
                }
            }
        }

        // Fan picker with per-fan enable
        Row {
            id: fanRow
            width: parent.width
            spacing: Theme.spacingS
            Repeater {
                model: tab.curves
                Chip {
                    required property var modelData
                    required property int index
                    width: (fanRow.width - fanRow.spacing * (tab.curves.length - 1)) / Math.max(1, tab.curves.length)
                    icon: modelData[3] ? "check_circle" : "radio_button_unchecked"
                    text: tab.ctl.fanName(modelData[0])
                    selected: tab.fanIndex === index
                    onClicked: tab.fanIndex = index
                }
            }
        }

        FanCurveEditor {
            id: editor
            visible: tab.curve !== null
            pwms: tab.draftPwms || (tab.curve ? tab.curve[1] : [])
            temps: tab.draftTemps || (tab.curve ? tab.curve[2] : [])
            active: tab.curve ? tab.curve[3] : false
            onEdited: (t, p) => {
                tab.draftTemps = t.slice();
                tab.draftPwms = p.slice();
            }
        }

        Item {
            width: parent.width
            height: fanEnable.height
            visible: tab.curve !== null
            DankToggle {
                id: fanEnable
                text: "Use this curve for " + (tab.curve ? tab.ctl.fanName(tab.curve[0]) : "")
                checked: tab.curve ? tab.curve[3] : false
                onToggled: checked => tab.ctl.setFanCurveEnabled(tab.effectiveProfile, tab.curve[0], checked)
            }
        }

        Row {
            spacing: Theme.spacingS
            DankButton {
                text: "Apply"
                iconName: "check"
                enabled: tab.dirty
                opacity: enabled ? 1 : 0.5
                onClicked: {
                    tab.ctl.setFanCurve(tab.effectiveProfile, tab.curve[0], tab.draftPwms, tab.draftTemps, true);
                    tab.discard();
                }
            }
            DankButton {
                text: "Revert"
                iconName: "undo"
                enabled: tab.dirty
                opacity: enabled ? 1 : 0.5
                backgroundColor: Theme.surfaceContainerHighest
                textColor: Theme.surfaceText
                onClicked: tab.discard()
            }
            DankButton {
                text: tab.confirmReset ? "Confirm reset" : "Defaults"
                iconName: "restart_alt"
                backgroundColor: tab.confirmReset ? Theme.error : Theme.surfaceContainerHighest
                textColor: tab.confirmReset ? "white" : Theme.surfaceText
                onClicked: {
                    if (!tab.confirmReset) {
                        tab.confirmReset = true;
                        confirmTimer.restart();
                        return;
                    }
                    tab.confirmReset = false;
                    tab.discard();
                    tab.ctl.resetFanCurves(tab.effectiveProfile);
                }
            }
        }

        Hint {
            text: "Drag points to shape the curve, then Apply (this also enables it). Defaults restores the firmware curves for all fans of this profile. A custom curve on the active profile is required for Power limits tuning."
        }
    }

    Hint {
        visible: !tab.ctl.hasFans
        text: "asusd reports no fan-curve support on this model."
    }
}
