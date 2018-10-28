(ns solanum.source.cpu
  "Metrics source that measures the CPU utilization of a host."
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


;; ### Linux

(defn- stat-jiffies
  "Read the per-core cpu state measurements in jiffies from `/proc/stat`.
  Returns a map from CPU core names to maps of the state keywords to jiffie
  counts."
  []
  (->>
    (linux/read-proc-lines "/proc/stat")
    (take-while #(str/starts-with? % "cpu"))
    (reduce
      (fn parse-info
        [totals line]
        (let [fields (str/split (str/trim-newline line) #" +")
              core (first fields)
              jiffies (zipmap
                        [:user :nice :system :idle :iowait :irqhard :irqsoft]
                        (map #(Long/parseLong %) (rest fields)))]
          (assoc totals core jiffies)))
      {})))


(defn- relative-vals
  "Update the values in a map so they represent their fraction of the total of
  all values in the original map."
  [m]
  (let [total (apply + (vals m))]
    (into {}
          (map (fn [[k v]] [k (double (/ v total))]))
          m)))


(defn- measure-linux-cpu
  "Measure CPU utilization on Linux systems by reading `/proc/stat`."
  [tracker]
  (let [data (stat-jiffies)
        prev @tracker]
    (reset! tracker data)
    (when prev
      (into {}
            (map (juxt key (comp relative-vals val)))
            (source/diff-tracker prev data)))))


;; ### Darwin

(defn- measure-darwin-cpu
  "Measure CPU utilization on Darwin (OS X) systems using `top`."
  []
  ; get process list with `ps -eo pcpu,pid,comm | sort -nrb -k1 | head -10`
  (let [head-lines (:lines (darwin/read-top))
        cpu-line (first (filter #(str/starts-with? % "CPU usage:")
                                head-lines))]
    (if cpu-line
      {"cpu"
       (into {}
             (map (fn [[_ pct kind]]
                    [(keyword kind) (/ (Double/parseDouble pct) 100.0)]))
             (re-seq #" (\d+\.\d+)% (\w+),?" cpu-line))}
      (log/warn "Couldn't find CPU usage information in top header:"
                (pr-str head-lines)))))



;; ## CPU Source

(defn- cpu-state-event
  "Construct a state usage event for the CPU as a whole."
  [[state pct]]
  {:service "cpu state"
   :metric (double pct)
   :state (name state)})


(defn- core-state-event
  "Construct a state usage event for a single core of the CPU."
  [core [state pct]]
  {:service "cpu core state"
   :metric (double pct)
   :state (name state)
   :core core})


(defn- core-events
  "Build a sequence of events measuring a single core of the CPU."
  [per-state [core states]]
  (concat
    (when-let [pct (some->> (:idle states) (- 1.0))]
      [{:service "cpu core usage"
        :metric pct
        :core core}])
    (when per-state
      (map (partial core-state-event core) states))))


(defrecord CPUSource
  [mode per-core per-state usage-states tracker]

  source/Source

  (collect-events
    [this]
    (let [usage (case mode
                  :linux (measure-linux-cpu tracker)
                  :darwin (measure-darwin-cpu))]
      (concat
        ; Overall usage stat.
        (when-let [pct (some->> (get-in usage ["cpu" :idle]) (- 1.0))]
          ; TODO: add process listing to this event
          [{:service "cpu usage"
            :metric pct
            :state (source/state-over usage-states pct :ok)}])
        ; Overall per-state metrics.
        (when per-state
          (map cpu-state-event (usage "cpu")))
        ; Per-core metrics
        (when per-core
          (mapcat (partial core-events per-state)
                  (dissoc usage "cpu")))))))


(defmethod source/initialize :cpu
  [config]
  (-> config
      (select-keys [:type :period :per-core :per-state :usage-states])
      (update :per-core boolean)
      (update :per-state boolean)
      (assoc :mode (sys/detect :cpu supported-modes (:mode config) :linux)
             :tracker (atom {}))
      (map->CPUSource)))
