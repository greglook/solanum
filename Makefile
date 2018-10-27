# Build file for Solanum
#
# https://www.astrecipes.net/blog/2018/07/20/cmd-line-apps-with-clojure-and-graalvm/
# https://medium.com/graalvm/instant-netty-startup-using-graalvm-native-image-generation-ed6f14ff7692

default: lint

.PHONY: setup clean lint test uberjar

# TODO: fetch graal?

setup:
	lein deps

clean:
	rm -rf target solanum

lint:
	lein check

test:
	lein test

target/uberjar/solanum.jar: src/* resources/* svm/java/*
	lein with-profile +svm uberjar

uberjar: target/uberjar/solanum.jar

solanum: reflection-config=svm/reflection-config.json
solanum: target/uberjar/solanum.jar $(reflection-config)
	$(GRAAL_PATH)/bin/native-image \
	    --report-unsupported-elements-at-runtime \
	    -H:ReflectionConfigurationFiles=$(reflection-config) \
	    -J-Xmx3G -J-Xms3G \
	    --no-server \
	    -jar $<

# seems to be automatic because of --report-unsupported-elements-at-runtime
#--delay-class-initialization-to-runtime=io.netty.handler.ssl.ReferenceCountedOpenSslEngine \
