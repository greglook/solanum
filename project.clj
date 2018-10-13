(defproject mvxcvi/solanum "0.1.0-SNAPSHOT"
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
   [io.forward/yaml "1.0.9"]
   [ch.qos.logback/logback-classic "1.1.7"]
   [riemann-clojure-client "0.5.0"]]

  :profiles
  {:repl
   {:source-paths ["dev"]
    :dependencies
    [[clj-stacktrace "0.2.8"]
     [org.clojure/tools.namespace "0.2.11"]]}

   :test
   {:jvm-opts ["-Dlogback-appender=nop"
               "-Dlogback-level-root=TRACE"
               "-Dlogback-level-solanum=TRACE"]}

   :uberjar
   {:target-path "target/uberjar"
    :uberjar-name "solanum.jar"
    :main solanum.main
    :aot :all}})
