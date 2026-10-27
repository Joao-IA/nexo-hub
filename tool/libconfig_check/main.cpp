// libconfig_check — reference parser for differential tests.
//
// Parses each file given on the command line with the real libconfig++
// (the same library and default options logid uses in Configuration.cpp)
// and prints one JSON line per file:
//
//   {"file":"a.cfg","ok":<tree>}
//   {"file":"b.cfg","error":{"line":3,"text":"syntax error"}}
//
// Tree encoding (chosen so both sides can compare values exactly):
//   group  {"group":[["name",<value>],...]}   (source order)
//   list   {"list":[<value>,...]}
//   array  {"array":[<value>,...]}
//   int    {"int":<n>}       int64 {"int64":"<n>"}
//   float  {"float":"<16 hex digits of the IEEE-754 bits>"}
//   bool   {"bool":true|false}
//   string {"string":"<hex bytes>"}
//
// Exit code: 0 when every file was read (parse errors are reported inline),
// 2 on usage or I/O errors.
#include <libconfig.h++>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

namespace {

void printHex(const unsigned char* bytes, std::size_t length) {
    static const char digits[] = "0123456789abcdef";
    for (std::size_t i = 0; i < length; ++i) {
        std::putchar(digits[bytes[i] >> 4]);
        std::putchar(digits[bytes[i] & 0xF]);
    }
}

void printJsonString(const char* text) {
    std::putchar('"');
    for (const unsigned char* p = reinterpret_cast<const unsigned char*>(text); *p; ++p) {
        if (*p == '"' || *p == '\\') {
            std::putchar('\\');
            std::putchar(*p);
        } else if (*p < 0x20) {
            std::printf("\\u%04x", *p);
        } else {
            std::putchar(*p);
        }
    }
    std::putchar('"');
}

void dump(const libconfig::Setting& s) {
    using libconfig::Setting;
    switch (s.getType()) {
    case Setting::TypeGroup:
        std::fputs("{\"group\":[", stdout);
        for (int i = 0; i < s.getLength(); ++i) {
            if (i) std::putchar(',');
            std::putchar('[');
            printJsonString(s[i].getName());
            std::putchar(',');
            dump(s[i]);
            std::putchar(']');
        }
        std::fputs("]}", stdout);
        break;
    case Setting::TypeList:
    case Setting::TypeArray:
        std::fputs(s.getType() == Setting::TypeList ? "{\"list\":[" : "{\"array\":[", stdout);
        for (int i = 0; i < s.getLength(); ++i) {
            if (i) std::putchar(',');
            dump(s[i]);
        }
        std::fputs("]}", stdout);
        break;
    case Setting::TypeInt:
        std::printf("{\"int\":%d}", static_cast<int>(s));
        break;
    case Setting::TypeInt64:
        std::printf("{\"int64\":\"%lld\"}", static_cast<long long>(s));
        break;
    case Setting::TypeFloat: {
        const double value = s;
        std::uint64_t bits;
        std::memcpy(&bits, &value, sizeof bits);
        std::printf("{\"float\":\"%016llx\"}", static_cast<unsigned long long>(bits));
        break;
    }
    case Setting::TypeBoolean:
        std::printf("{\"bool\":%s}", static_cast<bool>(s) ? "true" : "false");
        break;
    case Setting::TypeString: {
        const char* text = s;
        std::fputs("{\"string\":\"", stdout);
        printHex(reinterpret_cast<const unsigned char*>(text), std::strlen(text));
        std::fputs("\"}", stdout);
        break;
    }
    default:
        std::fputs("{\"unknown\":null}", stdout);
    }
}

}  // namespace

int main(int argc, char** argv) {
    if (argc < 2) {
        std::fprintf(stderr, "usage: %s FILE...\n", argv[0]);
        return 2;
    }
    for (int i = 1; i < argc; ++i) {
        libconfig::Config config;  // default options, exactly like logid
        std::fputs("{\"file\":", stdout);
        printJsonString(argv[i]);
        try {
            config.readFile(argv[i]);
            std::fputs(",\"ok\":", stdout);
            dump(config.getRoot());
        } catch (const libconfig::ParseException& e) {
            std::printf(",\"error\":{\"line\":%d,\"text\":", e.getLine());
            printJsonString(e.getError());
            std::putchar('}');
        } catch (const libconfig::FileIOException&) {
            std::fprintf(stderr, "error: cannot read %s\n", argv[i]);
            return 2;
        }
        std::fputs("}\n", stdout);
    }
    return 0;
}
