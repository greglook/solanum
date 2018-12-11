# Build file for Solanum

default: package

.PHONY: setup clean lint test uberjar package

uberjar_path := target/uberjar/solanum.jar
version := $(shell grep defproject project.clj | cut -d ' ' -f 3 | tr -d \")
platform := $(shell uname -s | tr '[:upper:]' '[:lower:]')
release_name := solanum_$(version)_$(platform)

ifndef GRAAL_PATH
$(error GRAAL_PATH is not set)
endif

# TODO: fetch graal?
setup:
	lein deps

clean:
	rm -rf target dist solanum

lint:
	lein check

test:
	lein test

$(uberjar_path): src/**/* resources/* svm/java/**/*
	lein with-profile +svm uberjar

uberjar: $(uberjar_path)

# TODO: --static ?
# --enable-url-protocols=http,https
solanum: reflection-config := svm/reflection-config.json
solanum: $(uberjar_path) $(reflection-config)
	$(GRAAL_PATH)/bin/native-image \
	    --report-unsupported-elements-at-runtime \
	    --delay-class-initialization-to-runtime=io.netty.handler.ssl.ReferenceCountedOpenSslEngine \
	    -H:ReflectionConfigurationFiles=$(reflection-config) \
	    -J-Xms3G -J-Xmx3G \
	    --no-server \
	    -jar $<

dist/$(release_name).tar.gz: solanum
	@mkdir -p dist
	tar -cvzf $@ $^

package: dist/$(release_name).tar.gz
