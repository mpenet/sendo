# ABOUTME: Component definition for the firmware's main code.
# ABOUTME: Also rebuilds the Lua bundle from fnl/ and packs it into the "assets" LittleFS image.

idf_component_register(SRCS "main.c" "rx_log.c" "lua_runtime.c"
                       INCLUDE_DIRS "."
                       PRIV_REQUIRES bt nvs_flash esp_timer)

# Compile fnl/ to firmware/assets/ on every build, so the image never holds stale Lua.
get_filename_component(repo_root "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)
add_custom_target(sendo_bundle
                  COMMAND make -C "${repo_root}" bundle
                  COMMENT "Compiling Fennel to Lua (make bundle)")

littlefs_create_partition_image(assets ../assets FLASH_IN_PROJECT DEPENDS sendo_bundle)
