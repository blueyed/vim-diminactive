test:
	test/run

testi: export VADER_KEEP=1
testi:
	test/run

manual:
	cd test && HOME=/dev/null vim -Nu vimrc -i viminfo

tryvis: CI=true
travis: test

.PHONY: test travis
