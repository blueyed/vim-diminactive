test:
	test/run

testi: export VADER_KEEP=1
testi:
	test/run

tryvis: CI=true
travis: test

.PHONY: test travis
