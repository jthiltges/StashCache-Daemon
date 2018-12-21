# Makefile for xcache-daemon


# ------------------------------------------------------------------------------
# Release information: Update for each release
# ------------------------------------------------------------------------------

PACKAGE := xcache
VERSION := 1.0.0


# ------------------------------------------------------------------------------
# Other configuration: May need to change for a release
# ------------------------------------------------------------------------------

LIBEXEC_FILES := src/xcache-reporter
INSTALL_LIBEXEC_DIR := usr/libexec/xcache
XROOTD_CONFIG := configs/Authfile-auth \
                 configs/Authfile-noauth \
                 configs/xcache-robots.txt \
                 configs/xrootd-stash-cache.cfg \
                 configs/xrootd-stash-origin.cfg \
                 configs/digauth.cfg

XROOTD_CONFIGD := configs/config.d/40-osg-http.cfg \
                  configs/config.d/40-osg-monitoring.cfg \
                  configs/config.d/40-osg-xcache.cfg \
                  configs/config.d/40-osg-paths.cfg \
                  configs/config.d/50-stash-cache-authz.cfg \
                  configs/config.d/50-stash-origin-authz.cfg \
                  configs/config.d/50-stash-origin-paths.cfg \
                  configs/config.d/50-stash-cache-logging.cfg \
                  configs/config.d/10-origin-site-local.cfg \
                  configs/config.d/10-cache-site-local.cfg

SYSTEMD_UNITS := configs/xrootd-renew-proxy.service \
                 configs/xrootd-renew-proxy.timer \
                 configs/xcache-reporter.service \
                 configs/xcache-reporter.timer \
                 configs/stash-cache-authfile.service \
                 configs/stash-cache-authfile.timer

INSTALL_XROOTD_DIR := etc/xrootd
INSTALL_SYSTEMD_UNITDIR := usr/lib/systemd/system
PYTHON_LIB := src/xrootd_cache_stats.py

DIST_FILES := $(LIBEXEC_FILES) $(PYTHON_LIB) Makefile


# ------------------------------------------------------------------------------
# Internal variables: Do not change for a release
# ------------------------------------------------------------------------------

DIST_DIR_PREFIX := dist_dir_
TARBALL_DIR := $(PACKAGE)-$(VERSION)
TARBALL_NAME := $(PACKAGE)-$(VERSION).tar.gz
UPSTREAM := /p/vdt/public/html/upstream
UPSTREAM_DIR := $(UPSTREAM)/$(PACKAGE)/$(VERSION)
INSTALL_PYTHON_DIR := $(shell python -c 'from distutils.sysconfig import get_python_lib; print get_python_lib()')


# ------------------------------------------------------------------------------

.PHONY: _default distclean install dist upstream check

_default:
	@echo "There is no default target; choose one of the following:"
	@echo "make install DESTDIR=path     -- install files to path"
	@echo "make dist                     -- make a distribution source tarball"
	@echo "make upstream [UPSTREAM=path] -- install source tarball to upstream cache rooted at path"
	@echo "make check                    -- use pylint to check for errors"


distclean:
	rm -f *.tar.gz
ifneq ($(strip $(DIST_DIR_PREFIX)),) # avoid evil
	rm -fr $(DIST_DIR_PREFIX)*
endif

