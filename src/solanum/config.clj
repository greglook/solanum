(ns solanum.config
  "Configuration loading functions."
  (:require
    [clojure.java.io :as io]
    [clojure.spec.alpha :as s]
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [clojure.walk :as walk]
    [solanum.output.core :as output]
    [solanum.output.print]
    [solanum.output.riemann]
    [solanum.source.core :as source]
    [solanum.source.cpu]
    [solanum.source.disk-space]
    [solanum.source.disk-stats]
    [solanum.source.http]
    [solanum.source.load]
    [solanum.source.memory]
    [solanum.source.network]
    [solanum.source.process]
    [solanum.source.shell]
    [solanum.source.tcp]
    [solanum.source.test]
    [solanum.source.uptime]
    [solanum.system.core :as sys]
    [solanum.util :as u])
  (:import
    org.yaml.snakeyaml.Yaml))


;; ## File Loading

(defn- keybabify
  "Replace underscores in a keyword with hyphens. Only uses the name portion."
  [k]
  (keyword (str/replace (name k) "_" "-")))


(defn- coerce-map
  "Coerces a Java map into a Clojure map, keywordizing the keys and `:type`
  values."
  [m]
  (into {}
        (map (fn coerce-entry
               [[k v]]
               (let [k (keybabify k)]
                 [k (if (= :type k)
                      (keybabify v)
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


(defn- read-file
  "Load some configuration from a file."
  [file]
  (log/debug "Reading configuration file" (str file))
  (try
    (let [parser (Yaml.)
          data (.load parser (slurp file))]
      (walk/prewalk yaml->clj data))
    (catch Exception ex
      (log/error ex "Failed to load configuration from" (str file)))))


(defn- merge-config
  "Merge configuration maps together to produce a combined config."
  [a b]
  {:defaults (u/merge-attrs (:defaults a) (:defaults b))
   :sources (into (vec (:sources a)) (:sources b))
   :outputs (into (vec (:outputs a)) (:outputs b))})



;; ## Plugin Construction

(defn- configure-source
  "Construct and start a new metrics source from configuration."
  [mode config]
  (try
    (if (:type config)
      (let [config (into {:mode mode, :period 60} config)
            common (select-keys config [:type :mode :period :attributes])]
        (case (source/supported? config)
          true
          (some-> (source/initialize config)
                  (merge common))
          nil
          (some-> (source/initialize config)
                  (merge common)
                  (dissoc :mode))
          (log/warnf "Source %s does not support mode %s"
                     (name (:type config))
                     (name (:mode config)))))
      (log/warn "Cannot configure source without a type:" (pr-str config)))
    (catch Exception ex
      (log/error ex "Failed to initialize source:" (pr-str config)))))


(defn- configure-output
  "Construct and start a new metrics output from configuration."
  [config]
  (try
    (if (:type config)
      (output/initialize config)
      (log/warn "Cannot configure output without a type:" (pr-str config)))
    (catch Exception ex
      (log/error ex "Failed to initialize output:" (pr-str config)))))


(defn- initialize-plugins
  "Initialize all source and output plugins."
  [config]
  (let [mode (sys/detect-mode)
        sources (into []
                      (keep (partial configure-source mode))
                      (:sources config))
        outputs (into []
                      (keep configure-output)
                      (:outputs config))]
    (assoc (into {} config)
           :sources sources
           :outputs outputs)))


(defn- yaml-file?
  "True if the file or path appears to be a YAML file."
  [file]
  (or (str/ends-with? (str file) ".yml")
      (str/ends-with? (str file) ".yaml")))


(defn- select-configs
  "Select a sequence of configuration files located using the given arguments.
  If the argument is a regular file, it is returned as a single-element vector.
  If it is a directory, all `*.yml` and `*.yaml` files in the directory are
  selected. Otherwise, the result is nil."
  [path]
  (let [file (io/file path)]
    (cond
      (not (.exists file))
      (log/warn "Can't load configuration from nonexistent file" path)

      (.isDirectory file)
      (sort (filter yaml-file? (.listFiles file)))

      :else
      [file])))


(defn load-files
  "Load multiple files, merge them together, and initialize the plugins."
  [config-paths]
  ; TODO: warn if defaults include :host
  (->>
    config-paths
    (mapcat select-configs)
    (map read-file)
    (reduce merge-config)
    (initialize-plugins)))
