(ns solanum.source.cpu
  "Metrics source that measures the CPU utilization of a host."
  (:require
    [clojure.java.io :as io]
    [clojure.java.shell :as shell]
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [solanum.source.core :as source])
  (:import
    java.io.FileReader))


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
    (line-seq (io/reader (FileReader. "/proc/stat")))
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


(defn- diff-core-states
  "Calculate the difference in the number of jiffies for each core state,
  compared to some previously-captured data."
  [prev data]
  (into {}
        (map
          (fn diff-core
            [[core states]]
            [core (reduce
                    (fn diff-states
                      [diff [state jiffies]]
                      (if-let [last-val (get-in prev [core state])]
                        (assoc diff state (- jiffies last-val))
                        diff))
                    {} states)]))
        data))


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
            (diff-core-states prev data)))))


;; ### Darwin

(defn- measure-darwin-cpu
  "Measure CPU utilization on Darwin (OS X) systems using `top`."
  []
  ; get process list with `ps -eo pcpu,pid,comm | sort -nrb -k1 | head -10`
  (let [result (shell/sh "top" "-l" "1")]
    (if (zero? (:exit result))
      (let [head-lines (take 10 (str/split (:out result) #"\n"))
            cpu-line (first (filter #(str/starts-with? % "CPU usage:")
                                    head-lines))]
        (if cpu-line
          {"cpu"
           (into {}
                 (map (fn [[_ pct kind]]
                        [(keyword kind) (/ (Double/parseDouble pct) 100.0)]))
                 (re-seq #" (\d+\.\d+)% (\w+),?" cpu-line))}
          (log/warn "Couldn't find CPU usage information in top header:"
                    (pr-str head-lines))))
      (log/warn "Failed to measure CPU usage with top:"
                (pr-str (:err result))))))



;; ## CPU Source

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
          (map
            (fn state-event
              [[state pct]]
              {:service "cpu state"
               :metric pct
               :state (name state)})
            (usage "cpu")))
        ; Per-core metrics
        (when per-core
          (mapcat
            (fn core-events
              [[core states]]
              (concat
                (when-let [pct (some->> (:idle states) (- 1.0))]
                  [{:service "cpu core usage"
                    :metric pct
                    :core core}])
                (when per-state
                  (map
                    (fn state-event
                      [[state pct]]
                      {:service "cpu core state"
                       :metric pct
                       :core core
                       :state (name state)})
                    states))))
            (dissoc usage "cpu")))))))


(defmethod source/initialize :cpu
  [config]
  (-> config
      (select-keys [:type :period :per-core :per-state :usage-states])
      (update :per-core boolean)
      (update :per-state boolean)
      (assoc :mode (source/detect-mode :cpu supported-modes
                                       (:mode config) :linux)
             :tracker (atom {}))
      (map->CPUSource)))
