// ABOUTME: Host tests for formatting received BLE writes as log lines.
// ABOUTME: Built with the system C compiler by `make firmware-test`, no ESP-IDF needed.

#include <stdio.h>
#include <string.h>

#include "rx_log.h"

static int failures = 0;

static void check_line(const char *name, const char *expected, const char *actual)
{
    if (strcmp(expected, actual) != 0) {
        failures++;
        printf("FAIL %s\n  expected: %s\n  actual:   %s\n", name, expected, actual);
    }
}

static void printable_bytes(void)
{
    char out[RX_LOG_LINE_MAX];
    const char *data = "l#S5,E";
    rx_log_format(out, sizeof out, 1234, 1, (const uint8_t *)data, strlen(data));
    check_line("printable_bytes",
               "rx ms=1234 conn=1 len=6 hex=6c2353352c45 text=\"l#S5,E\"", out);
}

static void escaped_bytes(void)
{
    char out[RX_LOG_LINE_MAX];
    const uint8_t data[] = {'a', 0xff, '"', '\\', '\n'};
    rx_log_format(out, sizeof out, 0, 2, data, sizeof data);
    check_line("escaped_bytes",
               "rx ms=0 conn=2 len=5 hex=61ff225c0a text=\"a\\xff\\\"\\\\\\x0a\"", out);
}

static void empty_write(void)
{
    char out[RX_LOG_LINE_MAX];
    rx_log_format(out, sizeof out, 7, 0, NULL, 0);
    check_line("empty_write", "rx ms=7 conn=0 len=0 hex= text=\"\"", out);
}

static void longest_write_fits(void)
{
    char out[RX_LOG_LINE_MAX];
    uint8_t data[RX_LOG_DATA_MAX];
    memset(data, 0xff, sizeof data);
    size_t n = rx_log_format(out, sizeof out, 4294967295u, 65535, data, sizeof data);
    if (n == 0 || n >= sizeof out || out[n] != '\0' || out[n - 1] != '"') {
        failures++;
        printf("FAIL longest_write_fits: n=%zu\n", n);
    }
}

static void oversized_write_is_rejected(void)
{
    char out[RX_LOG_LINE_MAX];
    uint8_t data[RX_LOG_DATA_MAX + 1] = {0};
    size_t n = rx_log_format(out, sizeof out, 0, 0, data, sizeof data);
    if (n != 0 || out[0] != '\0') {
        failures++;
        printf("FAIL oversized_write_is_rejected: n=%zu\n", n);
    }
}

int main(void)
{
    printable_bytes();
    escaped_bytes();
    empty_write();
    longest_write_fits();
    oversized_write_is_rejected();
    printf("rx_log: %d failures\n", failures);
    return failures == 0 ? 0 : 1;
}
