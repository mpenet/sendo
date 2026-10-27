// ABOUTME: The Lua task: runs the Fennel-compiled firmware logic on queued Bluetooth events.
// ABOUTME: Mounts the "assets" LittleFS partition and loads modules from it with require().

#pragma once

// FreeRTOS task entry. `queue` is a QueueHandle_t of event_t (events.h).
// Owns the only Lua state: starts it, prints the self-check, loads
// sendo.firmware and then feeds it every event from the queue.
void lua_runtime_task(void *queue);
