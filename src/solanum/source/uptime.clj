(ns solanum.source.uptime
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
        ; TODO: human format duration
        :description (str "Up for " seconds)}])))


(defmethod source/initialize :uptime
  [config]
  (map->UptimeSource (select-keys config [:type :period])))
