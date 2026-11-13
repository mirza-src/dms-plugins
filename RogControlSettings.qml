import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "rogControl"

    StyledText {
        width: parent.width
        text: "ROG Control"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Lighting, performance, fans and firmware controls via asusd (asusctl). Click the bar icon (or run: dms ipc call widget toggle rogControl) for the full panel. Settings live in asusd itself, so they survive reboots without this plugin. Colour correction and chassis colour are in the panel."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ToggleSetting {
        settingKey: "followTheme"
        label: "Follow DMS theme accent"
        description: "Keep the keyboard colour in sync with the theme's primary (and secondary, for two-colour effects). Updates automatically when matugen regenerates the palette from a new wallpaper."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "tintPill"
        label: "Tint bar icon with keyboard colour"
        description: "Colour the bar icon with the current effect colour instead of the theme primary."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "scrollBrightness"
        label: "Scroll to change brightness"
        description: "Mouse wheel over the bar icon steps the keyboard backlight."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showProfileInBar"
        label: "Show platform profile in bar"
        description: "Adds the Quiet / Balanced / Performance icon next to the keyboard icon."
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "rightClickAction"
        label: "Right-click on bar icon"
        options: [
            {label: "Toggle keyboard light", value: "keyboard"},
            {label: "Next platform profile", value: "profile"}
        ]
        defaultValue: "keyboard"
    }
}
