(ns solanum.config
  "Configuration loading functions."
  (:refer-clojure :exclude [load-file])
  (:require
    [clojure.spec.alpha :as s]
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [clojure.walk :as walk]
    [solanum.source.core :as source]
    [solanum.output.core :as output]
    [solanum.util :as u]
    [yaml.core :as yaml]))


; TODO: spec out config
#_
{:defaults {:tags ["solanum"], :ttl 60},
 :outputs [{:type "print"} {:host "riemann.example.com", :port 5555, :type "riemann"}],
 :sources [{:detailed false, :per_core false, :type "cpu", :usage_states {:critical 0.9, :warning 0.8}}
           {:period 60, :type "uptime"}
           {:load_states {:critical 8, :warning 4}, :type "load"}
           {:type "memory"}
           {:detailed false, :devices ["sda"], :type "diskstats"}
           {:detailed false, :interfaces ["wlan0"], :type "network"}
           {:attributes {:ttl 3600}, :expiry_states {:critical 30, :warning 180}, :host "www.google.com", :period 300, :type "certificate"}]}



;; ## File Loading

(defn- type-entry?
  "True if the value is a key-value tuple with the key `:type`."
  [x]
  (and (vector? x)
       (= 2 (count x))
       (= :type (first x))))


(defn- keywordize-type-tuple
  "If the given value is a type entry tuple, this returns a new tuple with the
  value cast to a keyword. Otherwise, returns the original value."
  [x]
  (if (type-entry? x)
    (update x 1 keyword)
    x))


(defn- keywordize-types
  "Coerce all values of a `:type` key into a keyword in the datastructure."
  [m]
  (walk/postwalk keywordize-type-tuple m))


(defn load-file
  "Load some configuration from a file."
  [path]
  (keywordize-types (yaml/from-file path)))


(defn merge-config
  "Merge configuration maps together to produce a combined config."
  [a b]
  {:defaults (u/merge-attrs (:defaults a) (:defaults b))
   :sources (u/merge-vec (:sources a) (:sources b))
   :outputs (u/merge-vec (:outputs a) (:outputs b))})



;; ## Plugin Construction

; TODO: dynamically load namespaces?

(defn initialize-plugins
  "Initialize all source and output plugins."
  [config]
  (-> config
      (update :sources (partial into [] (map source/initialize)))
      (update :outputs (partial into [] (map output/initialize)))))
