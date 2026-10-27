// Minimal stand-in for ipcgull::property (https://github.com/PixlOne/ipcgull),
// enough to compile logid's config headers outside the daemon. A property is
// a value holder; the D-Bus side is irrelevant for decoding a config file.
#ifndef NEXO_STUB_IPCGULL_PROPERTY_H
#define NEXO_STUB_IPCGULL_PROPERTY_H

// The real ipcgull headers bring these in transitively; logid relies on it.
#include <cstdint>
#include <string>
#include <utility>

namespace ipcgull {
    enum property_permissions {
        property_readable = 1,
        property_writeable = 2,
        property_full_permissions = 3,
    };

    template<typename T>
    class property {
        T _value;
    public:
        property(property_permissions, T value) : _value(std::move(value)) {}
        property(const property&) = default;
        property& operator=(const property&) = default;
        property& operator=(const T& value) {
            _value = value;
            return *this;
        }
        operator T() const { return _value; }
    };
}

#endif
