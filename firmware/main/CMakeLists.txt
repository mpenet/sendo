# ABOUTME: Component definition for the firmware's main code.
# ABOUTME: Lists sources and the ESP-IDF components they use.

idf_component_register(SRCS "main.c" "rx_log.c"
                       INCLUDE_DIRS "."
                       PRIV_REQUIRES bt nvs_flash esp_timer)
