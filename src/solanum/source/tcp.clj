(ns solanum.source.tcp
  "Metrics source that checks the availability of a local TCP port."
  (:require
    [clojure.tools.logging :as log]
    [solanum.source.core :as source])
  (:import
    (java.net
      InetSocketAddress
      Socket
      SocketTimeoutException)))


(defrecord TCPSource
  [host port]

  source/Source

  (collect-events
    [this]
    (let [address (InetSocketAddress. (str host) (long port))
          socket (Socket.)
          open-event (fn [metric state desc]
                       {:service "tcp socket open"
                        :port port
                        :metric metric
                        :state state
                        :description desc})]
      (try
        (.connect socket address 1000)
        [(open-event 1 :ok
                     (format "TCP port %d is open on %s" port host))]
        (catch SocketTimeoutException ex
          [(open-event 0 :critical
                       (format "Timed out connecting to TCP port %d on %s"
                               port host))])
        (catch Exception ex
          [(open-event 0 :critical
                       (format "Error connecting to TCP port %d on %s\n%s: %s"
                               port host
                               (.getName (class ex))
                               (.getMessage ex)))])
        (finally
          (.close socket))))))


(defmethod source/initialize :tcp
  [config]
  (when-not (:port config)
    (throw (IllegalArgumentException.
             "Cannot initialize TCP source without a port")))
  (-> (merge {:host "localhost"} config)
      (select-keys [:type :period :host :port])
      (map->TCPSource)))
