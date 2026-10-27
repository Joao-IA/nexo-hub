// logid_config_check — reference decoder for differential tests.
//
// Decodes each file with logid 0.3.5's own config code (vendored, unmodified,
// in upstream/) and prints, per file, one JSON line describing exactly what
// logid understood:
//
//   {"file":"a.cfg","ok":{"devices":…,"ignore":…,"io_timeout":…,"workers":…,"log":[…]}}
//   {"file":"b.cfg","error":{"line":3,"text":"syntax error"}}   (libconfig parse error)
//
// Devices are normalized the way Device::_getConfig does when a device
// connects (flat form -> profile "default"; no profiles -> empty "default").
// `hiresscroll: <bool>` is reported as {"hires":<bool>} with the other fields
// null (only the hires bit is applied), and single keys of a Keypress action
// as a one-element list — both equivalent for logid.
//
// Encoding: strings as hex bytes, floats as the hex of their IEEE-754 bits,
// maps as [key, value] pairs in std::map order.
#include <libconfig.h++>

#include <config/schema.h>
#include <util/log.h>

#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <variant>

std::vector<std::string> logid::captured_log;

void logid::logPrintf(LogLevel, const char* format, ...) {
    char buffer[1024];
    va_list args;
    va_start(args, format);
    std::vsnprintf(buffer, sizeof buffer, format, args);
    va_end(args);
    captured_log.emplace_back(buffer);
}

namespace cfg = logid::config;

