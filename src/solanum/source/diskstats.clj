(ns solanum.source.diskstats
  "Metrics source that measures the IO utilization of a host's block devices."
  (:require
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [solanum.source.core :as source]
    [solanum.system.core :as sys]
    [solanum.system.linux :as linux]))


(def supported-modes
  "Set of supported source modes."
  #{:linux})



;; ### Linux

(def ^:private linux-disk-fields
  "Fields in the diskstats proc file."
  [:reads-completed :reads-merged :read-sectors :read-time
   :writes-completed :writes-merged :write-sectors :write-time
   :io-active :io-time :io-weighted-time])


(defn- parse-disk-counters
  "Parse a line from `/proc/diskstats` into a tuple with the device name and
  a map of stat keys to numeric counter values."
  [line]
  (let [columns (str/split (str/trim line) #"\s+")
        [major minor device] (take 3 columns)
        counters (->> (drop 3 columns)
                      (map #(Long/parseLong %))
                      (zipmap linux-disk-fields))]
    [device counters]))


(defn- read-disk-stats
  "Read disk device counters from `/proc/diskstats`."
  []
  (into {}
        (map parse-disk-counters)
        (linux/read-proc-lines "/proc/diskstats")))


(defn- measure-linux
  "Measure disk IO on Linux systems by reading the proc subsystem."
  [tracker]
  (let [data (read-disk-stats)
        prev @tracker]
    (reset! tracker data)
    (when prev
      (source/diff-tracker prev data))))



;; ## Diskstats Source

(defrecord DiskStatsSource
  [mode tracker devices detailed]

  source/Source

  (collect-events
    [this]
    (let [info (case mode
                 :linux (measure-linux tracker))]
      (into []
            (comp
              (if (seq devices)
                (filter (comp (set devices) key))
                (filter #(re-matches #"(sd|xvd)[a-z]" (key %))))
              (mapcat
                (fn expand-events
                  [[device diffs]]
                  (keep
                    (fn [[service stat detailed-metric f]]
                      (when-let [metric (and (or detailed (not detailed-metric))
                                             (get diffs stat))]
                        {:service (str "diskstats " service)
                         :metric (if f (f metric) metric)
                         :device device}))
                    [["read bytes" :read-sectors false (partial * 512)]
                     ["read time" :read-time]
                     ["read completed" :reads-completed true]
                     ["read merged" :reads-merged true]
                     ["write bytes" :write-sectors false (partial * 512)]
                     ["write time" :write-time]
                     ["write completed" :writes-completed true]
                     ["write merged" :writes-merged true]
                     ["io active" :io-active]
                     ["io time" :io-time]
                     ["io weighted-time" :io-weighted-time]]))))
            info))))


(defmethod source/initialize :diskstats
  [config]
  (-> config
      (select-keys [:type :period :devices :detailed])
      (update :detailed boolean)
      (update :devices set)
      (assoc :mode (sys/detect :diskstats supported-modes (:mode config) :linux)
             :tracker (atom {}))
      (map->DiskStatsSource)))
