// ABOUTME: Formats a received BLE write as one log line with exact hex and readable text.
// ABOUTME: Pure C with no ESP-IDF dependency, so it is tested on the host.

#pragma once

#include <stddef.h>
#include <stdint.h>

// Largest write logged: the maximum ATT attribute value length.
#define RX_LOG_DATA_MAX 512

// 64 covers the longest header and ` text="` (47 chars); each byte takes 2 hex
// chars and at most 4 escaped text chars; then the closing quote and NUL.
#define RX_LOG_LINE_MAX (64 + RX_LOG_DATA_MAX * 6 + 2)

// Writes "rx ms=<ms> conn=<conn> len=<n> hex=<hex> text=\"<text>\"" into out.
// Returns the line length, or 0 (with out set to "") if len exceeds
// RX_LOG_DATA_MAX or out_size is too small.
size_t rx_log_format(char *out, size_t out_size, uint32_t ms, uint16_t conn,
                     const uint8_t *data, size_t len);
