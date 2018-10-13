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


(defn- load-file
  "Load some configuration from a file."
  [path]
  (keywordize-types (yaml/from-file path)))


(defn- merge-config
  "Merge configuration maps together to produce a combined config."
  [a b]
  {:defaults (u/merge-attrs (:defaults a) (:defaults b))
   :sources (u/merge-vec (:sources a) (:sources b))
   :outputs (u/merge-vec (:outputs a) (:outputs b))})



;; ## Plugin Construction

(defn- type->ns
  "Convert a type keyword into a symbol for a namespace where that type should
  be defined."
  [kind type-key]
  (let [type-name (name type-key)]
    (if (str/includes? type-name ".")
      (symbol type-name)
      (symbol (str "solanum." kind "." type-name)))))


(defn- autoload-type
  "Attempt to load the namespece where a type of plugin should be defined."
  [kind type-key]
  (let [type-ns (type->ns kind type-key)]
    (when-not (contains? (loaded-libs) type-ns)
      (try
        (require type-ns)
        (catch Exception ex
          (log/warn "Dynamic loading of" kind "ns" type-ns "failed:"
                    (.getMessage ex)))))))


(defn- configure-source
  "Construct and start a new metrics source from configuration."
  [source-config]
  (when-not (:type source-config)
    (throw (ex-info "Cannot configure source without a type"
                    {:config source-config})))
  (autoload-type "source" (:type source-config))
  (source/initialize (u/kebabify-keys source-config)))


(defn- configure-output
  "Construct and start a new metrics output from configuration."
  [output-config]
  (when-not (:type output-config)
    (throw (ex-info "Cannot configure output without a type"
                    {:config output-config})))
  (autoload-type "output" (:type output-config))
  (output/initialize (u/kebabify-keys output-config)))


(defn initialize-plugins
  "Initialize all source and output plugins."
  [config]
  (-> (into {} config)
      (update :sources (partial into [] (keep configure-source)))
      (update :outputs (partial into [] (keep configure-output)))))


(defn load-files
  "Load multiple files, merge them together, and initialize the plugins."
  [config-paths]
  (->> (map load-file config-paths)
       (reduce merge-config)
       (initialize-plugins)))
