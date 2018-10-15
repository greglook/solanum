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
    [solanum.source.core :as source]
    [solanum.output.core :as output]
    [solanum.writer :as writer]))


(def config nil)
(def channel nil)
(def scheduler nil)
(def writer nil)


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
   (alter-var-root #'scheduler (constantly (scheduler/start! {} (:sources config) channel)))
   (alter-var-root #'writer (constantly (writer/start! channel (:outputs config) 100 10)))
   :started))


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
