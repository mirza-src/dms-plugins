import QtQuick
import qs.Common
import qs.Widgets

StyledText {
    width: parent ? parent.width : implicitWidth
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSizeSmall
    color: Theme.surfaceVariantText
    opacity: 0.85
}
