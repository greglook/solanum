(ns solanum.source.tcp
  "Metrics source that checks the availability of a local TCP port."
  (:require
    [solanum.source.core :as source])
  (:import
    (java.net
      InetSocketAddress
      Socket
      SocketTimeoutException)))


;; ## Measurements

(defn- test-port
  "Test a TCP port by connecting to it. Returns a vector with a state and
  description."
  [host port timeout]
  (let [address (InetSocketAddress. (str host) (long port))
        socket (Socket.)]
    (try
      (.connect socket address (long timeout))
      [:ok (format "TCP port %d is open on %s" port host)]
      (catch SocketTimeoutException _
        [:critical (format "Timed out connecting to TCP port %d on %s"
                           port host)])
      (catch Exception ex
        [:critical (format "Error connecting to TCP port %d on %s\n%s: %s"
                           port host
                           (.getName (class ex))
                           (ex-message ex))])
      (finally
        (.close socket)))))


;; ## TCP Source

(defrecord TCPSource
  [label host port]

  source/Source

  (collect-events
    [_]
    (let [[state desc] (test-port host port 1000)]
      [{:service "tcp socket open"
        :port (str (or label port))
        :metric (if (= :ok state) 1 0)
        :state state
        :description desc}])))


(defmethod source/initialize :tcp
  [config]
  (when-not (:port config)
    (throw (IllegalArgumentException.
             "Cannot initialize TCP source without a port")))
  (map->TCPSource
    {:label (:label config)
     :host (:host config "localhost")
     :port (int (:port config))}))
