# Build file for Solanum

.PHONY: all clean check setup test uberjar set-version graal package

version := $(shell grep defproject project.clj | cut -d ' ' -f 3 | tr -d \")
platform := $(shell uname -s | tr '[:upper:]' '[:lower:]')
uberjar_path := target/uberjar/solanum.jar

# Graal settings
GRAAL_ROOT ?= /tmp/graal
GRAAL_VERSION ?= 22.3.1
GRAAL_HOME ?= $(GRAAL_ROOT)/graalvm-ce-java11-$(GRAAL_VERSION)
graal_archive := graalvm-ce-java11-$(platform)-amd64-$(GRAAL_VERSION).tar.gz

# Rewrite darwin as a more recognizable OS
ifeq ($(platform),darwin)
platform := macos
GRAAL_HOME := $(GRAAL_HOME)/Contents/Home
endif


all: solanum


### Utilities ###

clean:
	rm -rf dist solanum target

check:
	lein check

setup:
	lein deps

test:
	lein test

new-version=$(version)
set-version:
	@echo "Setting project and doc version to $(new-version)"
	@sed -i '' \
	    -e 's|^(defproject mvxcvi/solanum ".*"|(defproject mvxcvi/solanum "$(new-version)"|' \
	    project.clj
	@sed -i '' \
	    -e 's|mvxcvi/solanum ".*"|mvxcvi/solanum "$(new-version)"|' \
	    -e 's|SOLANUM_VERSION: .*|SOLANUM_VERSION: $(new-version)|' \
	    -e 's|solanum.git", :tag ".*"}|solanum.git", :tag "$(new-version)"}|' \
	    doc/integrations.md
	@echo "$(new-version)" > VERSION.txt


### GraalVM Install ###

$(GRAAL_ROOT)/fetch/$(graal_archive):
	@mkdir -p $(GRAAL_ROOT)/fetch
	curl --location --output $@ https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-$(GRAAL_VERSION)/$(graal_archive)

$(GRAAL_HOME): $(GRAAL_ROOT)/fetch/$(graal_archive)
	tar -xz -C $(GRAAL_ROOT) -f $<

$(GRAAL_HOME)/bin/native-image: $(GRAAL_HOME)
	$(GRAAL_HOME)/bin/gu install native-image

graal: $(GRAAL_HOME)/bin/native-image


### Local Build ###

SRC := project.clj $(shell find resources -type f) $(shell find src -type f)

$(uberjar_path): $(SRC)
	script/uberjar

uberjar: $(uberjar_path)

solanum: $(uberjar_path) $(GRAAL_HOME)/bin/native-image
	GRAAL_HOME=$(GRAAL_HOME) script/compile



#### Distribution Packaging ###

release_jar := solanum-$(version).jar
release_macos_tgz := solanum_$(version)_macos.tar.gz
release_macos_zip := solanum_$(version)_macos.zip
release_linux_tgz := solanum_$(version)_linux.tar.gz
release_linux_zip := solanum_$(version)_linux.zip
release_linux_static_zip := solanum_$(version)_linux_static.zip

# Uberjar
dist/$(release_jar): $(uberjar_path)
	@mkdir -p dist
	cp $< $@

# Mac OS X
ifeq ($(platform),macos)
dist/$(release_macos_tgz): solanum
	@mkdir -p dist
	tar -cvzf $@ $^

dist/$(release_macos_zip): solanum
	@mkdir -p dist
	zip $@ $^
endif

# Linux
target/package/linux/solanum: Dockerfile $(SRC)
	script/docker-build --output $@

dist/$(release_linux_tgz): target/package/linux/solanum
	@mkdir -p dist
	tar -cvzf $@ -C $(dir $<) $(notdir $<)

dist/$(release_linux_zip): target/package/linux/solanum
	@mkdir -p dist
	cd $(dir $<); zip $(abspath $@) $(notdir $<)

# Linux (static)
target/package/linux-static/solanum: Dockerfile $(SRC)
	script/docker-build --static --output $@

dist/$(release_linux_static_zip): target/package/linux-static/solanum
	@mkdir -p dist
	cd $(dir $<); zip $(abspath $@) $(notdir $<)

# Metapackage
ifeq ($(platform),macos)
package: dist/$(release_jar) dist/$(release_macos_tgz) dist/$(release_macos_zip) dist/$(release_linux_tgz) dist/$(release_linux_zip) dist/$(release_linux_static_zip)
else
package: dist/$(release_jar) dist/$(release_linux_tgz) dist/$(release_linux_zip) dist/$(release_linux_static_zip)
endif
