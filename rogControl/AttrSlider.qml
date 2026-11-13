import QtQuick
import qs.Common
import qs.Widgets

// Labelled slider that only commits on release / click / wheel, and snaps back
// to the daemon's value whenever it isn't being dragged.
Column {
    id: as
    property string label: ""
    property string unit: ""
    property int minimum: 0
    property int maximum: 100
    property int step: 1
    property int value: 0
    property int defaultValue: -1
    property string leftIcon: ""
    property string rightIcon: ""
    signal committed(int v)
    signal resetRequested

    width: parent ? parent.width : 0
    spacing: 2
    opacity: enabled ? 1 : 0.5

    Item {
        width: parent.width
        height: Math.max(lbl.implicitHeight, resetBtn.height)
        SubLabel {
            id: lbl
            anchors.verticalCenter: parent.verticalCenter
            text: as.label + (as.defaultValue >= 0 ? "  ·  default " + as.defaultValue + as.unit : "")
        }
        StyledText {
            anchors.right: resetBtn.visible ? resetBtn.left : parent.right
            anchors.rightMargin: resetBtn.visible ? Theme.spacingXS : 0
            anchors.verticalCenter: parent.verticalCenter
            text: (slider.isDragging ? slider.value : as.value) + (as.unit === "%" || as.unit === "" ? as.unit : " " + as.unit)
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
        }
        DankActionButton {
            id: resetBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: as.defaultValue >= 0 && as.value !== as.defaultValue && as.enabled
            iconName: "restart_alt"
            iconColor: Theme.surfaceVariantText
            buttonSize: 24
            iconSize: 16
            tooltipText: "Restore default"
            onClicked: as.resetRequested()
        }
    }

    DankSlider {
        id: slider
        width: parent.width
        minimum: as.minimum
        maximum: as.maximum
        step: as.step
        unit: as.unit
        leftIcon: as.leftIcon
        rightIcon: as.rightIcon
        showValue: false
        enabled: as.enabled
        onSliderValueChanged: v => {
            if (!isDragging)
                as.committed(v);
        }
        onSliderDragFinished: v => as.committed(v)
    }
    Binding {
        target: slider
        property: "value"
        value: as.value
        when: !slider.isDragging
    }
}
