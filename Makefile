FENNEL ?= fennel
FENNEL_PATH = fnl/?.fnl;test/?.fnl

.PHONY: test lint

test:
	$(FENNEL) --add-fennel-path "$(FENNEL_PATH)" test/run.fnl test/*_test.fnl

lint:
	fennel-ls --lint fnl/sendo/*.fnl test/*.fnl
