test:
	test/run

testi: export VADER_KEEP=1
testi:
	test/run

# Manually invoke Vim, using the test setup.
# -X: do not connect to X server.
manual:
	cd test && HOME=/dev/null vim -XNu vimrc -i viminfo

travis: CI=true
travis: test

.PHONY: test travis
