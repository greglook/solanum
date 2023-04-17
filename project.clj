(defproject mvxcvi/solanum "3.2.4-SNAPSHOT"
  :description "Local host monitoring daemon."
  :url "https://github.com/greglook/solanum"
  :license {:name "Public Domain"
            :url "http://unlicense.org/"}

  :aliases
  {"coverage" ["with-profile" "+coverage" "cloverage"]}

  :deploy-branches ["main"]
  :pedantic? :abort

  :dependencies
  [[org.clojure/clojure "1.11.1"]
   [org.clojure/data.json "2.4.0"]
   [org.clojure/tools.cli "1.0.214"]
   ;; TODO: switch directly to dialog interfaces?
   [org.clojure/tools.logging "1.2.4"]
   [com.amperity/dialog "2.0.115"]
   [http-kit "2.6.0"]
   [org.yaml/snakeyaml "2.0"]
   [riemann-clojure-client "0.5.4"]]

  :hiera
  {:cluster-depth 2
   :vertical false
   :show-external false
   :ignore-ns #{solanum.config}}

  :profiles
  {:repl
   {:pedantic? false
    :source-paths ["dev"]
    :jvm-opts ["-Ddialog.profile=repl"]
    :dependencies
    [[org.clojure/tools.namespace "1.4.4"]]}

   :test
   {:jvm-opts ["-Ddialog.profile=test"]}

   :coverage
   {:jvm-opts ["-Ddialog.profile=test"]
    :plugins
    [[org.clojure/clojure "1.11.1"]
     [lein-cloverage "RELEASE"]]}

   :svm
   {:java-source-paths ["svm/java"]
    :dependencies
    [[org.graalvm.nativeimage/svm "22.3.1" :scope "provided"]
     [com.github.clj-easy/graal-build-time "0.1.4"]]}

   :uberjar
   {:target-path "target/uberjar"
    :uberjar-name "solanum.jar"
    :global-vars {*assert* false}
    :jvm-opts ["-Dclojure.compiler.direct-linking=true"
               "-Dclojure.spec.skip-macros=true"]
    :main solanum.main
    :aot :all}})
