# Automation boilerplate

SHELL := /bin/bash
SN := $(shell hostname)
SUDO := $(shell test $${EUID} -ne 0 && echo "sudo")
.EXPORT_ALL_VARIABLES:

LOCAL=/usr/local
LOCAL_SCRIPTS=start-video.sh
CONFIG ?= /var/local
LIBSYSTEMD=/lib/systemd/system
PKGDEPS ?= gstreamer1.0-tools
SERVICES=video.service
SYSCFG=/etc/systemd

.PHONY = clean dependencies enable install provision see uninstall 

default:
	@echo "Please choose an action:"
	@echo ""
	@echo "  dependencies: ensure all needed software is installed (requires internet)"
	@echo "  install: update programs and system scripts"
	@echo "  provision: interactively define the needed configurations (all of them)"
	@echo ""
	@echo "The above are issued in the order shown above.  dependencies is only done once."
	@echo ""

$(SYSCFG)/video.conf:
	@echo ""
	@echo "Please answer the questions below to provision the video settings:"
	@echo ""
	@./provision.sh $@ $(DRY_RUN)

clean:
	@if [ -d src ] ; then cd src && make clean ; fi

dependencies:	
	@if [ ! -z "$(PKGDEPS)" ] ; then $(SUDO) apt-get install -y $(PKGDEPS) ; fi

disable:
	@( for c in stop disable ; do $(SUDO) systemctl $${c} $(SERVICES) ; done ; true )

enable:
	@( for c in stop disable ; do $(SUDO) systemctl $${c} $(SERVICES) ; done ; true )
	@( for s in $(SERVICES) ; do $(SUDO) install -Dm644 $${s%.*}.service $(LIBSYSTEMD)/$${s%.*}.service ; done ; true )
	@if [ ! -z "$(SERVICES)" ] ; then $(SUDO) systemctl daemon-reload ; fi
	@( for s in $(SERVICES) ; do $(SUDO) systemctl enable $${s%.*} ; done ; true )

install: dependencies
	@for s in $(LOCAL_SCRIPTS) ; do $(SUDO) install -Dm755 $${s} $(LOCAL)/bin/$${s} ; done
	@./ensure-elp-driver.sh	
	@$(MAKE) --no-print-directory -B $(SYSCFG)/video.conf $(DRY_RUN)
	@$(MAKE) --no-print-directory enable

provision:
	$(MAKE) --no-print-directory -B $(SYSCFG)/video.conf $(DRY_RUN)
	$(SUDO) systemctl restart video

see:
	$(SUDO) cat $(SYSCFG)/video.conf

uninstall:
	@$(MAKE) --no-print-directory disable
	@( for s in $(SERVICES) ; do $(SUDO) rm $(LIBSYSTEMD)/$${s%.*}.service ; done ; true )
	@if [ ! -z "$(SERVICES)" ] ; then $(SUDO) systemctl daemon-reload ; fi
	$(SUDO) rm -f $(SYSCFG)/video.conf


