SHELL := /bin/bash

SOURCE_DIR ?= test_source
QUARANTINE_DIR ?= test_quarantine
INTERVAL ?= 3

.PHONY: all prepare antivirus restore cron clean

all: prepare

prepare:
	mkdir -p "$(SOURCE_DIR)" "$(QUARANTINE_DIR)"
	touch whitelist.txt

antivirus: prepare
	bash antivirusd.sh "$(SOURCE_DIR)" "$(QUARANTINE_DIR)" "$(INTERVAL)"

restore: prepare
	bash restore.sh "$(SOURCE_DIR)" "$(QUARANTINE_DIR)"

cron: prepare
	bash antivirus-cron.sh "$(SOURCE_DIR)" "$(QUARANTINE_DIR)"

clean:
	rm -f directory-info.last directory-info.new
