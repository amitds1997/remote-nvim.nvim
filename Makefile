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

kill-running-ssh-server:
	docker rm --force --ignore openssh-server

.PHONY: launch-ssh-server
launch-ssh-server: kill-running-ssh-server
	docker run -d --name=openssh-server --hostname=openssh-server \
	-e PUID=1000 -e PGID=1000 -e TZ=Etc/UTC -e SUDO_ACCESS=true \
	-e PASSWORD_ACCESS=true -e USER_PASSWORD=password -e USER_NAME=test-user \
	-p 2222:2222 --restart unless-stopped lscr.io/linuxserver/openssh-server:latest

.PHONY: clean
clean:
	rm -rf .tests/

.PHONY: clean-test
clean-test: clean test
