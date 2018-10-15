(ns solanum.source.cpu
  "Metrics source that measures the CPU utilization of a host."
  (:require
    [clojure.java.shell :as shell]
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [solanum.source.core :as source])
  (:import
    java.io.FileReader))


(def supported-modes
  "Set of supported source modes."
  #{:linux :freebsd :darwin})


(defn- detect-mode
  "Determine what mode to run the source in for compatibility with the
  local operating system."
  [requested]
  (let [mode (or requested
                 (keyword (str/lower-case (:name @source/os-info))))]
    (if (contains? supported-modes mode)
      mode
      (do (log/warn "Unknown CPU source mode" (pr-str mode) "- falling back to :linux")
          :linux))))


(defn- linux-cpu-states
  "Measure CPU utilization on Linux systems by reading `/proc/stat`."
  [tracker]
  ; TODO: implement linux measurement
  ,,,)


(defn- freebsd-cpu-states
  "Measure CPU utilization on BSD systems using ..."
  []
  ; TODO: implement freebsd measurement
  ,,,)


(defn- darwin-cpu-states
  "Measure CPU utilization on Darwin (OS X) systems using `top`."
  []
  ; get process list with `ps -eo pcpu,pid,comm | sort -nrb -k1 | head -10`
  (let [result (shell/sh "top" "-l" "1")]
    (if (zero? (:exit result))
      (let [head-lines (take 10 (str/split (:out result) #"\n"))
            cpu-line (first (filter #(str/starts-with? % "CPU usage:")
                                    head-lines))]
        (if cpu-line
          (into {}
                (map (fn [[_ pct kind]]
                       [(keyword kind) (/ (Double/parseDouble pct) 100.0)]))
                (re-seq #" (\d+\.\d+)% (\w+),?" cpu-line))
          (log/warn "Couldn't find CPU usage information in top header:"
                    (pr-str head-lines))))
      (log/warn "Failed to measure CPU usage with top:"
                (pr-str (:err result))))))


(defrecord CPUSource
  [mode per-core per-state tracker]

  source/Source

  (collect-events
    [this]
    (let [states (case mode
                   :linux (linux-cpu-states tracker)
                   :freebsd (freebsd-cpu-states)
                   :darwin (darwin-cpu-states))]
      (concat
        (when-let [usage (and (:idle states) (- 1.0 (:idle states)))]
          [{:service "cpu usage"
            :metric usage
            :state (source/state-over (:usage-states this) usage :ok)}])
        (when (and per-core (= mode :linux))
          ; TODO: per-core stats
          ,,,)
        (when per-state
          (map
            (fn state-event
              [[state pct]]
              {:service "cpu state"
               :metric pct
               :state (name state)})
            states))))))


(defmethod source/initialize :cpu
  [config]
  (-> config
      (select-keys [:type :period :per-core :per-state])
      (update :per-core boolean)
      (update :per-state boolean)
      (assoc :mode (detect-mode (:mode config))
             :tracker (atom {}))
      (map->CPUSource)))
