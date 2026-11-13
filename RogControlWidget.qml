import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // All state and D-Bus I/O lives in the shared RogService singleton.
    readonly property var svc: RogService
    Component.onCompleted: RogService.acquire()
    Component.onDestruction: RogService.release()

    // ── Bar pill ─────────────────────────────────────────────────────
    popoutWidth: 460
    pillRightClickAction: () => svc.rightClickAction === "profile" ? svc.nextProfile() : svc.toggleKeyboard()

    horizontalBarPill: Component {
        Item {
            implicitWidth: hRow.implicitWidth
            implicitHeight: hRow.implicitHeight

            Row {
                id: hRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: svc.showProfileInBar && svc.hasPlatform
                    name: svc.profileIcon(svc.platformProfile)
                    size: root.iconSize
                    color: Theme.surfaceText
                }

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: svc.available ? "keyboard" : "keyboard_off"
                    size: root.iconSize
                    color: svc.accentColor
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    visible: svc.hasKeyboard
                    Repeater {
                        model: Math.max(0, svc.kbSupportedBrightness.length - 1)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 5 + index * 3
                            radius: 1.5
                            color: index < svc.kbBrightness ? svc.accentColor : Theme.withAlpha(Theme.surfaceVariantText, 0.3)
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                enabled: svc.scrollBrightness
                onWheel: wheel => svc.stepKbBrightness(wheel.angleDelta.y > 0 ? 1 : -1)
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: vCol.implicitWidth
            implicitHeight: vCol.implicitHeight

            Column {
                id: vCol
                anchors.centerIn: parent
                spacing: Theme.spacingXS
                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: svc.showProfileInBar && svc.hasPlatform
                    name: svc.profileIcon(svc.platformProfile)
                    size: root.iconSize
                    color: Theme.surfaceText
                }
                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: svc.available ? "keyboard" : "keyboard_off"
                    size: root.iconSize
                    color: svc.accentColor
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                enabled: svc.scrollBrightness
                onWheel: wheel => svc.stepKbBrightness(wheel.angleDelta.y > 0 ? 1 : -1)
            }
        }
    }

    // ── Control Center tile ──────────────────────────────────────────
    ccWidgetIcon: "keyboard"
    ccWidgetPrimaryText: "Keyboard light"
    ccWidgetSecondaryText: svc.kbOn ? svc.brightnessNames[svc.kbBrightness] + " · " + svc.currentModeInfo.name : "Off"
    ccWidgetIsActive: svc.kbOn
    onCcWidgetToggled: svc.toggleKeyboard()

    // ── Popout ───────────────────────────────────────────────────────
    property string currentTab: "lighting"
    readonly property var tabs: {
        const t = [];
        if (svc.hasKeyboard || svc.hasSlash)
            t.push({ key: "lighting", text: "Lighting", icon: "palette" });
        if (svc.hasPlatform)
            t.push({ key: "performance", text: "Performance", icon: "speed" });
        if (svc.hasFans)
            t.push({ key: "fans", text: "Fans", icon: "mode_fan" });
        t.push({ key: "system", text: "System", icon: "settings" });
        return t;
    }
    readonly property string activeTab: tabs.some(t => t.key === currentTab) ? currentTab : (tabs[0] ? tabs[0].key : "system")

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: svc.product || "ASUS"
            detailsText: !svc.loaded ? "Loading…"
                : !svc.available ? "asusd is not running"
                : [svc.vendor, svc.board, svc.chassisName, svc.profileName(svc.platformProfile)].filter(x => x).join(" · ")
            showCloseButton: true

            headerActions: Component {
                Row {
                    spacing: 2
                    DankActionButton {
                        iconName: svc.heroHidden ? "laptop_chromebook" : "hide_image"
                        iconColor: Theme.surfaceVariantText
                        buttonSize: 28
                        tooltipText: svc.heroHidden ? "Show laptop" : "Hide laptop"
                        onClicked: svc.saveSetting("heroHidden", !svc.heroHidden)
                    }
                    DankActionButton {
                        iconName: "refresh"
                        iconColor: Theme.surfaceVariantText
                        buttonSize: 28
                        tooltipText: "Refresh"
                        onClicked: svc.refresh()
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledRect {
                    visible: svc.loaded && !svc.available
                    width: parent.width
                    height: missingText.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.error, 0.15)
                    StyledText {
                        id: missingText
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingL * 2
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.error
                        text: "Could not reach xyz.ljones.Asusd on the system bus.\nStart it with: systemctl start asusd"
                    }
                }

                LaptopHero {
                    id: hero
                    ctl: root.svc
                    screenName: root.parentScreen ? root.parentScreen.name : ""
                    visible: svc.available && !svc.heroHidden
                    active: popout.parentPopout ? popout.parentPopout.shouldBeVisible === true : false

                    // Battery / AC don't come through asusd signals; poll gently while open.
                    Timer {
                        interval: 10000
                        repeat: true
                        running: hero.running
                        onTriggered: svc.refresh()
                    }
                }

                DankTabBar {
                    id: tabBar
                    visible: svc.available
                    width: parent.width
                    tabHeight: 44
                    model: root.tabs
                    currentIndex: root.tabs.findIndex(t => t.key === root.activeTab)
                    onTabClicked: index => root.currentTab = root.tabs[index].key
                }

                Flickable {
                    id: body
                    visible: svc.available
                    width: parent.width
                    height: Math.min(bodyCol.implicitHeight, Math.max(320, (root.parentScreen ? root.parentScreen.height : 1100) * 0.62 - (hero.visible ? hero.height : 0)))
                    contentHeight: bodyCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    Column {
                        id: bodyCol
                        width: body.width
                        spacing: Theme.spacingM

                        LightingTab { ctl: root.svc; visible: root.activeTab === "lighting" }
                        PerformanceTab { ctl: root.svc; visible: root.activeTab === "performance" }
                        FansTab { ctl: root.svc; visible: root.activeTab === "fans" }
                        SystemTab { ctl: root.svc; visible: root.activeTab === "system" }
                    }
                }
            }
        }
    }
}
