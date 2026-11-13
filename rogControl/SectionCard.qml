import QtQuick
import qs.Common
import qs.Widgets

// Card with a clickable header that collapses the body. Collapsed state is
// persisted through the plugin controller (found via the enclosing tab's `ctl`).
StyledRect {
    id: card
    property string title: ""
    property string icon: ""
    property string subtitle: ""
    property Component trailing: null
    property bool collapsible: true
    property bool collapsedByDefault: false
    property string stateKey: title
    default property alias body: bodyCol.data

    property var ctl: null
    readonly property bool expanded: !collapsible || !ctl || !ctl.isCollapsed(stateKey, collapsedByDefault)

    function findCtl() {
        let p = parent;
        while (p) {
            if (p.ctl !== undefined && p.ctl !== null && p !== card)
                return p.ctl;
            p = p.parent;
        }
        return null;
    }
    Component.onCompleted: if (!ctl) ctl = findCtl()

    width: parent ? parent.width : 0
    height: cardCol.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh
    clip: true
    Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }

    Column {
        id: cardCol
        x: Theme.spacingM
        y: Theme.spacingM
        width: parent.width - Theme.spacingM * 2
        spacing: Theme.spacingM

        Item {
            width: parent.width
            height: Math.max(titleRow.implicitHeight, trailingLoader.implicitHeight)

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                enabled: card.collapsible && card.ctl !== null
                hoverEnabled: enabled
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: card.ctl.setCollapsed(card.stateKey, card.expanded)
            }

            Row {
                id: titleRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS
                DankIcon {
                    name: card.icon
                    size: Theme.iconSize - 2
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    StyledText {
                        text: card.title
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                    StyledText {
                        visible: card.subtitle !== ""
                        text: card.subtitle
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS
                Loader {
                    id: trailingLoader
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: card.trailing
                }
                DankIcon {
                    visible: card.collapsible && card.ctl !== null
                    anchors.verticalCenter: parent.verticalCenter
                    name: "expand_more"
                    size: Theme.iconSize - 2
                    color: headerMouse.containsMouse ? Theme.surfaceText : Theme.surfaceVariantText
                    rotation: card.expanded ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: Theme.shortDuration } }
                }
            }
        }

        Column {
            id: bodyCol
            visible: card.expanded
            width: parent.width
            spacing: Theme.spacingM
        }
    }
}
