(ns solanum.source.core
  "Core event source protocol and methods."
  (:require
    [clojure.java.shell :as sh]
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
      (let [result (sh/sh "uname" "-sr")]
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
  threshold the metric is larger than is returned, or the 'min-sate' is
  returned."
  [min-state thresholds metric]
  (loop [thresholds (sort-by val (comp - compare) thresholds)]
    (if-let [[state threshold] (first thresholds)]
      (if (<= threshold metric)
        state
        (recur (next thresholds)))
      min-state)))


(defn state-under
  "Calculate the state of a metric by comparing it to the given thresholds. The
  metric is compared to each threshold in turn, smallest to largest. The first
  threshold the metric is smaller than is returned, or the 'max-sate' is
  returned."
  [max-state thresholds metric]
  (loop [thresholds (sort-by val thresholds)]
    (if-let [[state threshold] (first thresholds)]
      (if (< metric threshold)
        state
        (recur (next thresholds)))
      max-state)))
