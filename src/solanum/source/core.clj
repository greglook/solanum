(ns solanum.source.core
  "Core event source protocol and methods."
  (:require
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



;; ## Event Helpers

(defn stopwatch
  "Constructs a delayed value which will yield the number of milliseconds
  elapsed since its construction when realized."
  []
  (let [start (System/nanoTime)]
    (delay
      (/ (- (System/nanoTime) start) 1e6))))


(defn byte-str
  "Format a byte size into a human-friendly string representation."
  [size]
  (loop [suffixes ["B" "KB" "MB" "GB" "TB" "PB"]
         size size]
    (if (and (< 1024 size) (next suffixes))
      (recur (next suffixes) (/ size 1024))
      (if (integer? size)
        (format "%d %s" size (first suffixes))
        (format "%.1f %s" (double size) (first suffixes))))))


(defn duration-str
  "Format a duration in seconds into a human-friendly string representation."
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
  threshold the metric is larger than or equal to is returned, or the
  'min-state' is returned.

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
  threshold the metric is smaller than or equal to is returned, or the
  'max-state' is returned.

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
      (if (<= metric threshold)
        state
        (recur (next thresholds)))
      max-state)))


(defn diff-counters
  "Calculate the _difference_ between two maps of monotonically-increasing
  counter values. Expects `then` and `now` to be maps of counter keys to
  numeric values. Returns a map with each key present in both inputs with the
  difference as the value."
  [then now]
  (into {}
        (keep
          (fn diff
            [k]
            (let [a (get then k)
                  b (get now k)]
              (when (and a b)
                [k (- b a)]))))
        (keys now)))


(defn diff-tracker
  "Calculate the difference between several entities in a tracker map,
  identified by a key pointing to a map of counter values. Passes each entity's
  counters to `diff-counters` for processing."
  [then now]
  (into {}
        (map (fn diff-entity
               [[id counters]]
               [id (diff-counters (get then id) counters)]))
        now))
