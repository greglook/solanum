(defproject mvxcvi/solanum "0.1.0-SNAPSHOT"
  :description "Local host monitoring daemon."
  :url "https://github.com/greglook/solanum"
  :license {:name "Public Domain"
            :url "http://unlicense.org/"}

  :deploy-branches ["master"]
  :pedantic? :abort

  :dependencies
  [[org.clojure/clojure "1.9.0"]
   [org.clojure/tools.logging "0.4.1"]
   ;[amperity/envoy "0.3.1"]
   ;[com.stuartsierra/component "0.3.2"]
   ;[manifold "0.1.6"]
   [riemann-clojure-client "0.4.2"]]

  :profiles
  {:repl
   {:source-paths ["dev"]}

   :test
   {:dependencies [[commons-logging "1.2"]]
    :jvm-opts ["-Dorg.apache.commons.logging.Log=org.apache.commons.logging.impl.NoOpLog"]}})
