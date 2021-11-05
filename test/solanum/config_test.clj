(ns solanum.config-test
  (:require
    [clojure.java.io :as io]
    [clojure.test :refer [deftest testing is]]
    [solanum.config :as config]
    [solanum.output.core :as output]
    [solanum.source.core :as source]
    [solanum.test-util :refer [boom!]]))


(def path-a "target/test/config-a.yml")
(def path-b "target/test/config-b.yml")


(def config-a
  "---
defaults:
  stack: foo
  ttl: 60
  tags:
    - solanum

sources:
  - type: cpu

outputs:
  - type: print
")


(def config-b
  "---
defaults:
  sys: bar
  tags:
    - abc

sources:
  - type: memory

outputs:
  - type: print
")


(defn write-configs!
  []
  (io/make-parents path-a)
  (spit path-a config-a)
  (spit path-b config-b))


(deftest config-errors
  (write-configs!)
  (testing "file reading"
    (with-redefs [config/yaml->clj boom!]
      (is (nil? (#'config/read-file path-a)))))
  (testing "source configuration"
    (is (nil? (#'config/configure-source :linux {:foo :bar})))
    (is (nil? (source/initialize {:type :???})))
    (with-redefs [solanum.source.core/initialize boom!]
      (is (nil? (#'config/configure-source :abc {:type :foo})))))
  (testing "output configuration"
    (is (nil? (#'config/configure-output {:foo :bar})))
    (is (nil? (output/initialize {:type :???})))
    (with-redefs [solanum.output.core/initialize boom!]
      (is (nil? (#'config/configure-output {:type :foo}))))))


(deftest config-loading
  (write-configs!)
  (let [config (config/load-files [path-a path-b])]
    (is (= {:stack "foo"
            :sys "bar"
            :tags ["solanum" "abc"]
            :ttl 60}
           (:defaults config))
        "defaults should be merged")
    (is (= [:cpu :memory]
           (map :type (:sources config)))
        "sources should be merged")
    (is (= [:cpu :memory]
           (map :type (:sources config)))
        "sources should be merged")
    (is (= [:print :print]
           (map :type (:outputs config)))
        "outputs should be merged")))
