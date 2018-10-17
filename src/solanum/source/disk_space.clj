(ns solanum.source.disk-space
  "Metrics source that measures the disk space usage of a host's filesystems."
  (:require
    [clojure.java.shell :as shell]
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [solanum.source.core :as source]
    [solanum.system.core :as sys]))


(def supported-modes
  "Set of supported source modes."
  #{:linux})



;; ### Linux

(defn- parse-disk-info
  "Parse a line from `df` into a map with the filesystem name, mount point, and
  usage info."
  [line]
  (let [columns (str/split (str/trim line) #"\s+")
        [filesystem total used available capacity mount] columns
        total (Long/parseLong total)
        used (Long/parseLong used)]
    {:filesystem filesystem
     :mount mount
     :total (* 1024 total)
     :used (* 1024 used)
     :usage (double (/ used total))}))


(defn- measure-linux
  "Measure disk space on Linux systems by calling `df`."
  []
  (let [result (shell/sh "df" "--local" "--portability" "--exclude-type" "iso9660")]
    (if (zero? (:exit result))
      (into []
            (comp
              (drop 1)
              (map parse-disk-info))
            (str/split (:out result) #"\n"))
      (log/warn "Failed to measure disk space:" (pr-str (:err result))))))



;; ## Disk Space Source

(defn- usage-event
  "Construct a metric event for the filesystem usage data."
  [data]
  {:service "disk-space usage"
   :metric (:usage data)
   :device (:filesystem data)
   :mount (:mount data)
   :description (format "Filesystem %s mounted on %s is %.1f%% used\n%s of %s remaining"
                        (:filesystem data)
                        (:mount data)
                        (* 100.0 (:usage data))
                        (source/byte-str (- (:total data) (:used data)))
                        (source/byte-str (:total data)))})


(defrecord DiskSpaceSource
  [mode]

  source/Source

  (collect-events
    [this]
    (let [info (case mode
                 :linux (measure-linux))]
      (into []
            (comp
              ; Only monitor filesystems which map to a real block device.
              (filter #(str/includes? (:filesystem %) "/"))
              (map usage-event))
            info))))


(defmethod source/initialize :disk-space
  [config]
  (-> config
      (select-keys [:type :period])
      (assoc :mode (sys/detect :disk-space supported-modes (:mode config) :linux))
      (map->DiskSpaceSource)))
