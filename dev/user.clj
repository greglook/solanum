(ns user
  "Custom repl customization for local development."
  (:require
    [clojure.java.io :as io]
    [clojure.repl :refer :all]
    [clojure.set :as set]
    [clojure.stacktrace :refer [print-cause-trace]]
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [clojure.tools.namespace.repl :refer [refresh]]
    [solanum.channel :as chan]
    [solanum.config :as cfg]
    [solanum.scheduler :as scheduler]
    [solanum.writer :as writer]))


#_ ; Example config
{:defaults {:tags ["solanum"]
            :ttl 60}
 :outputs [{:type "print"}
           {:type "riemann"
            :host "riemann.example.com"
            :port 5555}]
 :sources [{:type "cpu"
            :per-core false
            :detailed false
            :usage-states {:critical 0.9
                           :warning 0.8}}
           {:type "uptime"
            :period 60}
           {:type "load"
            :load-states {:critical 8
                          :warning 4}}
           {:type "memory"}
           {:type "diskstats"
            :detailed false
            :devices ["sda"]}
           {:type "network"
            :detailed false
            :interfaces ["wlan0"]}
           {:type "certificate"
            :host "www.google.com"
            :expiry-states {:critical 30 :warning 180}
            :attributes {:ttl 3600}
            :period 300}]}


(def config nil)
(def channel nil)
(def scheduler nil)
(def writer nil)


(defn stop!
  "Halt the running scheduler and writer threads."
  []
  (when scheduler
    (scheduler/stop! scheduler 1000)
    (alter-var-root #'scheduler (constantly nil)))
  (when (or channel writer)
    (when channel
      (let [remaining (chan/wait-drained channel 1000)]
        (if (zero? remaining)
          (log/info "Drained channel events")
          (log/warn remaining "events remaining in channel")))
      (alter-var-root #'channel (constantly nil)))
    (when writer
      (writer/stop! writer 1000)
      (alter-var-root #'writer (constantly nil))))
  :stopped)


(defn start!
  "Start running the scheduler and writer threads."
  ([]
   (start! (cfg/load-files ["config.yml"])))
  ([config]
   (alter-var-root #'config (constantly config))
   (when (or channel scheduler writer)
     (throw (IllegalStateException.
              "There are already running resources, call `stop!` first.")))
   (alter-var-root #'channel (constantly (chan/create 1000)))
   (alter-var-root #'scheduler (constantly (scheduler/start! (:sources config) channel)))
   (alter-var-root #'writer (constantly (writer/start! (:outputs config) channel 100 10)))
   :started))
