# ABOUTME: Developer tasks: Fennel tests, lint and simulator, plus host tests for firmware C code.
# ABOUTME: Firmware builds use idf.py in firmware/ instead (see README).

FENNEL ?= fennel
FENNEL_PATH = fnl/?.fnl;sim/?.fnl;test/?.fnl

# Lua built like the firmware's espressif/lua component: 32-bit integers and floats.
LUA_VERSION = 5.5.1
LUA_SHA256 = 1c4b4068d67061f2a2231ad2b5422e77acea1487ea9890f6320af614f4373dce
LUA32_DIR = build/lua32
LUA32 = $(LUA32_DIR)/lua-$(LUA_VERSION)/src/lua

# Lua modules the firmware loads from its "assets" LittleFS partition.
BUNDLE_DIR = firmware/assets

.PHONY: test test32 lint sim firmware-test bundle bundle-check

test:
	$(FENNEL) --add-fennel-path "$(FENNEL_PATH)" test/run.fnl test/*_test.fnl

# Same suite on the firmware's number model.
test32: $(LUA32)
	$(LUA32) "$$(command -v $(FENNEL))" --add-fennel-path "$(FENNEL_PATH)" test/run.fnl test/*_test.fnl

$(LUA32):
	mkdir -p $(LUA32_DIR)
	curl -sSfL -o $(LUA32_DIR)/lua.tar.gz https://www.lua.org/ftp/lua-$(LUA_VERSION).tar.gz
	echo "$(LUA_SHA256)  $(LUA32_DIR)/lua.tar.gz" | shasum -a 256 -c -
	tar -xzf $(LUA32_DIR)/lua.tar.gz -C $(LUA32_DIR)
	$(MAKE) -C $(LUA32_DIR)/lua-$(LUA_VERSION) posix MYCFLAGS=-DLUA_32BITS

lint:
	fennel-ls --lint fnl/sendo/*.fnl sim/*.fnl test/*.fnl

sim:
	$(FENNEL) --add-fennel-path "$(FENNEL_PATH)" sim/main.fnl

# Compile the firmware logic to plain Lua: no Fennel runtime is needed on the device.
bundle:
	rm -rf $(BUNDLE_DIR)/sendo
	mkdir -p $(BUNDLE_DIR)/sendo
	for f in fnl/sendo/*.fnl; do \
		$(FENNEL) --compile "$$f" > "$(BUNDLE_DIR)/sendo/$$(basename "$$f" .fnl).lua" || exit 1; \
	done

# Run the compiled bundle the way the firmware does: 32-bit Lua, no Fennel,
# only the base, package, math, string and table libraries, a fake LED module.
bundle-check: bundle $(LUA32)
	$(LUA32) test/bundle_check.lua $(BUNDLE_DIR)

firmware-test:
	mkdir -p firmware/build-host
	$(CC) -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined -Ifirmware/main \
		firmware/main/rx_log.c firmware/test/rx_log_test.c \
		-o firmware/build-host/rx_log_test
	firmware/build-host/rx_log_test
