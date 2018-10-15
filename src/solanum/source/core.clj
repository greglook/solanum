(ns solanum.source.core
  "Core event source protocol and methods."
  (:require
    [clojure.java.shell :as shell]
    [clojure.string :as str]
    [clojure.tools.logging :as log]))


(defprotocol Source
  "Source of metrics events."

  (collect-events
    [source]
    "Return a sequence of metrics events collected from the source."))


(defmulti initialize
  "Construct a new source from a type keyword."
  :type)


(defmethod initialize :default
  [config]
  (log/error "No source definition for type" (pr-str (:type config))))



;; ## Utilities

(def os-info
  "Delayed map with the local operating system's `:name` and `:release`, as
  returned by `uname`."
  (delay
    (try
      (let [result (shell/sh "uname" "-sr")]
        (if (zero? (:exit result))
          (zipmap
            [:name :release]
            (-> (:out result)
                (str/trim-newline)
                (str/split #" " 2)))
          (log/warn "Failed to determine operating system information:"
                    (pr-str (:err result)))))
      (catch Exception ex
        (log/error ex "Error while determining operating system information")))))


(defn detect-mode
  "Determine what mode to run the source in for compatibility with the
  local operating system."
  [source-type supported-modes requested default]
  (let [mode (or requested (keyword (str/lower-case (:name @os-info))))]
    (if (contains? supported-modes mode)
      mode
      (do (log/warnf "Unsupported %s source mode %s - falling back to %s"
                     source-type (pr-str mode) default)
          default))))


(defn duration-str
  "Convert a duration in seconds into a human-friendly representation."
  [duration]
  (let [days (int (/ duration 86400))
        hours (int (/ (mod duration 86400) 3600))
        minutes (int (/ (mod duration 3600) 60))
        seconds (int (mod duration 60))
        hms (format "%02d:%02d:%02d" hours minutes seconds)]
    (if (pos? days)
      (str days " days, " hms)
      hms)))


(defn state-over
  "Calculate the state of a metric by comparing it to the given thresholds. The
  metric is compared to each threshold in turn, largest to smallest. The first
  threshold the metric is larger than is returned, or the 'min-state' is
  returned.

  Use this with metrics where _higher values_ are worse; this lets you set
  thresholds like:

  ```yaml
  usage_states:
    warning: 0.8
    critical: 0.9
  ```"
  [thresholds metric min-state]
  (loop [thresholds (sort-by val (comp - compare) thresholds)]
    (if-let [[state threshold] (first thresholds)]
      (if (<= threshold metric)
        state
        (recur (next thresholds)))
      min-state)))


(defn state-under
  "Calculate the state of a metric by comparing it to the given thresholds. The
  metric is compared to each threshold in turn, smallest to largest. The first
  threshold the metric is smaller than is returned, or the 'max-state' is
  returned.

  Use this with metrics where _lower values_ are worse; this lets you set
  thresholds like:

  ```yaml
  expiry_states:
    warning: 180
    critical: 30
  ```"
  [thresholds metric max-state]
  (loop [thresholds (sort-by val thresholds)]
    (if-let [[state threshold] (first thresholds)]
      (if (< metric threshold)
        state
        (recur (next thresholds)))
      max-state)))
