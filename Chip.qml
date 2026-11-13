import QtQuick
import qs.Common
import qs.Widgets

// Tappable chip used for effects, flags and choices.
Rectangle {
    id: chip
    property string icon: ""
    property string text: ""
    property bool selected: false
    property color accent: Theme.primary
    property color iconColor: "transparent"   // fixed icon colour (e.g. a swatch)
    signal clicked

    height: 36
    radius: Theme.cornerRadius
    opacity: enabled ? 1 : 0.45
    color: selected ? Theme.withAlpha(accent, 0.22) : (chipMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : Theme.withAlpha(Theme.surfaceText, 0.04))
    border.width: selected ? 1 : 0
    border.color: Theme.withAlpha(accent, 0.6)
    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingXS
        width: Math.min(implicitWidth, chip.width - Theme.spacingS * 2)
        DankIcon {
            id: chipIcon
            name: chip.icon
            visible: chip.icon !== ""
            size: Theme.iconSizeSmall
            color: chip.iconColor.a > 0 ? chip.iconColor : (chip.selected ? chip.accent : Theme.surfaceVariantText)
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            text: chip.text
            width: Math.min(implicitWidth, chip.width - Theme.spacingS * 2 - (chipIcon.visible ? chipIcon.width + Theme.spacingXS : 0))
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeSmall
            color: chip.selected ? Theme.surfaceText : Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: chip.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
