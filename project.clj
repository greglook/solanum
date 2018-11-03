(defproject mvxcvi/solanum "3.0.1-SNAPSHOT"
  :description "Local host monitoring daemon."
  :url "https://github.com/greglook/solanum"
  :license {:name "Public Domain"
            :url "http://unlicense.org/"}

  :deploy-branches ["master"]
  :pedantic? :abort

  :dependencies
  [[org.clojure/clojure "1.9.0"]
   [org.clojure/data.json "0.2.6"]
   [org.clojure/tools.cli "0.4.1"]
   [org.clojure/tools.logging "0.4.1"]
   [ch.qos.logback/logback-classic "1.2.3"]
   [clj-http-lite "0.3.0"]
   [org.yaml/snakeyaml "1.23"]
   [riemann-clojure-client "0.5.0"]]

  :hiera
  {:cluster-depth 2
   :vertical false
   :show-external false
   :ignore-ns #{solanum.config}}

  :profiles
  {:repl
   {:source-paths ["dev"]
    :dependencies
    [[clj-stacktrace "0.2.8"]
     [org.clojure/tools.namespace "0.2.11"]]
    :jvm-opts ["-DSOLANUM_LOG_APPENDER=repl"]}

   :test
   {:jvm-opts ["-DSOLANUM_LOG_APPENDER=nop"
               "-DSOLANUM_LOG_LEVEL_ROOT=TRACE"
               "-DSOLANUM_LOG_LEVEL=TRACE"]}

   :svm
   {:java-source-paths ["svm/java"]
    :dependencies
    [[com.oracle.substratevm/svm "1.0.0-rc8" :scope "provided"]]}

   :uberjar
   {:target-path "target/uberjar"
    :uberjar-name "solanum.jar"
    :main solanum.main
    :aot :all}})
