# Build file for Solanum

default: package

.PHONY: setup clean lint test uberjar package

version := $(shell grep defproject project.clj | cut -d ' ' -f 3 | tr -d \")
platform := $(shell uname -s | tr '[:upper:]' '[:lower:]')
release_name := solanum_$(version)_$(platform)

# TODO: fetch graal?
setup:
	lein deps

clean:
	rm -rf target dist solanum

lint:
	lein check

test:
	lein test

target/uberjar/solanum.jar: src/* resources/* svm/java/*
	lein with-profile +svm uberjar

uberjar: target/uberjar/solanum.jar

# TODO: --static ?
solanum: reflection-config := svm/reflection-config.json
solanum: target/uberjar/solanum.jar $(reflection-config)
	$(GRAAL_PATH)/bin/native-image \
	    --report-unsupported-elements-at-runtime \
	    --delay-class-initialization-to-runtime=io.netty.handler.ssl.ReferenceCountedOpenSslEngine \
	    -H:ReflectionConfigurationFiles=$(reflection-config) \
	    -J-Xmx3G -J-Xms3G \
	    --no-server \
	    -jar $<

dist/$(release_name).tar.gz: solanum
	@mkdir -p dist
	tar -cvzf $@ $^

package: dist/$(release_name).tar.gz
