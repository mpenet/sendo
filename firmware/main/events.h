// ABOUTME: Events passed from the Bluetooth callbacks to the Lua task through a FreeRTOS queue.
// ABOUTME: Lua is not thread-safe, so only the Lua task touches the Lua state.

#pragma once

#include <stdint.h>

#include "rx_log.h"

// Writes are logged and queued whole, so both share the same size limit.
#define EVENT_DATA_MAX RX_LOG_DATA_MAX

typedef enum {
    EVENT_RECEIVED,
    EVENT_DISCONNECTED,
} event_type_t;

typedef struct {
    event_type_t type;
    uint16_t conn;
    uint16_t len;                   // EVENT_RECEIVED only
    uint8_t data[EVENT_DATA_MAX];   // EVENT_RECEIVED only
} event_t;
