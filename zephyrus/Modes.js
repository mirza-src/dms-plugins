.pragma library

// One mode = one set of settings, applied together and kept by the daemons:
//   gpu      cardwire mode (cardwired persists it)
//   profile  asusd platform profile (asusd links EPP and fan curves to it)
//   limits   asus-armoury attributes, each one of
//              "min" | "max" | "default"   the firmware's value right now
//              "NN%"                       NN% of the way from min to max
//              a number                    watts / °C, clamped to the range
//            Ranges differ on AC and on battery (e.g. CPU SPL 15–80 W on AC,
//            15–35 W on battery), so the active mode is applied again on every
//            plug/unplug, at login and after resume.
//
// Edit freely while dms-plugin-dev runs: changes apply on the next selection.

var GPU = {
    integrated: 0,
    hybrid: 1,
    manual: 2,
    smart: 3,
    ultimate: 4
};
var GPU_NAMES = ["Integrated", "Hybrid", "Manual", "Smart", "Ultimate"];

var PROFILE = {
    balanced: 0,
    performance: 1,
    quiet: 2,
    lowPower: 3
};
var PROFILE_NAMES = ["Balanced", "Performance", "Quiet", "Low power"];
var PROFILE_ICONS = ["balance", "speed", "nest_eco_leaf", "battery_saver"];

var CPU = ["ppt_pl1_spl", "ppt_pl2_sppt", "ppt_pl3_fppt"];
var NV = ["nv_dynamic_boost", "nv_tgp", "nv_temp_target"];

var modes = [
    {
        id: "eco",
        name: "Eco",
        icon: "eco",
        description: "iGPU only (dGPU off), quiet, CPU at its lowest power",
        gpu: "integrated",
        profile: "quiet",
        limits: {
            ppt_pl1_spl: "min",
            ppt_pl2_sppt: "min",
            ppt_pl3_fppt: "min"
        }
    },
    {
        id: "silent",
        name: "Silent",
        icon: "volume_off",
        description: "Hybrid, quiet fans, moderate power",
        gpu: "hybrid",
        profile: "quiet",
        limits: {
            ppt_pl1_spl: "40%",
            ppt_pl2_sppt: "50%",
            ppt_pl3_fppt: "50%",
            nv_dynamic_boost: "min",
            nv_temp_target: "min"
        }
    },
    {
        id: "balanced",
        name: "Balanced",
        icon: "balance",
        description: "Hybrid, firmware defaults",
        gpu: "hybrid",
        profile: "balanced",
        limits: {
            ppt_pl1_spl: "default",
            ppt_pl2_sppt: "default",
            ppt_pl3_fppt: "default",
            nv_dynamic_boost: "default",
            nv_tgp: "default",
            nv_temp_target: "default"
        }
    },
    {
        id: "performance",
        name: "Performance",
        icon: "speed",
        description: "Hybrid, every limit at its maximum",
        gpu: "hybrid",
        profile: "performance",
        limits: {
            ppt_pl1_spl: "max",
            ppt_pl2_sppt: "max",
            ppt_pl3_fppt: "max",
            nv_dynamic_boost: "max",
            nv_tgp: "max",
            nv_temp_target: "max"
        }
    },
    {
        id: "gaming",
        name: "Gaming",
        icon: "sports_esports",
        description: "Panel on the dGPU, dGPU at full power, CPU trimmed",
        gpu: "ultimate",
        profile: "performance",
        // The CPU and dGPU share one power/thermal budget: full TGP and
        // dynamic boost for the dGPU, CPU sustained power trimmed (not
        // pinned) so the boost isn't eaten by the CPU; short CPU boosts stay.
        limits: {
            ppt_pl1_spl: "50%",
            ppt_pl2_sppt: "70%",
            ppt_pl3_fppt: "max",
            nv_dynamic_boost: "max",
            nv_tgp: "max",
            nv_temp_target: "max"
        }
    }
];

function byId(id) {
    for (var i = 0; i < modes.length; i++) {
        if (modes[i].id === id)
            return modes[i];
    }
    return null;
}

// Resolve a limit spec against an attribute {current, min, max, def}. Null
// when the attribute can't be changed right now (e.g. dGPU limits on
// battery, where min == max).
function resolve(spec, attr) {
    if (!attr || attr.min === undefined || attr.max === undefined || attr.max <= attr.min)
        return null;
    var v;
    if (spec === "min")
        v = attr.min;
    else if (spec === "max")
        v = attr.max;
    else if (spec === "default")
        v = attr.def;
    else if (typeof spec === "string" && spec.charAt(spec.length - 1) === "%")
        v = attr.min + (attr.max - attr.min) * parseFloat(spec) / 100;
    else
        v = Number(spec);
    if (v === undefined || isNaN(v))
        return null;
    return Math.round(Math.min(attr.max, Math.max(attr.min, v)));
}
