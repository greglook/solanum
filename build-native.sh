#!/bin/bash

# https://www.astrecipes.net/blog/2018/07/20/cmd-line-apps-with-clojure-and-graalvm/

rm -f solanum

./graalvm-ce-1.0.0-rc7/bin/native-image \
    --report-unsupported-elements-at-runtime \
    -J-Xmx3G -J-Xms3G \
    --no-server \
    -jar solanum.jar
