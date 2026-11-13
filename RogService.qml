pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

// Shared state + D-Bus I/O for every ROG Control widget instance (bar pill,
// Control Center tile, one per screen…): one monitor, one state reader and one
// writer instead of one per instance.
Singleton {
    id: root

    readonly property string pluginId: "rogControl"
    property var pluginData: ({})
    function loadPluginData() {
        pluginData = SettingsData.getPluginSettingsForPlugin(pluginId) || {};
    }
    Connections {
        target: PluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                root.loadPluginData();
        }
    }

    // Widgets acquire/release the service; the monitor only runs while in use.
    property int users: 0
    function acquire() {
        users++;
        if (users === 1) {
            loadPluginData();
            refresh();
        }
    }
    function release() {
        users = Math.max(0, users - 1);
    }

    // ── Plugin settings ──────────────────────────────────────────────
    readonly property bool followTheme: pluginData.followTheme === true
    readonly property bool tintPill: pluginData.tintPill !== false
    readonly property bool scrollBrightness: pluginData.scrollBrightness !== false
    readonly property bool showProfileInBar: pluginData.showProfileInBar !== false
    readonly property string rightClickAction: pluginData.rightClickAction || "keyboard"
    readonly property int ledSaturation: pluginData.ledSaturation || 100
    readonly property int ledGamma: pluginData.ledGamma || 100
    readonly property bool correctionActive: ledSaturation !== 100 || ledGamma !== 100

    // Collapsible sections (persisted): key -> collapsed bool.
    readonly property var collapsed: pluginData.collapsed || ({})
    readonly property bool heroHidden: pluginData.heroHidden === true
    function isCollapsed(key, def) {
        return collapsed[key] !== undefined ? collapsed[key] === true : def === true;
    }
    function setCollapsed(key, value) {
        const c = Object.assign({}, collapsed);
        c[key] = value;
        saveSetting("collapsed", c);
    }

    function saveSetting(key, value) {
        PluginService.savePluginData(pluginId, key, value);
    }

    // ── asusd state (refreshed from asus-state.sh) ───────────────────
    readonly property string svc: "xyz.ljones.Asusd"
    readonly property string stateScript: Qt.resolvedUrl("asus-state.sh").toString().replace("file://", "")

    property bool loaded: false
    property bool available: false
    property string product: ""
    property string board: ""
    property string vendor: ""
    property string bios: ""
    property bool onAc: true
    property var battery: ({ capacity: -1, status: "" })
    property bool pendingReboot: false
    property var platform: ({})
    property var armoury: ({})          // attr -> props
    property var fans: ({})             // profile -> [[name, pwm[8], temp[8], enabled], ...]

    // Keyboard (first xyz.ljones.Aura device)
    property string auraPath: ""
    property int kbBrightness: 0
    property var kbSupportedBrightness: [0, 1, 2, 3]
    property var kbSupportedModes: []
    property var kbPowerZones: []
    property var kbPower: ({})          // zone -> [boot, awake, sleep, shutdown]
    property int kbMode: 0
    property int kbZone: 0
    property color kbColour1: "#ffffff"     // what the LEDs are set to
    property color kbColour2: "#000000"
    property color kbDisplayColour1: "#ffffff"  // what the user picked (before correction)
    property color kbDisplayColour2: "#000000"
    property string kbSpeed: "Med"
    property string kbDirection: "Right"
    property int kbLastOnBrightness: 3

    // Slash ledbar (first xyz.ljones.Slash device)
    property string slashPath: ""
    property bool slashEnabled: false
    property int slashBrightness: 255
    property int slashInterval: 0
    property int slashMode: 16
    property var slashFlags: ({})

    readonly property bool hasKeyboard: auraPath !== ""
    readonly property bool hasSlash: slashPath !== ""
    readonly property bool hasPlatform: platform.PlatformProfile !== undefined
    readonly property bool hasFans: Object.keys(fans).length > 0
    readonly property int platformProfile: platform.PlatformProfile !== undefined ? platform.PlatformProfile : -1
    readonly property bool tuningEnabled: platform.EnablePptGroup === true

    // ── Static metadata ──────────────────────────────────────────────
    readonly property var modeInfo: ({
        0: { name: "Static", icon: "light_mode", colours: 1, speed: false, dir: false },
        1: { name: "Breathe", icon: "air", colours: 2, speed: true, dir: false },
        2: { name: "Rainbow", icon: "looks", colours: 0, speed: true, dir: false },
        3: { name: "Wave", icon: "waves", colours: 0, speed: true, dir: true },
        4: { name: "Stars", icon: "auto_awesome", colours: 2, speed: true, dir: false },
        5: { name: "Rain", icon: "water_drop", colours: 0, speed: true, dir: false },
        6: { name: "Highlight", icon: "highlight", colours: 1, speed: true, dir: false },
        7: { name: "Laser", icon: "flare", colours: 1, speed: true, dir: false },
        8: { name: "Ripple", icon: "radio_button_checked", colours: 1, speed: true, dir: false },
        10: { name: "Pulse", icon: "favorite", colours: 1, speed: false, dir: false },
        11: { name: "Comet", icon: "rocket_launch", colours: 1, speed: true, dir: false },
        12: { name: "Flash", icon: "flash_on", colours: 1, speed: true, dir: false }
    })
    readonly property var brightnessNames: ["Off", "Low", "Med", "High"]
    readonly property var speeds: ["Low", "Med", "High"]
    readonly property var directions: ["Left", "Right", "Up", "Down"]
    readonly property var powerZoneNames: ({ 0: "Logo", 1: "Keyboard", 2: "Lightbar", 3: "Lid", 4: "Rear glow", 5: "Keyboard + lightbar", 6: "Ally" })
    readonly property var powerStateNames: ["Boot", "Awake", "Sleep", "Shutdown"]

    readonly property var slashModes: [
        { name: "Static", value: 6 }, { name: "Bounce", value: 16 }, { name: "Slash", value: 18 },
        { name: "Loading", value: 19 }, { name: "BitStream", value: 29 }, { name: "Transmission", value: 26 },
        { name: "Flow", value: 25 }, { name: "Flux", value: 37 }, { name: "Phantom", value: 36 },
        { name: "Spectrum", value: 38 }, { name: "Hazard", value: 50 }, { name: "Interfacing", value: 51 },
        { name: "Ramp", value: 52 }, { name: "GameOver", value: 66 }, { name: "Start", value: 67 },
        { name: "Buzzer", value: 68 }
    ]
    readonly property var slashFlagDefs: [
        { key: "ShowOnBoot", label: "Boot", icon: "power_settings_new" },
        { key: "ShowOnShutdown", label: "Shutdown", icon: "power_off" },
        { key: "ShowOnSleep", label: "Sleep", icon: "bedtime" },
        { key: "ShowOnLidClosed", label: "Lid closed", icon: "laptop_chromebook" },
        { key: "ShowOnBattery", label: "On battery", icon: "battery_std" },
        { key: "ShowBatteryWarning", label: "Low battery", icon: "battery_alert" }
    ]

    // asusd PlatformProfile enum
    readonly property var profileNames: ({ 0: "Balanced", 1: "Performance", 2: "Quiet", 3: "Low power", 4: "Custom" })
    readonly property var profileIcons: ({ 0: "balance", 1: "speed", 2: "eco", 3: "battery_saver", 4: "tune" })
    function profileName(p) { return profileNames[p] || ("Profile " + p); }
    function profileIcon(p) { return profileIcons[p] || "tune"; }
    readonly property var profileChoicesSorted: {
        const order = [2, 3, 0, 1, 4];
        const c = (platform.PlatformProfileChoices || []).slice();
        return c.sort((a, b) => order.indexOf(a) - order.indexOf(b));
    }
    readonly property var eppNames: ["Default", "Performance", "Balance performance", "Balance power", "Power saving"]
    readonly property var eppProps: [
        { label: "Quiet", prop: "ProfileQuietEpp" },
        { label: "Balanced", prop: "ProfileBalancedEpp" },
        { label: "Performance", prop: "ProfilePerformanceEpp" }
    ].filter(e => platform[e.prop] !== undefined)

    // Firmware attributes (asus-armoury). group: cpu/gpu -> Performance tab, the rest -> System tab.
    readonly property var attrMeta: ({
        ppt_pl1_spl: { label: "CPU sustained power (PL1 / SPL)", unit: "W", group: "cpu", order: 1 },
        ppt_pl2_sppt: { label: "CPU boost power (PL2 / sPPT)", unit: "W", group: "cpu", order: 2 },
        ppt_pl3_fppt: { label: "CPU peak power (PL3 / fPPT)", unit: "W", group: "cpu", order: 3 },
        ppt_fppt: { label: "CPU peak power (fPPT)", unit: "W", group: "cpu", order: 3 },
        ppt_apu_sppt: { label: "APU boost power", unit: "W", group: "cpu", order: 4 },
        ppt_platform_sppt: { label: "Platform boost power", unit: "W", group: "cpu", order: 5 },
        nv_base_tgp: { label: "GPU base TGP", unit: "W", group: "gpu", order: 10, ro: true },
        nv_tgp: { label: "GPU TGP", unit: "W", group: "gpu", order: 11 },
        dgpu_tgp: { label: "GPU TGP", unit: "W", group: "gpu", order: 11 },
        nv_dynamic_boost: { label: "GPU Dynamic Boost", unit: "W", group: "gpu", order: 12 },
        nv_temp_target: { label: "GPU temperature target", unit: "°C", group: "gpu", order: 13 },
        gpu_mux_mode: { label: "GPU mode (MUX)", group: "graphics", order: 20, confirm: true,
            values: { 0: "Discrete (Ultimate)", 1: "Hybrid (Optimus)" }, help: "Discrete wires the display straight to the NVIDIA GPU (lower latency, more power). Needs a reboot." },
        dgpu_disable: { label: "Dedicated GPU", group: "graphics", order: 21, confirm: true,
            values: { 0: "Enabled", 1: "Disabled (Eco)" }, help: "Disabling powers the NVIDIA GPU off entirely. Close apps using it first; not possible in Discrete mode." },
        egpu_enable: { label: "External GPU (XG Mobile)", group: "graphics", order: 22, confirm: true, values: { 0: "Off", 1: "On" } },
        boot_sound: { label: "Boot sound", group: "firmware", order: 30, values: { 0: "Off", 1: "On" } },
        panel_overdrive: { label: "Panel overdrive", group: "firmware", order: 31, values: { 0: "Off", 1: "On" } },
        panel_od: { label: "Panel overdrive", group: "firmware", order: 31, values: { 0: "Off", 1: "On" } },
        mini_led_mode: { label: "Mini-LED mode", group: "firmware", order: 32 },
        mcu_powersave: { label: "MCU power saving", group: "firmware", order: 33, values: { 0: "Off", 1: "On" } },
        charge_mode: { label: "Power source", group: "hidden", ro: true, values: { 0: "None", 1: "DC adapter", 2: "USB-C" } },
        pending_reboot: { group: "hidden" }
    })
    readonly property var groupInfo: ({
        graphics: { title: "Graphics", icon: "developer_board", order: 1 },
        firmware: { title: "Firmware", icon: "memory", order: 2 },
        other: { title: "Other firmware attributes", icon: "settings", order: 3 }
    })

    function attrModel(attr) {
        const p = armoury[attr];
        const m = attrMeta[attr] || {};
        const values = (p.PossibleValues || []).map(v => ({ v: v, label: (m.values && m.values[v]) || String(v) }));
        const range = p.MinValue >= 0 && p.MaxValue > p.MinValue;
        const kind = m.ro ? "readonly" : values.length > 0 ? "enum" : range ? "range" : "readonly";
        const valueLabel = (m.values && m.values[p.CurrentValue]) || String(p.CurrentValue);
        return {
            attr: attr,
            label: m.label || attr.replace(/_/g, " ").replace(/^./, c => c.toUpperCase()),
            unit: m.unit || "",
            group: m.group || "other",
            order: m.order || 99,
            help: m.help || "",
            confirm: m.confirm === true,
            ro: m.ro === true,
            kind: kind,
            range: range && !m.ro,
            values: values,
            value: p.CurrentValue,
            valueText: valueLabel + (m.unit ? " " + m.unit : ""),
            min: p.MinValue,
            max: p.MaxValue,
            step: p.ScalarIncrement,
            def: (p.DefaultValue >= p.MinValue && p.DefaultValue <= p.MaxValue && range) ? p.DefaultValue : -1
        };
    }
    readonly property var allAttrs: Object.keys(armoury).map(a => attrModel(a)).sort((x, y) => x.order - y.order)
    readonly property var tuningAttrs: allAttrs.filter(a => a.group === "cpu" || a.group === "gpu")
    readonly property var systemAttrGroups: {
        const groups = {};
        allAttrs.forEach(a => {
            if (a.group === "cpu" || a.group === "gpu" || a.group === "hidden")
                return;
            (groups[a.group] = groups[a.group] || []).push(a);
        });
        return Object.keys(groups).sort((x, y) => (groupInfo[x] || groupInfo.other).order - (groupInfo[y] || groupInfo.other).order)
            .map(g => ({ title: (groupInfo[g] || groupInfo.other).title, icon: (groupInfo[g] || groupInfo.other).icon, attrs: groups[g] }));
    }
    readonly property string powerSourceText: {
        const parts = [];
        if (battery.capacity >= 0)
            parts.push(battery.capacity + "%" + (battery.status ? " · " + battery.status : ""));
        if (armoury.charge_mode && armoury.charge_mode.CurrentValue > 0)
            parts.push(attrModel("charge_mode").valueText);
        else
            parts.push(onAc ? "AC power" : "On battery");
        return parts.join(" · ");
    }

    function fanCurvesFor(p) { return fans[p] || []; }
    function fanName(n) { return ({ CPU: "CPU", GPU: "GPU", MID: "Mid" })[n] || n; }
    readonly property bool activeProfileHasCustomFans: fanCurvesFor(platformProfile).some(c => c[3] === true)

    readonly property var currentModeInfo: modeInfo[kbMode] || { name: "Mode " + kbMode, icon: "keyboard", colours: 1, speed: true, dir: false }
    readonly property bool kbOn: kbBrightness > 0

    function slashModeName(v) {
        for (let i = 0; i < slashModes.length; i++)
            if (slashModes[i].value === v)
                return slashModes[i].name;
        return "Mode " + v;
    }
    function slashModeValue(name) {
        for (let i = 0; i < slashModes.length; i++)
            if (slashModes[i].name === name)
                return slashModes[i].value;
        return -1;
    }

    // ── Chassis colour (not in DMI; per-model options) ───────────────
    readonly property var chassisOptions: {
        const b = board.toUpperCase();
        if (b.startsWith("GA403") || b.startsWith("GU605"))
            return [{ name: "Eclipse Gray", colour: "#55585d" }, { name: "Platinum White", colour: "#dcdcd8" }];
        if (b.startsWith("GA402") || b.startsWith("GA401"))
            return [{ name: "Moonlight White", colour: "#e4e4e0" }, { name: "Eclipse Gray", colour: "#4d4f53" }];
        return [{ name: "Eclipse Gray", colour: "#55585d" }, { name: "Platinum White", colour: "#dcdcd8" },
            { name: "Off Black", colour: "#202124" }, { name: "Moonlight White", colour: "#e4e4e0" }];
    }
    readonly property string chassisName: {
        const n = pluginData.chassis;
        return chassisOptions.some(o => o.name === n) ? n : chassisOptions[0].name;
    }
    readonly property color chassisColour: (chassisOptions.find(o => o.name === chassisName) || chassisOptions[0]).colour
    function setChassis(name) { saveSetting("chassis", name); }

    function wallpaperFor(screenName) {
        const w = (screenName && SessionData.getMonitorWallpaper) ? SessionData.getMonitorWallpaper(screenName) : "";
        return w || SessionData.wallpaperPath || "";
    }

    // ── Colour helpers + LED correction ──────────────────────────────
    function rgbToColor(a) {
        return Qt.rgba((a[0] || 0) / 255, (a[1] || 0) / 255, (a[2] || 0) / 255, 1);
    }
    function colorToRgb(c) {
        return [Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255)];
    }
    function hex(c) {
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }
    // LEDs are additive and much "hotter" than a screen: boost saturation in HSV,
    // then apply a gamma curve so mid-tones aren't driven near full current.
    function correct(c) {
        if (!correctionActive)
            return c;
        c = Qt.color(c);
        const h = c.hsvHue < 0 ? 0 : c.hsvHue;
        const s = Math.min(1, c.hsvSaturation * ledSaturation / 100);
        const boosted = Qt.hsva(h, s, c.hsvValue, 1);
        const g = ledGamma / 100;
        return Qt.rgba(Math.pow(boosted.r, g), Math.pow(boosted.g, g), Math.pow(boosted.b, g), 1);
    }
    function setCorrection(sat, gamma) {
        saveSetting("ledSaturation", sat);
        saveSetting("ledGamma", gamma);
        reapplyTimer.restart();
    }
    Timer {
        id: reapplyTimer
        interval: 250
        onTriggered: if (root.hasKeyboard && root.currentModeInfo.colours > 0) root.applyEffect({})
    }

    // Colour used for the bar pill / CC icon: the picked effect colour when it has one.
    readonly property color accentColor: {
        if (!kbOn)
            return Theme.surfaceVariantText;
        if (!tintPill || currentModeInfo.colours === 0)
            return Theme.primary;
        const c = kbDisplayColour1;
        const lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        return lum < 0.12 ? Theme.primary : c;
    }

    // ── Reading state ────────────────────────────────────────────────
    function applyState(text) {
        let s;
        try {
            s = JSON.parse(text);
        } catch (e) {
            console.warn("RogControl: bad state JSON:", e);
            return;
        }
        available = !!s.available;
        product = s.product || "";
        board = s.board || "";
        vendor = (s.vendor || "").replace("ASUSTeK COMPUTER INC.", "ASUS");
        bios = s.bios || "";
        onAc = s.onAc !== false;
        battery = s.battery || { capacity: -1, status: "" };
        pendingReboot = !!s.pendingReboot;
        platform = s.platform || {};

        const arm = {};
        (s.armoury || []).forEach(a => arm[a.attr] = a.props);
        armoury = arm;

        const f = {};
        (s.fans || []).forEach(x => f[x.profile] = x.curves);
        fans = f;

        const kb = (s.aura || [])[0];
        auraPath = kb ? kb.path : "";
        if (kb) {
            const p = kb.props;
            kbBrightness = p.Brightness;
            if (p.Brightness > 0)
                kbLastOnBrightness = p.Brightness;
            kbSupportedBrightness = p.SupportedBrightness && p.SupportedBrightness.length ? p.SupportedBrightness : [0, 1, 2, 3];
            kbSupportedModes = p.SupportedBasicModes || [];
            kbPowerZones = p.SupportedPowerZones || [];
            const pw = {};
            ((p.LedPower || [[]])[0] || []).forEach(z => pw[z[0]] = [z[1], z[2], z[3], z[4]]);
            kbPower = pw;
            const d = p.LedModeData;
            if (d) {
                kbMode = d[0];
                kbZone = d[1];
                kbColour1 = rgbToColor(d[2]);
                kbColour2 = rgbToColor(d[3]);
                kbSpeed = d[4];
                kbDirection = d[5];
                // Show the picked colour if the LEDs still hold what we sent for it,
                // otherwise something else changed them: show the raw LED colour.
                const picked = pluginData.kbPicked || {};
                kbDisplayColour1 = picked.s1 === hex(kbColour1) && picked.c1 ? picked.c1 : kbColour1;
                kbDisplayColour2 = picked.s2 === hex(kbColour2) && picked.c2 ? picked.c2 : kbColour2;
            }
        }

        const sl = (s.slash || [])[0];
        slashPath = sl ? sl.path : "";
        if (sl) {
            const p = sl.props;
            slashEnabled = p.Enabled;
            slashBrightness = p.Brightness;
            slashInterval = p.Interval;
            slashMode = p.Mode;
            const fl = {};
            slashFlagDefs.forEach(def => fl[def.key] = !!p[def.key]);
            slashFlags = fl;
        }
        loaded = true;
    }

    Process {
        id: stateProc
        command: ["sh", root.stateScript]
        stdout: StdioCollector {
            onStreamFinished: root.applyState(text)
        }
    }

    function refresh() {
        if (stateProc.running)
            refreshTimer.restart();
        else
            stateProc.running = true;
    }

    Timer {
        id: refreshTimer
        interval: 150
        onTriggered: root.refresh()
    }

    // asusd emits PropertiesChanged for property changes (ours, asusctl, Fn keys),
    // so one monitor keeps the UI live without polling.
    Process {
        id: monitor
        running: root.users > 0
        // Orphan-proof: a separate watcher kills gdbus as soon as either the shell
        // ($PPID) or this wrapper goes away (Quickshell SIGKILLs the wrapper on
        // teardown, so a trap alone never runs).
        command: ["sh", "-c", "p=$PPID; s=$$; gdbus monitor --system --dest " + root.svc + " & g=$!; "
            + "( while kill -0 $p 2>/dev/null && kill -0 $s 2>/dev/null; do sleep 2; done; kill $g 2>/dev/null ) >/dev/null 2>&1 & "
            + "wait $g"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("PropertiesChanged") !== -1 || line.indexOf("is owned by") !== -1)
                    refreshTimer.restart();
            }
        }
        onExited: if (root.users > 0) monitorRestart.start()
    }

    Timer {
        id: monitorRestart
        interval: 3000
        onTriggered: {
            monitor.running = true;
            root.refresh();
        }
    }


    // ── Writing (serialised queue) ───────────────────────────────────
    // A newer write with the same key replaces a queued one, so dragging a
    // slider doesn't pile up D-Bus calls. Failures surface as a toast.
    property var writeQueue: []
    property var currentWrite: null

    Process {
        id: writer
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim();
                if (msg.length > 0)
                    root.reportError(msg);
            }
        }
        onExited: Qt.callLater(root.pumpQueue)
    }

    function reportError(msg) {
        const short = msg.replace(/^.*?:\s*(org\.freedesktop\.DBus\.Error\.\w+:\s*)?/, "").split("\n")[0];
        console.warn("RogControl: write failed:", msg);
        if (typeof ToastService !== "undefined" && ToastService.showError)
            ToastService.showError("ASUS: " + short, msg);
        refreshTimer.restart();
    }

    function enqueue(key, args) {
        const q = writeQueue.filter(item => item.key !== key);
        q.push({ key: key, args: args });
        writeQueue = q;
        pumpQueue();
    }

    function pumpQueue() {
        if (writer.running)
            return;
        if (writeQueue.length === 0) {
            if (currentWrite !== null) {
                currentWrite = null;
                refreshTimer.restart(); // method calls don't emit PropertiesChanged
            }
            return;
        }
        currentWrite = writeQueue[0];
        writeQueue = writeQueue.slice(1);
        writer.command = currentWrite.args;
        writer.running = true;
    }

    function setProp(path, iface, prop, sig, values) {
        enqueue(path + prop, ["busctl", "--system", "set-property", svc, path, iface, prop, sig].concat(values.map(v => String(v))));
    }
    function callMethod(key, path, iface, method, sig, values) {
        const args = ["busctl", "--system", "call", svc, path, iface, method];
        if (sig)
            args.push(sig);
        enqueue(key, args.concat((values || []).map(v => String(v))));
    }

    // Keyboard
    function setKbBrightness(level) {
        if (!hasKeyboard)
            return;
        kbBrightness = level;
        if (level > 0)
            kbLastOnBrightness = level;
        setProp(auraPath, "xyz.ljones.Aura", "Brightness", "u", [level]);
    }
    function toggleKeyboard() {
        setKbBrightness(kbOn ? 0 : Math.max(1, kbLastOnBrightness));
    }
    function stepKbBrightness(delta) {
        const levels = kbSupportedBrightness.slice().sort();
        const idx = levels.indexOf(kbBrightness);
        const next = levels[Math.max(0, Math.min(levels.length - 1, (idx < 0 ? 0 : idx) + delta))];
        if (next !== kbBrightness)
            setKbBrightness(next);
    }

    // Writes the full effect: mode, zone, both colours (corrected), speed, direction.
    function applyEffect(changes) {
        if (!hasKeyboard)
            return;
        if (changes.mode !== undefined) kbMode = changes.mode;
        if (changes.colour1 !== undefined) kbDisplayColour1 = changes.colour1;
        if (changes.colour2 !== undefined) kbDisplayColour2 = changes.colour2;
        if (changes.speed !== undefined) kbSpeed = changes.speed;
        if (changes.direction !== undefined) kbDirection = changes.direction;
        const s1 = correct(kbDisplayColour1), s2 = correct(kbDisplayColour2);
        kbColour1 = s1;
        kbColour2 = s2;
        const picked = { c1: hex(kbDisplayColour1), c2: hex(kbDisplayColour2), s1: hex(s1), s2: hex(s2) };
        if (JSON.stringify(picked) !== JSON.stringify(pluginData.kbPicked || {}))
            saveSetting("kbPicked", picked);
        const c1 = colorToRgb(s1), c2 = colorToRgb(s2);
        setProp(auraPath, "xyz.ljones.Aura", "LedModeData", "(uu(yyy)(yyy)ss)",
            [kbMode, kbZone, c1[0], c1[1], c1[2], c2[0], c2[1], c2[2], kbSpeed, kbDirection]);
        if (!kbOn && changes.mode !== undefined)
            setKbBrightness(Math.max(1, kbLastOnBrightness));
    }

    function setKbPower(zone, stateIdx, on) {
        if (!hasKeyboard)
            return;
        const pw = Object.assign({}, kbPower);
        const cur = (pw[zone] || [false, false, false, false]).slice();
        cur[stateIdx] = on;
        pw[zone] = cur;
        kbPower = pw;
        const zones = Object.keys(pw);
        let vals = [zones.length];
        zones.forEach(z => vals = vals.concat([z].concat(pw[z])));
        setProp(auraPath, "xyz.ljones.Aura", "LedPower", "(a(ubbbb))", vals);
    }

    // Slash
    function setSlash(prop, sig, value) {
        if (hasSlash)
            setProp(slashPath, "xyz.ljones.Slash", prop, sig, [value]);
    }
    function setSlashEnabled(on) { slashEnabled = on; setSlash("Enabled", "b", on); }
    function setSlashBrightness(v) { slashBrightness = v; setSlash("Brightness", "y", v); }
    function setSlashInterval(v) { slashInterval = v; setSlash("Interval", "y", v); }
    function setSlashMode(v) { slashMode = v; setSlash("Mode", "y", v); }
    function setSlashFlag(key, on) {
        const f = Object.assign({}, slashFlags);
        f[key] = on;
        slashFlags = f;
        setSlash(key, "b", on);
    }

    // Platform
    function setPlatform(prop, sig, value) {
        const p = Object.assign({}, platform);
        p[prop] = value;
        platform = p;
        setProp("/xyz/ljones", "xyz.ljones.Platform", prop, sig, [value]);
    }
    function nextProfile() {
        callMethod("nextProfile", "/xyz/ljones", "xyz.ljones.Platform", "NextPlatformProfile", "", []);
    }
    function oneShotCharge() {
        callMethod("oneshot", "/xyz/ljones", "xyz.ljones.Platform", "OneShotFullCharge", "", []);
        if (typeof ToastService !== "undefined" && ToastService.showInfo)
            ToastService.showInfo("Charging to 100% once", "The charge limit returns after this cycle.");
    }
    function setTuning(on) {
        enqueue("tuning", ["asusctl", "profile", "tuning", on ? "true" : "false"]);
    }

    // Armoury firmware attributes
    function setArmoury(attr, v) {
        const a = Object.assign({}, armoury);
        a[attr] = Object.assign({}, a[attr], { CurrentValue: v });
        armoury = a;
        setProp("/xyz/ljones/asus_armoury/" + attr, "xyz.ljones.AsusArmoury", "CurrentValue", "i", [v]);
    }
    function restoreArmoury(attr) {
        callMethod("restore" + attr, "/xyz/ljones/asus_armoury/" + attr, "xyz.ljones.AsusArmoury", "RestoreDefault", "", []);
    }

    // Fan curves
    function setFanCurve(profile, fan, pwms, temps, enabled) {
        callMethod("fan" + profile + fan, "/xyz/ljones", "xyz.ljones.FanCurves", "SetFanCurve", "u(s(yyyyyyyy)(yyyyyyyy)b)",
            [profile, fan].concat(pwms).concat(temps).concat([enabled]));
    }
    function setFanCurveEnabled(profile, fan, on) {
        callMethod("fanEn" + profile + fan, "/xyz/ljones", "xyz.ljones.FanCurves", "SetProfileFanCurveEnabled", "usb", [profile, fan, on]);
    }
    function setFanCurvesEnabled(profile, on) {
        callMethod("fansEn" + profile, "/xyz/ljones", "xyz.ljones.FanCurves", "SetFanCurvesEnabled", "ub", [profile, on]);
    }
    function resetFanCurves(profile) {
        callMethod("fansReset" + profile, "/xyz/ljones", "xyz.ljones.FanCurves", "SetCurvesToDefaults", "u", [profile]);
    }

    // ── Follow the DMS/matugen accent ────────────────────────────────
    function syncThemeColours() {
        if (!followTheme || !hasKeyboard || currentModeInfo.colours === 0)
            return;
        const c1 = Theme.primary, c2 = Theme.secondary;
        if (hex(c1) === hex(kbDisplayColour1) && (currentModeInfo.colours < 2 || hex(c2) === hex(kbDisplayColour2)))
            return;
        applyEffect({ colour1: c1, colour2: c2 });
    }
    Timer {
        id: themeSyncTimer
        interval: 400
        onTriggered: root.syncThemeColours()
    }
    Connections {
        target: Theme
        function onPrimaryChanged() { themeSyncTimer.restart(); }
        function onSecondaryChanged() { themeSyncTimer.restart(); }
    }
    onFollowThemeChanged: themeSyncTimer.restart()
    onLoadedChanged: themeSyncTimer.restart()

}
