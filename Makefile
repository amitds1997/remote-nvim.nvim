NVIM := $(shell command -v nvim 2> /dev/null)
CUSTOM_NVIM :=

ifdef CUSTOM_NVIM
    NVIM := $(CUSTOM_NVIM)
endif

.PHONY: test
test:
	$(NVIM) --headless --noplugin -u tests/init.lua -c "lua require('plenary.test_harness').test_directory_command('tests/ {minimal_init = \"tests/init.lua\", sequential = true, timeout=20000}')"

.PHONY: test-file
test-file:
	$(NVIM) --headless --noplugin -u tests/init.lua -c "lua require('plenary.busted').run('$(FILE)')"

.PHONY: install-hooks
install-hooks:
	pre-commit install --install-hooks

.PHONY: check
check:
	pre-commit run --all-files

.PHONY: clean
clean:
	rm -rf .tests/

.PHONY: clean-test
clean-test: clean test
