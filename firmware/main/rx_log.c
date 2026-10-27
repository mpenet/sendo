// ABOUTME: Formats a received BLE write as one log line with exact hex and readable text.
// ABOUTME: Printable ASCII appears as is; quotes, backslashes and other bytes are escaped.

#include "rx_log.h"

#include <stdio.h>
#include <string.h>

static const char hex_digits[] = "0123456789abcdef";
static const char text_label[] = " text=\"";

size_t rx_log_format(char *out, size_t out_size, uint32_t ms, uint16_t conn,
                     const uint8_t *data, size_t len)
{
    if (out_size == 0) {
        return 0;
    }
    out[0] = '\0';
    if (len > RX_LOG_DATA_MAX || out_size < RX_LOG_LINE_MAX) {
        return 0;
    }

    int header = snprintf(out, out_size, "rx ms=%lu conn=%u len=%u hex=",
                          (unsigned long)ms, (unsigned)conn, (unsigned)len);
    size_t n = (size_t)header;

    for (size_t i = 0; i < len; i++) {
        out[n++] = hex_digits[data[i] >> 4];
        out[n++] = hex_digits[data[i] & 0x0f];
    }

    memcpy(out + n, text_label, sizeof text_label - 1);
    n += sizeof text_label - 1;
    for (size_t i = 0; i < len; i++) {
        uint8_t b = data[i];
        if (b == '"' || b == '\\') {
            out[n++] = '\\';
            out[n++] = (char)b;
        } else if (b >= 0x20 && b <= 0x7e) {
            out[n++] = (char)b;
        } else {
            out[n++] = '\\';
            out[n++] = 'x';
            out[n++] = hex_digits[b >> 4];
            out[n++] = hex_digits[b & 0x0f];
        }
    }
    out[n++] = '"';
    out[n] = '\0';
    return n;
}
