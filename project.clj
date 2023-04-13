(defproject mvxcvi/solanum "3.2.4-SNAPSHOT"
  :description "Local host monitoring daemon."
  :url "https://github.com/greglook/solanum"
  :license {:name "Public Domain"
            :url "http://unlicense.org/"}

  :aliases
  {"coverage" ["with-profile" "+coverage" "cloverage"]}

  :deploy-branches ["master"]
  :pedantic? :abort

  :dependencies
  [[org.clojure/clojure "1.10.3"]
   [org.clojure/data.json "2.4.0"]
   [org.clojure/tools.cli "1.0.206"]
   [org.clojure/tools.logging "1.1.0"]
   [ch.qos.logback/logback-classic "1.2.6"]
   [http-kit "2.5.3"]
   [org.yaml/snakeyaml "1.29"]
   [riemann-clojure-client "0.5.1"]]

  :hiera
  {:cluster-depth 2
   :vertical false
   :show-external false
   :ignore-ns #{solanum.config}}

  :profiles
  {:repl
   {:pedantic? false
    :source-paths ["dev"]
    :jvm-opts ["-DSOLANUM_LOG_APPENDER=repl"]
    :dependencies
    [[org.clojure/tools.namespace "1.1.0"]]}

   :test
   {:jvm-opts ["-DSOLANUM_LOG_APPENDER=nop"]}

   :coverage
   {:jvm-opts ["-DSOLANUM_LOG_APPENDER=nop"]
    :plugins
    [[org.clojure/clojure "1.10.3"]
     [lein-cloverage "1.1.2"]]}

   :svm
   {:java-source-paths ["svm/java"]
    :dependencies
    [[com.oracle.substratevm/svm "19.2.1" :scope "provided"]]}

   :uberjar
   {:target-path "target/uberjar"
    :uberjar-name "solanum.jar"
    :main solanum.main
    :jvm-opts ["-Dclojure.compiler.direct-linking=true"]
    :aot :all}})
