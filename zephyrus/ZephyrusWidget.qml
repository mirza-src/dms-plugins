import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property var z: Zephyrus
    readonly property bool showGpu: pluginData.showGpuInBar ?? true

    popoutWidth: 440
    // Right click: next mode.
    pillRightClickAction: () => z.cycleMode(1)

    component Pill: Item {
        id: pill
        property bool vertical: false
        implicitWidth: layout.implicitWidth
        implicitHeight: layout.implicitHeight

        Grid {
            id: layout
            anchors.centerIn: parent
            flow: pill.vertical ? Grid.TopToBottom : Grid.LeftToRight
            columns: pill.vertical ? 1 : 2
            spacing: Theme.spacingXS

            DankIcon {
                name: root.z.activeModeInfo?.icon ?? "laptop"
                size: root.iconSize
                color: root.z.applying || root.z.gpuSwitching ? Theme.surfaceVariantText : Theme.surfaceText
            }
            // dGPU awake (anything but D3cold): something is keeping it on.
            DankIcon {
                visible: root.showGpu && root.z.dgpuAwake
                name: root.z.panelGpu === "dgpu" ? "monitor" : "memory"
                size: root.iconSize
                color: Theme.primary
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.PointingHandCursor
            onWheel: wheel => root.z.cycleMode(wheel.angleDelta.y > 0 ? -1 : 1)
        }
    }

    horizontalBarPill: Component {
        Pill {}
    }
    verticalBarPill: Component {
        Pill {
            vertical: true
        }
    }

    ccWidgetIcon: z.activeModeInfo?.icon ?? "laptop"
    ccWidgetPrimaryText: z.activeModeInfo?.name ?? "Zephyrus"
    ccWidgetSecondaryText: (z.onBattery ? "On battery" : "On AC") + (z.modified ? " · modified" : "")
    ccWidgetIsActive: true
    ccWidgetIsToggle: false
    onCcWidgetToggled: z.cycleMode(1)
    ccDetailContent: Component {
        ZephyrusPanel {}
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "Zephyrus"
            detailsText: (root.z.activeModeInfo?.name ?? "") + (root.z.modified ? " (modified)" : "") + " · " + (root.z.onBattery ? "on battery" : "on AC")

            ZephyrusPanel {
                width: parent.width
            }
        }
    }
}
