import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: cb
    property string label: ""
    property color value: "white"
    signal picked(color c)
    spacing: 4

    function hex(c) {
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    SubLabel { text: cb.label }
    Rectangle {
        width: 120
        height: 36
        radius: Theme.cornerRadius
        color: cb.value
        border.width: 2
        border.color: Theme.outlineStrong
        StyledText {
            anchors.centerIn: parent
            text: cb.hex(cb.value).toUpperCase()
            font.pixelSize: Theme.fontSizeSmall
            font.family: "monospace"
            color: (0.2126 * cb.value.r + 0.7152 * cb.value.g + 0.0722 * cb.value.b) > 0.55 ? "black" : "white"
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const m = PopoutService ? PopoutService.colorPickerModal : null;
                if (!m)
                    return;
                m.selectedColor = cb.value;
                m.pickerTitle = cb.label;
                m.onColorSelectedCallback = c => cb.picked(c);
                m.show();
            }
        }
    }
}
