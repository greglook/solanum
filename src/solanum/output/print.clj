(ns solanum.output.print
  "Prints events to standard out."
  (:require
    [solanum.output.core :as output]))


(defn- print-event
  "Print the event to `*out*`."
  [event]
  (printf "%-40s %5s (%s) %s\n"
          (:service event)
          (:metric event)
          (:state event "--")
          (pr-str event)))


(defrecord PrintOutput
  []

  output/Output

  (write-events
    [this events]
    (run! print-event events)
    (flush)))


(defmethod output/initialize :print
  [config]
  (map->PrintOutput (select-keys config [:type])))
