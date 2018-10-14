(ns solanum.config
  "Configuration loading functions."
  (:refer-clojure :exclude [load-file])
  (:require
    [clojure.java.io :as io]
    [clojure.spec.alpha :as s]
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [clojure.walk :as walk]
    [solanum.source.core :as source]
    [solanum.output.core :as output]
    [solanum.util :as u])
  (:import
    org.yaml.snakeyaml.Yaml))


;; ## File Loading

(defn- coerce-map
  "Coerces a Java map into a Clojure map, keywordizing the keys and `:type`
  values."
  [m]
  (into {}
        (map (fn coerce-entry
               [[k v]]
               (let [k (keyword k)]
                 [k (if (= :type k)
                      (keyword v)
                      v)])))
        m))


(defn- yaml->clj
  "Coerces a YAML-loaded value into a corresponding Clojure equivalent, where
  appropriate. Mainly turns collections into their persistent equivalents, and
  keywordizes map keys and `:type` values."
  [x]
  (condp instance? x
    java.util.Map  (coerce-map x)
    java.util.Set  (set x)
    java.util.List (vec x)
    x))


(defn- load-file
  "Load some configuration from a file."
  [path]
  (let [file (io/file path)]
    (if (.exists file)
      (try
        (let [parser (Yaml.)
              data (.load parser (slurp file))]
          (walk/prewalk yaml->clj data))
          (catch Exception ex
            (log/error ex "Failed to load configuration from" path)))
      (log/warn "Can't load configuration from nonexistent file" path))))


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
