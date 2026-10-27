// Stand-in for logid's util/log.h: messages are collected so the harness can
// report what logid would print while decoding a config.
#ifndef NEXO_STUB_LOG_H
#define NEXO_STUB_LOG_H

#include <string>
#include <vector>

namespace logid {
    enum LogLevel { RAWREPORT, DEBUG, INFO, WARN, ERROR };

    /// Every message passed to logPrintf, in order.
    extern std::vector<std::string> captured_log;

    void logPrintf(LogLevel level, const char* format, ...);
}

#endif