install:
	mkdir -p $(DESTDIR)/$(INSTALL_LIBEXEC_DIR)
	install -p -m 0755 $(LIBEXEC_FILES) $(DESTDIR)/$(INSTALL_LIBEXEC_DIR)
	sed -i -e 's/##VERSION##/$(VERSION)/g' $(DESTDIR)/$(INSTALL_LIBEXEC_DIR)/xcache-reporter
	mkdir -p $(DESTDIR)/$(INSTALL_PYTHON_DIR)
	install -p -m 0644 $(PYTHON_LIB) $(DESTDIR)/$(INSTALL_PYTHON_DIR)
	mkdir -p $(DESTDIR)/$(INSTALL_XROOTD_DIR)
	# XRootD configuration files
	install -p -m 0644 $(XROOTD_CONFIG) $(DESTDIR)/$(INSTALL_XROOTD_DIR)
	ln -srf $(DESTDIR)/$(INSTALL_XROOTD_DIR)/xrootd-stash-cache.cfg $(DESTDIR)/$(INSTALL_XROOTD_DIR)/xrootd-stash-cache-auth.cfg
	mkdir -p $(DESTDIR)/$(INSTALL_XROOTD_DIR)/config.d
	install -p -m 0644 $(XROOTD_CONFIGD) $(DESTDIR)/$(INSTALL_XROOTD_DIR)/config.d
	# systemd unit files
	mkdir -p $(DESTDIR)/$(INSTALL_SYSTEMD_UNITDIR)
	install -p -m 0644 $(SYSTEMD_UNITS) $(DESTDIR)/$(INSTALL_SYSTEMD_UNITDIR)
	# systemd unit overrides
	mkdir -p $(DESTDIR)/$(INSTALL_SYSTEMD_UNITDIR)/xrootd@stash-cache.service.d
	install -p -m 0644 configs/10-stash-cache-overrides.conf $(DESTDIR)/$(INSTALL_SYSTEMD_UNITDIR)/xrootd@stash-cache.service.d
	mkdir -p $(DESTDIR)/$(INSTALL_SYSTEMD_UNITDIR)/xrootd@stash-cache-auth.service.d
	install -p -m 0644 configs/10-stash-cache-overrides.conf $(DESTDIR)/$(INSTALL_SYSTEMD_UNITDIR)/xrootd@stash-cache-auth.service.d
	install -p -m 0644 configs/10-stash-cache-overrides.conf $(DESTDIR)/$(INSTALL_SYSTEMD_UNITDIR)/xrootd@stash-cache-auth.service.d
	# systemd tempfiles
	mkdir -p $(DESTDIR)/run/stash-cache
	mkdir -p $(DESTDIR)/run/stash-cache-auth
	mkdir -p $(DESTDIR)/usr/lib/tmpfiles.d
	install -p -m 0644 configs/stash-cache.conf $(DESTDIR)/usr/lib/tmpfiles.d
	# Authfile updater scripts
	mkdir -p $(DESTDIR)/$(INSTALL_LIBEXEC_DIR)/
	install -p -m 0755 src/authfile-update src/renew-proxy $(DESTDIR)/$(INSTALL_LIBEXEC_DIR)/

$(TARBALL_NAME): $(DIST_FILES)
	$(eval TEMP_DIR := $(shell mktemp -d -p . $(DIST_DIR_PREFIX)XXXXXXXXXX))
	mkdir -p $(TEMP_DIR)/$(TARBALL_DIR)
	cp -pr $(DIST_FILES) $(TEMP_DIR)/$(TARBALL_DIR)/
	sed -i -e 's/##VERSION##/$(VERSION)/g' $(TEMP_DIR)/$(TARBALL_DIR)/xcache-reporter
	tar czf $(TARBALL_NAME) -C $(TEMP_DIR) $(TARBALL_DIR)
	rm -rf $(TEMP_DIR)

dist: $(TARBALL_NAME)

upstream: $(TARBALL_NAME)
ifeq ($(shell ls -1d $(UPSTREAM) 2>/dev/null),)
	@echo "Must have existing upstream cache directory at '$(UPSTREAM)'"
else ifneq ($(shell ls -1 $(UPSTREAM_DIR)/$(TARBALL_NAME) 2>/dev/null),)
	@echo "Source tarball already installed at '$(UPSTREAM_DIR)/$(TARBALL_NAME)'"
	@echo "Remove installed source tarball or increment release version"
else
	mkdir -p $(UPSTREAM_DIR)
	install -p -m 0644 $(TARBALL_NAME) $(UPSTREAM_DIR)/$(TARBALL_NAME)
	rm -f $(TARBALL_NAME)
endif

check:
	pylint -E $(LIBEXEC_FILES) $(PYTHON_LIB)

