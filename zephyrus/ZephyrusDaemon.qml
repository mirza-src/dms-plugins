import QtQuick
import Quickshell.Io
import qs.Modules.Plugins

// Runs once, with or without the bar widget: starts the automatic mode
// handling and the IPC target, e.g.
//   dms ipc call zephyrus mode gaming
//   dms ipc call zephyrus next
PluginComponent {
    id: root

    Component.onCompleted: Zephyrus.start()

    IpcHandler {
        target: "zephyrus"

        function mode(id: string): string {
            return Zephyrus.selectMode(id) ? "ok: " + id : "unknown mode '" + id + "' (" + Zephyrus.modes.map(m => m.id).join(", ") + ")";
        }

        function next(): string {
            Zephyrus.cycleMode(1);
            return Zephyrus.activeMode;
        }

        function status(): string {
            return JSON.stringify({
                "mode": Zephyrus.activeMode,
                "modified": Zephyrus.modified,
                "source": Zephyrus.source,
                "gpuMode": Zephyrus.gpuMode,
                "panelGpu": Zephyrus.panelGpu,
                "dgpuPower": Zephyrus.dgpuPower,
                "profile": Zephyrus.profile,
                "limits": Object.fromEntries(Object.entries(Zephyrus.armoury).map(([k, v]) => [k, v.current]))
            });
        }

        function reapply(): string {
            Zephyrus.applyMode(Zephyrus.activeMode, "ipc");
            return Zephyrus.activeMode;
        }
    }
}