namespace {

void out(const char* s) { std::fputs(s, stdout); }

void outHex(const std::string& s) {
    static const char digits[] = "0123456789abcdef";
    std::putchar('"');
    for (unsigned char c : s) {
        std::putchar(digits[c >> 4]);
        std::putchar(digits[c & 0xF]);
    }
    std::putchar('"');
}

void outJsonText(const std::string& s) {
    std::putchar('"');
    for (unsigned char c : s) {
        if (c == '"' || c == '\\') {
            std::putchar('\\');
            std::putchar(c);
        } else if (c < 0x20) {
            std::printf("\\u%04x", c);
        } else {
            std::putchar(c);
        }
    }
    std::putchar('"');
}

void outDouble(double d) {
    std::uint64_t bits;
    std::memcpy(&bits, &d, sizeof bits);
    std::printf("\"%016llx\"", static_cast<unsigned long long>(bits));
}

template<typename T, typename F>
void outOpt(const std::optional<T>& o, F f) {
    if (o) f(*o); else out("null");
}

void outInt(int v) { std::printf("%d", v); }
void outUInt(unsigned v) { std::printf("%u", v); }
void outBool(bool v) { out(v ? "true" : "false"); }

void dumpBasic(const cfg::BasicAction& a);
void dumpGesture(const cfg::Gesture& g);

// ---- actions --------------------------------------------------------------

void dumpKeys(const std::variant<std::string, uint,
        std::list<std::variant<uint, std::string>>>& keys) {
    auto key = [](const std::variant<uint, std::string>& k) {
        if (std::holds_alternative<uint>(k)) {
            out("{\"code\":"); outUInt(std::get<uint>(k)); out("}");
        } else {
            out("{\"name\":"); outHex(std::get<std::string>(k)); out("}");
        }
    };
    out("[");
    if (std::holds_alternative<std::string>(keys)) {
        key(std::get<std::string>(keys));
    } else if (std::holds_alternative<uint>(keys)) {
        key(std::get<uint>(keys));
    } else {
        bool first = true;
        for (auto& k : std::get<std::list<std::variant<uint, std::string>>>(keys)) {
            if (!first) out(",");
            first = false;
            key(k);
        }
    }
    out("]");
}

void dumpIntList(const std::list<int>& l) {
    out("[");
    bool first = true;
    for (int v : l) {
        if (!first) out(",");
        first = false;
        outInt(v);
    }
    out("]");
}

void dumpOne(const cfg::NoAction&) { out("{\"type\":\"none\"}"); }
void dumpOne(const cfg::KeypressAction& a) {
    out("{\"type\":\"keypress\",\"keys\":");
    outOpt(a.keys, dumpKeys);
    out("}");
}
void dumpOne(const cfg::ToggleSmartShift&) { out("{\"type\":\"togglesmartshift\"}"); }
void dumpOne(const cfg::ToggleHiresScroll&) { out("{\"type\":\"togglehiresscroll\"}"); }
void dumpOne(const cfg::CycleDPI& a) {
    out("{\"type\":\"cycledpi\",\"dpis\":");
    outOpt(a.dpis, dumpIntList);
    out(",\"sensor\":");
    outOpt(a.sensor, outInt);
    out("}");
}
void dumpOne(const cfg::ChangeDPI& a) {
    out("{\"type\":\"changedpi\",\"inc\":");
    outOpt(a.inc, outInt);
    out(",\"sensor\":");
    outOpt(a.sensor, outInt);
    out("}");
}
void dumpOne(const cfg::ChangeHost& a) {
    out("{\"type\":\"changehost\",\"host\":");
    outOpt(a.host, [](const std::variant<int, std::string>& h) {
        if (std::holds_alternative<int>(h)) {
            out("{\"int\":"); outInt(std::get<int>(h)); out("}");
        } else {
            out("{\"string\":"); outHex(std::get<std::string>(h)); out("}");
        }
    });
    out("}");
}
void dumpOne(const cfg::ChangeProfile& a) {
    out("{\"type\":\"changeprofile\",\"profile\":");
    outOpt(a.profile, outHex);
    out("}");
}
void dumpOne(const cfg::GestureAction& a) {
    out("{\"type\":\"gestures\",\"gestures\":");
    outOpt(a.gestures, [](const auto& gestures) {
        out("[");
        bool first = true;
        for (auto& [direction, gesture] : gestures) {
            if (!first) out(",");
            first = false;
            out("[");
            outHex(direction);
            out(",");
            dumpGesture(gesture);
            out("]");
        }
        out("]");
    });
    out("}");
}

void dumpBasic(const cfg::BasicAction& a) {
    std::visit([](const auto& x) { dumpOne(x); }, a);
}

void dumpAction(const cfg::Action& a) {
    std::visit([](const auto& x) { dumpOne(x); }, a);
}

// ---- gestures -------------------------------------------------------------

void dumpGestureOne(const cfg::NoGesture& g) {
    out("{\"mode\":\"nopress\",\"threshold\":");
    outOpt(g.threshold, outInt);
    out("}");
}
void dumpGestureOne(const cfg::AxisGesture& g) {
    out("{\"mode\":\"axis\",\"threshold\":");
    outOpt(g.threshold, outInt);
    out(",\"axis\":");
    outOpt(g.axis, [](const std::variant<std::string, uint>& axis) {
        if (std::holds_alternative<std::string>(axis)) {
            out("{\"name\":"); outHex(std::get<std::string>(axis)); out("}");
        } else {
            out("{\"code\":"); outUInt(std::get<uint>(axis)); out("}");
        }
    });
    out(",\"axis_multiplier\":");
    outOpt(g.axis_multiplier, outDouble);
    out("}");
}
void dumpInterval(const char* mode, const cfg::IntervalGesture& g) {
    std::printf("{\"mode\":\"%s\",\"threshold\":", mode);
    outOpt(g.threshold, outInt);
    out(",\"action\":");
    outOpt(g.action, dumpBasic);
    out(",\"interval\":");
    outOpt(g.interval, outInt);
    out("}");
}
void dumpGestureOne(const cfg::FewPixelsGesture& g) { dumpInterval("onfewpixels", g); }
void dumpGestureOne(const cfg::IntervalGesture& g) { dumpInterval("oninterval", g); }
template<typename G>
void dumpThresholdLike(const char* mode, const G& g) {
    std::printf("{\"mode\":\"%s\",\"threshold\":", mode);
    outOpt(g.threshold, outInt);
    out(",\"action\":");
    outOpt(g.action, dumpBasic);
    out("}");
}
void dumpGestureOne(const cfg::ReleaseGesture& g) { dumpThresholdLike("onrelease", g); }
void dumpGestureOne(const cfg::ThresholdGesture& g) { dumpThresholdLike("onthreshold", g); }

void dumpGesture(const cfg::Gesture& g) {
    std::visit([](const auto& x) { dumpGestureOne(x); }, g);
}

// ---- profile ---------------------------------------------------------------

void dumpProfile(const cfg::Profile& p) {
    out("{\"dpi\":");
    outOpt(p.dpi, [](const cfg::DPI& dpi) {
        if (std::holds_alternative<int>(dpi)) {
            out("{\"int\":"); outInt(std::get<int>(dpi)); out("}");
        } else {
            out("{\"list\":"); dumpIntList(std::get<std::list<int>>(dpi)); out("}");
        }
    });
    out(",\"smartshift\":");
    outOpt(p.smartshift, [](const cfg::SmartShift& s) {
        out("{\"on\":"); outOpt(s.on, outBool);
        out(",\"threshold\":"); outOpt(s.threshold, outUInt);
        out(",\"torque\":"); outOpt(s.torque, outUInt);
        out("}");
    });
    out(",\"hiresscroll\":");
    outOpt(p.hiresscroll, [](const std::variant<bool, cfg::HiresScroll>& h) {
        if (std::holds_alternative<bool>(h)) {
            out("{\"hires\":"); outBool(std::get<bool>(h));
            out(",\"invert\":null,\"target\":null,\"up\":null,\"down\":null}");
            return;
        }
        auto& c = std::get<cfg::HiresScroll>(h);
        out("{\"hires\":"); outOpt(c.hires, outBool);
        out(",\"invert\":"); outOpt(c.invert, outBool);
        out(",\"target\":"); outOpt(c.target, outBool);
        out(",\"up\":"); outOpt(c.up, dumpGesture);
        out(",\"down\":"); outOpt(c.down, dumpGesture);
        out("}");
    });
    out(",\"thumbwheel\":");
    outOpt(p.thumbwheel, [](const cfg::ThumbWheel& t) {
        out("{\"divert\":"); outOpt(t.divert, outBool);
        out(",\"invert\":"); outOpt(t.invert, outBool);
        out(",\"left\":"); outOpt(t.left, dumpGesture);
        out(",\"right\":"); outOpt(t.right, dumpGesture);
        out(",\"proxy\":"); outOpt(t.proxy, dumpBasic);
        out(",\"touch\":"); outOpt(t.touch, dumpBasic);
        out(",\"tap\":"); outOpt(t.tap, dumpBasic);
        out("}");
    });
    out(",\"buttons\":");
    outOpt(p.buttons, [](const cfg::RemapButton& buttons) {
        out("[");
        bool first = true;
        for (auto& [cid, button] : buttons) {
            if (!first) out(",");
            first = false;
            std::printf("[%u,", static_cast<unsigned>(cid));
            outOpt(button.action, dumpAction);
            out("]");
        }
        out("]");
    });
    out("}");
}

// Mirrors Device::_getConfig (src/logid/Device.cpp L340-L366).
cfg::Device normalize(const std::variant<cfg::Device, cfg::Profile>& device) {
    cfg::Device d;
    if (std::holds_alternative<cfg::Profile>(device)) {
        d.profiles["default"] = std::get<cfg::Profile>(device);
        d.default_profile = std::string("default");
    } else {
        d = std::get<cfg::Device>(device);
        d.profiles = std::get<cfg::Device>(device).profiles;
        d.default_profile = std::string(std::get<cfg::Device>(device).default_profile);
    }
    if (d.profiles.empty()) {
        d.profiles["default"] = {};
        d.default_profile = std::string("default");
    }
    return d;
}

void dumpConfig(const cfg::Config& c) {
    out("{\"devices\":");
    outOpt(c.devices, [](const auto& devices) {
        out("[");
        bool first = true;
        for (auto& [name, raw] : devices) {
            if (!first) out(",");
            first = false;
            cfg::Device d = normalize(raw);
            out("{\"name\":");
            outHex(name);
            out(",\"default_profile\":");
            outHex(std::string(d.default_profile));
            out(",\"profiles\":[");
            bool firstProfile = true;
            for (auto& [profileName, profile] : d.profiles) {
                if (!firstProfile) out(",");
                firstProfile = false;
                out("[");
                outHex(profileName);
                out(",");
                dumpProfile(profile);
                out("]");
            }
            out("]}");
        }
        out("]");
    });
    out(",\"ignore\":");
    outOpt(c.ignore, [](const std::set<uint16_t>& ignore) {
        out("[");
        bool first = true;
        for (auto pid : ignore) {
            if (!first) out(",");
            first = false;
            std::printf("%u", static_cast<unsigned>(pid));
        }
        out("]");
    });
    out(",\"io_timeout\":");
    outOpt(c.io_timeout, outDouble);
    out(",\"workers\":");
    outOpt(c.workers, outInt);
    out(",\"log\":[");
    for (std::size_t i = 0; i < logid::captured_log.size(); ++i) {
        if (i) out(",");
        outJsonText(logid::captured_log[i]);
    }
    out("]}");
}

}  // namespace

int main(int argc, char** argv) {
    if (argc < 2) {
        std::fprintf(stderr, "usage: %s FILE...\n", argv[0]);
        return 2;
    }
    for (int i = 1; i < argc; ++i) {
        logid::captured_log.clear();
        libconfig::Config config;  // same defaults as logid's Configuration
        out("{\"file\":");
        outJsonText(argv[i]);
        try {
            config.readFile(argv[i]);
            // Same call chain as Configuration::Configuration().
            cfg::Config decoded = cfg::get<cfg::Config>(config.getRoot());
            out(",\"ok\":");
            dumpConfig(decoded);
        } catch (const libconfig::ParseException& e) {
            std::printf(",\"error\":{\"line\":%d,\"text\":", e.getLine());
            outJsonText(e.getError());
            out("}");
        } catch (const libconfig::FileIOException&) {
            std::fprintf(stderr, "error: cannot read %s\n", argv[i]);
            return 2;
        }
        out("}\n");
    }
    return 0;
}
