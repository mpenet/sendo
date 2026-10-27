# ABOUTME: Developer tasks: Fennel tests, lint and simulator, plus host tests for firmware C code.
# ABOUTME: Firmware builds use idf.py in firmware/ instead (see README).

FENNEL ?= fennel
FENNEL_PATH = fnl/?.fnl;sim/?.fnl;test/?.fnl

.PHONY: test lint sim firmware-test

test:
	$(FENNEL) --add-fennel-path "$(FENNEL_PATH)" test/run.fnl test/*_test.fnl

lint:
	fennel-ls --lint fnl/sendo/*.fnl sim/*.fnl test/*.fnl

sim:
	$(FENNEL) --add-fennel-path "$(FENNEL_PATH)" sim/main.fnl

firmware-test:
	mkdir -p firmware/build-host
	$(CC) -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined -Ifirmware/main \
		firmware/main/rx_log.c firmware/test/rx_log_test.c \
		-o firmware/build-host/rx_log_test
	firmware/build-host/rx_log_test
