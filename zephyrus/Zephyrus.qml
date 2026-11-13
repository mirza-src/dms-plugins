pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Common
import qs.Services
import "Modes.js" as Modes

// State of asusd (platform, firmware limits, fans, keyboard) and cardwired
// (GPU mode, panel mux) and the modes built on them. Everything goes through
// DMS's D-Bus bridge; the daemons keep and restore their own settings, this
// only decides which mode applies (per power source) and applies it again
// when the power source changes, at login and after resume.
Singleton {
    id: root

    readonly property string pluginId: "zephyrus"

    // ── Bus ──────────────────────────────────────────────────────────
    readonly property string asusdName: "xyz.ljones.Asusd"
    readonly property string asusdPath: "/xyz/ljones"
    readonly property string platformIface: "xyz.ljones.Platform"
    readonly property string fanIface: "xyz.ljones.FanCurves"
    readonly property string armouryIface: "xyz.ljones.AsusArmoury"
    readonly property string auraIface: "xyz.ljones.Aura"
    readonly property string cwName: "org.opengamingcollective.cardwire"
    readonly property string cwPath: "/org/opengamingcollective/cardwire"
    readonly property string cwModeIface: "org.opengamingcollective.cardwire.Mode"
    readonly property string cwMuxIface: "org.opengamingcollective.cardwire.Mux"
    readonly property string cwGpuIface: "org.opengamingcollective.cardwire.Gpu"

    readonly property bool busReady: DMSService.isConnected && DMSService.capabilities.includes("dbus")

    // ── State ────────────────────────────────────────────────────────
    property bool asusdUp: false
    property bool cardwireUp: false

    property int profile: -1
    property var profileChoices: []
    property int chargeLimit: -1
    property bool asusdAutoProfile: false
    // attribute name -> {current, min, max, def, step, path}
    property var armoury: ({})
    // profile -> [{fan, pwm[8], temp[8], enabled}]
    property var fanCurves: ({})
    property bool hasFans: false

    property string auraPath: ""
    property int kbBrightness: -1
    property var kbBrightnessLevels: []
    property int kbMode: -1
    property var kbModes: []
    // [mode, zone, [r, g, b], [r, g, b], speed, direction]
    property var kbModeData: null

    property int gpuMode: -1
    property var gpuModes: []
    property bool gpuSwitching: false
    property bool muxCapable: false
    property string panelGpu: ""
    property string muxState: ""
    property string muxError: ""
    property string dgpuPath: ""
    property string dgpuName: ""
    property string dgpuPower: ""

    readonly property bool onBattery: UPower.onBattery
    readonly property string source: onBattery ? "battery" : "ac"

    // Mode chosen for the current power source; `modified` once something was
    // changed by hand after applying it (the next apply resets it).
    property string activeMode: modeFor(source)
    property bool modified: false
    property bool applying: false
    property string lastError: ""

    readonly property var modes: Modes.modes
    readonly property var activeModeInfo: Modes.byId(activeMode)
    readonly property bool dgpuAwake: dgpuPower !== "" && !dgpuPower.startsWith("D3")

    // ── Settings ─────────────────────────────────────────────────────
    readonly property var defaultModes: ({
            "ac": "balanced",
            "battery": "eco"
        })

    function setting(key, fallback) {
        return PluginService.loadPluginData(pluginId, key, fallback);
    }
    function modeFor(src) {
        const id = setting(src === "battery" ? "modeBattery" : "modeAc", defaultModes[src]);
        return Modes.byId(id) ? id : defaultModes[src];
    }

    Connections {
        target: PluginService
        function onPluginDataChanged(changedId) {
            if (changedId !== root.pluginId)
                return;
            const wanted = root.modeFor(root.source);
            if (wanted !== root.activeMode && root.started)
                root.applyMode(wanted, "settings");
        }
    }

    // ── Bus helpers ──────────────────────────────────────────────────
    function request(method, params, cb) {
        DMSService.sendRequest(method, params, response => {
            if (response.error)
                console.warn("zephyrus:", method, params.interface + "." + (params.method || params.property), response.error);
            if (cb)
                cb(response.error ? null : response.result, response.error || "");
        });
    }
    // Typed arguments need the method's input signature (patched DMS bridge).
    function call(dest, path, iface, method, args, signature, cb) {
        request("dbus.call", {
            "bus": "system",
            "dest": dest,
            "path": path,
            "interface": iface,
            "method": method,
            "args": args || [],
            "signature": signature || ""
        }, (result, err) => {
            if (cb)
                cb(result ? result.values : null, err);
        });
    }
    // The bridge converts the value to the property's current type.
    function setProp(dest, path, iface, property, value, cb) {
        request("dbus.setProperty", {
            "bus": "system",
            "dest": dest,
            "path": path,
            "interface": iface,
            "property": property,
            "value": value
        }, (result, err) => {
            if (err)
                root.fail(property, err);
            if (cb)
                cb(!err);
        });
    }
    function fail(what, err) {
        lastError = what + ": " + err;
        ToastService.showError("Zephyrus: couldn't change " + what, err);
    }

    // ── Reading ──────────────────────────────────────────────────────
    function refresh() {
        refreshAsusd();
        refreshCardwire();
    }

    function refreshAsusd(done) {
        if (!busReady)
            return;
        call(asusdName, "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects", [], "", (values, err) => {
            const objects = values ? values[0] : null;
            root.asusdUp = !!objects;
            if (!objects) {
                if (done)
                    done();
                return;
            }
            const base = objects[root.asusdPath] || {};
            const platform = base[root.platformIface];
            if (platform) {
                root.profile = platform.PlatformProfile;
                root.profileChoices = (platform.PlatformProfileChoices || []).slice().sort();
                root.chargeLimit = platform.ChargeControlEndThreshold;
                root.asusdAutoProfile = !!(platform.ChangePlatformProfileOnAc || platform.ChangePlatformProfileOnBattery);
            }
            root.hasFans = root.fanIface in base;

            const attrs = {};
            for (const path in objects) {
                const armoury = objects[path][root.armouryIface];
                if (armoury) {
                    attrs[path.split("/").pop()] = {
                        "current": armoury.CurrentValue,
                        "min": armoury.MinValue,
                        "max": armoury.MaxValue,
                        "def": armoury.DefaultValue,
                        "step": armoury.ScalarIncrement || 1,
                        "path": path
                    };
                }
                const aura = objects[path][root.auraIface];
                if (aura && !root.auraPath)
                    root.auraPath = path;
                if (aura && path === root.auraPath) {
                    root.kbBrightness = aura.Brightness;
                    root.kbBrightnessLevels = aura.SupportedBrightness || [];
                    root.kbMode = aura.LedMode;
                    root.kbModes = aura.SupportedBasicModes || [];
                    root.kbModeData = aura.LedModeData || null;
                }
            }
            root.armoury = attrs;
            root.watch(root.asusdName, Object.keys(objects).filter(p => Object.keys(objects[p]).length > 0));
            if (root.hasFans)
                root.refreshFans();
            if (done)
                done();
        });
    }

    function refreshFans() {
        const curves = {};
        let pending = profileChoices.length;
        profileChoices.forEach(p => {
            call(asusdName, asusdPath, fanIface, "FanCurveData", [p], "u", values => {
                curves[p] = (values ? values[0] : []).map(c => ({
                            "fan": c[0],
                            "pwm": c[1],
                            "temp": c[2],
                            "enabled": c[3]
                        }));
                if (--pending === 0)
                    root.fanCurves = curves;
            });
        });
    }

    function refreshCardwire(done) {
        if (!busReady)
            return;
        call(cwName, cwPath, "org.freedesktop.DBus.ObjectManager", "GetManagedObjects", [], "", values => {
            const objects = values ? values[0] : null;
            root.cardwireUp = !!objects;
            if (!objects) {
                if (done)
                    done();
                return;
            }
            const base = objects[root.cwPath] || {};
            const mode = base[root.cwModeIface];
            if (mode)
                root.gpuMode = mode.Mode;
            const mux = base[root.cwMuxIface];
            if (mux) {
                root.muxCapable = !!mux.Capable;
                root.panelGpu = mux.PanelGpu || "";
                root.muxState = mux.State || "";
                root.muxError = mux.LastError || "";
            }
            const gpus = Object.keys(objects).filter(p => root.cwGpuIface in objects[p]);
            root.watch(root.cwName, [root.cwPath].concat(gpus));
            if (!root.dgpuPath)
                root.findDgpu(gpus);
            else
                root.refreshDgpuPower();
            if (done)
                done();
        });
        call(cwName, cwPath, cwModeIface, "AvailableModes", [], "", values => {
            if (values)
                root.gpuModes = values[0] || [];
        });
    }

    // GetDevice: (name, pci, render, card, default, discrete, …)
    function findDgpu(paths) {
        paths.forEach(path => {
            call(cwName, path, cwGpuIface, "GetDevice", [], "", values => {
                const device = values ? values[0] : null;
                if (device && device[5] === true && !root.dgpuPath) {
                    root.dgpuPath = path;
                    root.dgpuName = device[0];
                    root.refreshDgpuPower();
                }
            });
        });
    }

    function refreshDgpuPower() {
        if (!dgpuPath)
            return;
        call(cwName, dgpuPath, cwGpuIface, "PowerState", [], "", values => {
            if (values)
                root.dgpuPower = String(values[0]).trim();
        });
    }

    // ── Change notifications ─────────────────────────────────────────
    // The bridge's match rules are per object path, so one per object.
    property var subscriptions: ({}) // "dest path" -> subscription id
    property var subscriptionOwner: ({}) // subscription id -> dest

    function watch(dest, paths) {
        paths.forEach(path => {
            const key = dest + " " + path;
            if (key in root.subscriptions)
                return;
            root.subscriptions[key] = "";
            DMSService.dbusSubscribe("system", dest, path, "", "", response => {
                const id = response.result?.subscriptionId;
                if (id) {
                    root.subscriptions[key] = id;
                    root.subscriptionOwner[id] = dest;
                } else {
                    delete root.subscriptions[key];
                }
            });
        });
    }

    Connections {
        target: DMSService
        function onDbusSignalReceived(subscriptionId, data) {
            const dest = root.subscriptionOwner[subscriptionId];
            if (!dest)
                return;
            if (data.member === "PowerStateChanged") {
                root.dgpuPower = String(data.body?.[0] || "").trim();
            } else if (dest === root.asusdName) {
                asusdRefreshTimer.restart();
            } else {
                cardwireRefreshTimer.restart();
            }
        }
        function onIsConnectedChanged() {
            // A new socket has no subscriptions.
            root.subscriptions = {};
            root.subscriptionOwner = {};
            if (root.busReady)
                root.refresh();
        }
        function onCapabilitiesReceived() {
            if (root.busReady)
                root.refresh();
        }
    }

    Timer {
        id: asusdRefreshTimer
        interval: 150
        onTriggered: root.refreshAsusd()
    }
    Timer {
        id: cardwireRefreshTimer
        interval: 150
        onTriggered: root.refreshCardwire()
    }

    // ── Changing things ──────────────────────────────────────────────
    function setGpuMode(mode, cb) {
        if (mode === gpuMode) {
            if (cb)
                cb(true);
            return;
        }
        gpuSwitching = true;
        setProp(cwName, cwPath, cwModeIface, "Mode", mode, ok => {
            root.gpuSwitching = false;
            root.refreshCardwire();
            if (cb)
                cb(ok);
        });
    }
    function applyPendingMux() {
        call(cwName, cwPath, cwMuxIface, "ApplyPending", [], "", (v, err) => {
            if (err)
                root.fail("panel mux", err);
        });
    }

    function setProfile(p, cb) {
        if (p === profile) {
            if (cb)
                cb(true);
            return;
        }
        setProp(asusdName, asusdPath, platformIface, "PlatformProfile", p, ok => {
            // asusd applies EPP, fan curves and firmware ranges with it.
            root.refreshAsusd(() => {
                if (cb)
                    cb(ok);
            });
        });
    }
    function setChargeLimit(n) {
        setProp(asusdName, asusdPath, platformIface, "ChargeControlEndThreshold", n);
    }
    function fullChargeOnce() {
        call(asusdName, asusdPath, platformIface, "OneShotFullCharge", [], "", (v, err) => {
            if (err)
                root.fail("full charge", err);
        });
    }
    function setLimit(name, value) {
        const attr = armoury[name];
        if (!attr || attr.current === value)
            return;
        setProp(asusdName, attr.path, armouryIface, "CurrentValue", value);
    }

    function setFanCurvesEnabled(p, enabled) {
        call(asusdName, asusdPath, fanIface, "SetFanCurvesEnabled", [p, enabled], "ub", (v, err) => {
            if (err)
                root.fail("fan curves", err);
            root.refreshFans();
        });
    }
    function resetFanCurves(p) {
        call(asusdName, asusdPath, fanIface, "SetCurvesToDefaults", [p], "u", (v, err) => {
            if (err)
                root.fail("fan curves", err);
            root.refreshFans();
        });
    }

    function setKbBrightness(level) {
        if (auraPath)
            setProp(asusdName, auraPath, auraIface, "Brightness", level);
    }
    function setKbMode(mode) {
        if (auraPath)
            setProp(asusdName, auraPath, auraIface, "LedMode", mode);
    }
    function setKbColour(c) {
        if (!auraPath || !kbModeData)
            return;
        const data = kbModeData.slice();
        data[2] = [Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255)];
        setProp(asusdName, auraPath, auraIface, "LedModeData", data);
    }

    // Manual changes from the UI mark the mode as modified.
    function tweak(fn) {
        modified = true;
        fn();
    }

    // ── Modes ────────────────────────────────────────────────────────
    // Pick a mode for the current power source (remembered per source).
    function selectMode(id) {
        if (!Modes.byId(id))
            return false;
        // activeMode first: saving notifies onPluginDataChanged, which must
        // not apply it a second time.
        activeMode = id;
        PluginService.savePluginData(pluginId, onBattery ? "modeBattery" : "modeAc", id);
        applyMode(id, "selected");
        return true;
    }

    function applyMode(id, reason) {
        const mode = Modes.byId(id);
        if (!mode || !busReady)
            return;
        console.info("zephyrus: applying", id, "(" + reason + ", " + source + ")");
        activeMode = id;
        modified = false;
        applying = true;

        // GPU first: an Ultimate switch takes a few seconds and runs on its own.
        const gpu = Modes.GPU[mode.gpu];
        if (mode.gpu && cardwireUp && gpuModes.includes(gpu))
            setGpuMode(gpu);

        // Profile next: asusd re-applies EPP and fan curves for it and the
        // firmware may report other ranges. Then the limits, against fresh ranges.
        const p = Modes.PROFILE[mode.profile];
        const applyLimits = () => {
            root.refreshAsusd(() => {
                for (const name in mode.limits) {
                    const v = Modes.resolve(mode.limits[name], root.armoury[name]);
                    if (v !== null)
                        root.setLimit(name, v);
                }
                root.applying = false;
            });
        };
        if (mode.profile && asusdUp && profileChoices.includes(p))
            setProfile(p, applyLimits);
        else
            applyLimits();
    }

    function cycleMode(step) {
        const i = modes.findIndex(m => m.id === activeMode);
        selectMode(modes[(i + (step || 1) + modes.length) % modes.length].id);
    }

    // ── Automatic re-apply ───────────────────────────────────────────
    // Started by the daemon surface; only then does the plugin act on its own.
    property bool started: false
    property bool initialApplied: false

    function start() {
        if (started)
            return;
        started = true;
        if (busReady)
            refresh();
    }

    function takeOverFromAsusd() {
        // asusd switching profiles on plug/unplug by itself would race the
        // mode applied here (which sets the profile too).
        if (!asusdAutoProfile)
            return;
        setProp(asusdName, asusdPath, platformIface, "ChangePlatformProfileOnAc", false);
        setProp(asusdName, asusdPath, platformIface, "ChangePlatformProfileOnBattery", false);
    }

    function applyForSource(reason) {
        if (!started || !setting("managed", true) || !busReady)
            return;
        takeOverFromAsusd();
        applyMode(modeFor(source), reason);
    }

    // First full read after start: apply the mode once (login).
    onAsusdUpChanged: initialTimer.restart()
    onCardwireUpChanged: initialTimer.restart()
    Timer {
        id: initialTimer
        interval: 500
        onTriggered: {
            if (!root.initialApplied && root.asusdUp && root.started) {
                root.initialApplied = true;
                root.applyForSource("login");
            }
        }
    }

    // Firmware ranges change shortly after the power source does.
    onOnBatteryChanged: sourceTimer.restart()
    Timer {
        id: sourceTimer
        interval: 1500
        onTriggered: root.applyForSource(root.onBattery ? "unplugged" : "plugged in")
    }

    Connections {
        target: SessionService
        function onPreparingForSleepChanged() {
            if (!SessionService.preparingForSleep)
                resumeTimer.restart();
        }
    }
    Timer {
        id: resumeTimer
        interval: 3000
        onTriggered: root.applyForSource("resume")
    }
}
