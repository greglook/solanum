(ns solanum.source.uptime
  "Metrics source that measures the uptime of a host."
  (:require
    [clojure.java.shell :as shell]
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [solanum.source.core :as source]
    [solanum.system.core :as sys]
    [solanum.system.linux :as linux]))


;; ## Measurements

(source/defsupport :uptime
  #{:linux :darwin})


(defn- measure-linux-uptime
  "Measure the number of seconds the Linux system has been running."
  []
  (let [uptime (linux/read-proc-file "/proc/uptime")]
    (Double/parseDouble (first (str/split uptime #" +")))))


(defn- measure-darwin-uptime
  "Measure the number of seconds the OS X system has been running."
  []
  (let [result (shell/sh "uptime")]
    (if (zero? (:exit result))
      (let [[days hours minutes] (->> (:out result)
                                      (re-seq #"up (\d+) days, +(\d+):(\d+),")
                                      (first)
                                      (rest))]
        (+ (* 86400 (Long/parseLong days))
           (*  3600 (Long/parseLong hours))
           (*    60 (Long/parseLong minutes))))
      (log/warn "Failed to measure uptime:" (pr-str (:err result))))))


;; ## Uptime Source

(defrecord UptimeSource
  []

  source/Source

  (collect-events
    [this]
    (let [seconds (case (:mode this)
                    :linux (measure-linux-uptime)
                    :darwin (measure-darwin-uptime))]
      [{:service "uptime"
        :metric (double seconds)
        :description (str "Up for " (source/duration-str seconds))}])))


(defmethod source/initialize :uptime
  [config]
  (map->UptimeSource {}))
