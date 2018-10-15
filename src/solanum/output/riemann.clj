(ns solanum.output.riemann
  "Send events to a Riemann server."
  (:require
    [riemann.client :as riemann]
    [solanum.output.core :as output]))


(defn- add-timestamp
  "Update the event with the current time if missing."
  [event]
  (if (:time event)
    event
    (assoc event :time (long (/ (System/currentTimeMillis) 1000)))))


(defn- fix-state
  "Coerce the state field to a string if needed."
  [event]
  (let [state (:state event)]
    (cond
      (nil? state) event
      (string? state) event
      (keyword? state) (update event :state name)
      :else (update event :state str))))


(defn- prepare-batch
  "Prepare a batch of events for transmission to Riemann."
  [events]
  (into []
        (comp
          (map add-timestamp)
          (map fix-state))
        events))


(defrecord RiemannOutput
  [host port client]

  output/Output

  (write-events
    [this events]
    (riemann/send-events client (prepare-batch events))))


(defmethod output/initialize :riemann
  [config]
  (let [host (get config :host "localhost")
        port (get config :port 5555)]
    (-> config
        (select-keys [:type :host :port])
        (assoc :client (riemann/tcp-client :host host :port port))
        (map->RiemannOutput))))
