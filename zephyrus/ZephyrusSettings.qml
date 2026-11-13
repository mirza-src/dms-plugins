import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "Modes.js" as Modes

PluginSettings {
    id: root
    pluginId: "zephyrus"

    readonly property var modeOptions: Modes.modes.map(m => ({
                "label": m.name,
                "value": m.id
            }))

    SelectionSetting {
        settingKey: "modeAc"
        label: "Mode on AC"
        description: "Applied when plugged in. Picking a mode while on AC changes this too."
        options: root.modeOptions
        defaultValue: "balanced"
    }

    SelectionSetting {
        settingKey: "modeBattery"
        label: "Mode on battery"
        description: "Applied when unplugged. Picking a mode while on battery changes this too."
        options: root.modeOptions
        defaultValue: "eco"
    }

    ToggleSetting {
        settingKey: "managed"
        label: "Apply modes automatically"
        description: "On plug/unplug, at login and after resume. Also stops asusd from switching profiles on its own."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showGpuInBar"
        label: "Show when the dGPU is awake"
        description: "An extra icon in the bar pill while the dGPU is powered (monitor icon: it drives the panel)."
        defaultValue: true
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        text: "Modes are defined in Modes.js in the plugin directory. Keybinds: dms ipc call zephyrus mode <id> | next | status | reapply"
    }
}
