(ns solanum.source.uptime
  "Metrics source that measures the uptime of a host."
  (:require
    [clojure.string :as str]
    [solanum.source.core :as source])
  (:import
    java.io.FileReader))


(defrecord UptimeSource
  []

  source/Source

  (collect-events
    [this]
    (let [uptime (slurp (FileReader. "/proc/uptime"))
          seconds (Double/parseDouble (first (str/split uptime #" ")))]
      [{:service "uptime"
        :metric seconds
        :description (str "Up for " (source/duration-str seconds))}])))


(defmethod source/initialize :uptime
  [config]
  (map->UptimeSource (select-keys config [:type :period])))
