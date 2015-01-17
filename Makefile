# Allow to override the vim to use, e.g. /opt/vim-travis/bin/vim.
export VIM_BIN?=vim

test:
	test/run

# Interactive tests, keep Vader open.
testi: export VADER_KEEP=1
testi:
	test/run

# Manually invoke Vim, using the test setup.
# -X: do not connect to X server.
runvim:
	cd test && HOME=/dev/null $(VIM_BIN) -XNu vimrc -i viminfo

# Target for Travis (which sets CI=true already, but this allows to simulate it).
travis: CI=true
travis: test

# Targets for .vader files, absolute and relative.
# This can be used with `b:dispatch = ':Make %'` in Vim.
TESTS:=$(filter-out test/_%.vader,$(wildcard test/*.vader))
uniq = $(if $1,$(firstword $1) $(call uniq,$(filter-out $(firstword $1),$1)))
_TESTS_REL_AND_ABS:=$(call uniq,$(abspath $(TESTS)) $(TESTS))
$(_TESTS_REL_AND_ABS):
	test/run $@
.PHONY: $(_TESTS_REL_AND_ABS)

tags:
	ctags -R --langmap=vim:+.vader
.PHONY: tags

.PHONY: test travis
