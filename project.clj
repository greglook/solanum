(defproject mvxcvi/solanum "3.0.0-SNAPSHOT"
  :description "Local host monitoring daemon."
  :url "https://github.com/greglook/solanum"
  :license {:name "Public Domain"
            :url "http://unlicense.org/"}

  :deploy-branches ["master"]
  :pedantic? :abort

  :dependencies
  [[org.clojure/clojure "1.9.0"]
   [org.clojure/tools.cli "0.4.1"]
   [org.clojure/tools.logging "0.4.1"]
   [org.yaml/snakeyaml "1.23"]
   [ch.qos.logback/logback-classic "1.2.3"]
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

   :uberjar
   {:target-path "target/uberjar"
    :uberjar-name "solanum.jar"
    :main solanum.main
    :aot :all}})