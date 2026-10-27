FENNEL ?= fennel
FENNEL_PATH = fnl/?.fnl;sim/?.fnl;test/?.fnl

.PHONY: test lint sim

test:
	$(FENNEL) --add-fennel-path "$(FENNEL_PATH)" test/run.fnl test/*_test.fnl

lint:
	fennel-ls --lint fnl/sendo/*.fnl sim/*.fnl test/*.fnl

sim:
	$(FENNEL) --add-fennel-path "$(FENNEL_PATH)" sim/main.fnl
