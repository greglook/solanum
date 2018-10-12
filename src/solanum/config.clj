(ns solanum.config
  "Configuration loading functions."
  (:refer-clojure :exclude [load-file])
  (:require
    [clojure.spec.alpha :as s]
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [clojure.walk :as walk]
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



;; ## Config Merging

(defn- tagged?
  "True if the attributes include some tag values."
  [x]
  (boolean (seq (:tags x))))


(defn- merge-tags
  "Combine two tag vectors together."
  [a b]
  (vec (distinct (concat a b))))


(defn- merge-attrs
  "Merge attribute maps, handling tags correctly."
  [a b]
  (let [attrs (merge a b)]
    (if (or (tagged? a) (tagged? b))
      (assoc attrs :tags (merge-tags (:tags a) (:tags b)))
      attrs)))


(defn- merge-list
  "Merge two vectors of configuration together by concatenating them."
  [a b]
  (into (vec a) b))


(defn merge-config
  "Merge configuration maps together to produce a combined config."
  [a b]
  {:defaults (merge-attrs (:defaults a) (:defaults b))
   :sources (merge-list (:sources a) (:sources b))
   :outputs (merge-list (:outputs a) (:outputs b))})
