(ns solanum.source.load
  "Metrics source that measures process load."
  (:require
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [solanum.source.core :as source]
    [solanum.system.core :as sys]
    [solanum.system.darwin :as darwin]
    [solanum.system.linux :as linux]))


(def supported-modes
  "Set of supported source modes."
  #{:linux :darwin})


(defn- measure-linux-load
  "Measure the process load on a linux system."
  []
  (let [line (linux/read-proc-file "/proc/loadavg")
        [load-1m load-5m load-15m run-frac last-pid] (str/split line #" +")
        [running total] (str/split run-frac #"/" 2)]
    {:info line
     :load (mapv #(Double/parseDouble %) [load-1m load-5m load-15m])
     :total (Long/parseLong total)
     :running (Long/parseLong running)}))


(defn- measure-darwin-load
  "Measure the process load on an OS X system."
  []
  (reduce
    (fn [data line]
      ; Processes: 284 total, 4 running, 10 stuck, 270 sleeping, 1572 threads
      ; Load Avg: 2.03, 2.00, 2.07
      (cond
        (str/starts-with? line "Processes: ")
        (let [[_ total running] (re-matches #"Processes: (\d+) total, (\d+) running, .+" line)]
          (assoc data
                 :info line
                 :total (Long/parseLong total)
                 :running (Long/parseLong running)))

        (str/starts-with? line "Load Avg: ")
        (let [load-nums (->> (str/split (subs line 10) #", ")
                             (reverse)
                             (mapv #(Double/parseDouble %)))]
          (assoc data :load load-nums))

        :else data))
    {}
    (:lines (darwin/read-top))))



;; ## Load Source

(defrecord LoadSource
  [mode load-states]

  source/Source

  (collect-events
    [this]
    (let [processes (case mode
                      :linux (measure-linux-load)
                      :darwin (measure-darwin-load))]
      (concat
        (when-let [[load-1m load-5m load-15m] (:load processes)]
          [{:service "process load"
            :metric (double load-1m)
            :state (source/state-over load-states load-1m :ok)
            :description (format "Load averages: %.2f 1m, %.2f 5m, %.2f 15m"
                                 load-1m load-5m load-15m)}])
        (when-let [total (:total processes)]
          [{:service "process count"
            :metric total
            :description (:info processes)}])
        (when-let [running (:running processes)]
          [{:service "process running"
            :metric running}])))))


(defmethod source/initialize :load
  [config]
  (-> config
      (select-keys [:type :period :load-states])
      (assoc :mode (sys/detect :load supported-modes (:mode config) :linux))
      (map->LoadSource)))
