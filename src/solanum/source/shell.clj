(ns solanum.source.shell
  "Metrics source that executes a shell command."
  (:require
    [clojure.java.shell :as shell]
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [solanum.source.core :as source]))


;; ## Measurements

(defn- parse-metric
  "Parse a metric string as an integer or a float. Returns the number, or throws
  an exception if the metric is not a valid numeric literal."
  [metric]
  (if (str/includes? metric ".")
    (Double/parseDouble metric)
    (Long/parseLong metric)))


(defn- parse-attribute
  "Parse an attribute pair. Returns a tuple with the attribute and value, or
  nil if parsing failed."
  [attr]
  (if (str/includes? attr "=")
    (let [[k v] (str/split attr #"=" 2)]
      [(keyword k) v])
    (log/warn "Dropping invalid attribute pair:" (pr-str attr))))


(defn- parse-line
  "Parse a single line according to the line protocol, returning an event
  constructed from the parsed data. Returns nil if the line is blank or
  invalid."
  [line]
  (when-not (str/blank? line)
    (let [[service metric & attrs] (str/split line #"\t+")]
      (if-not (or (str/blank? service) (str/blank? metric))
        (try
          (let [metric (parse-metric metric)
                attrs (into {} (keep parse-attribute) attrs)]
            (assoc attrs
                   :service service
                   :metric metric))
          (catch Exception ex
            (log/warn "Failed to parse metrics line:"
                      (pr-str line)
                      (.getName (class ex))
                      (.getMessage ex))))
        (log/warn "Dropped invalid metrics line - missing service or metric:"
                  (pr-str line))))))


;; ## TCP Source

(defrecord ShellSource
  [shell command]

  source/Source

  (collect-events
    [this]
    (let [result (shell/sh shell "-s" :in command)]
      (if (zero? (:exit result))
        (->> (:out result)
             (str/split-lines)
             (into [] (keep parse-line)))
        (log/warn "Failed to execute shell command:"
                  (pr-str command)
                  (pr-str (:err result)))))))


(defmethod source/initialize :shell
  [config]
  (when-not (:command config)
    (throw (IllegalArgumentException.
             "Cannot initialize shell source without a command")))
  (map->ShellSource
    {:shell (:shell config (System/getenv "SHELL"))
     :command (:command config)}))
