(ns solanum.source.memory
  "Metrics source that measures system memory usage."
  (:require
    [clojure.string :as str]
    [solanum.source.core :as source]
    [solanum.system.darwin :as darwin]
    [solanum.system.linux :as linux]))


;; ## Measurements

(source/defsupport :memory
  #{:linux :darwin})


(defn- measure-linux-memory
  "Measure the memory usage on a linux system."
  []
  (let [lines (linux/read-proc-lines "/proc/meminfo")
        info (into {}
                   (map (fn parse-line
                          [line]
                          (let [[measure amount _unit] (str/split line #":? +")]
                            [measure (* 1024 (Long/parseLong amount))])))
                   lines)
        total (get info "MemTotal")]
    (when (and total (pos? total))
      {:usage (double (/ (- total
                            (get info "MemFree")
                            (get info "Buffers")
                            (get info "Cached"))
                         total))
       :buffers (double (/ (get info "Buffers") total))
       :cached (double (/ (+ (get info "Cached")
                             (get info "SReclaimable")
                             (- (get info "Shmem")))
                          total))
       :swap (let [swap-total (get info "SwapTotal")
                   swap-free (get info "SwapFree")]
               (when (and swap-total (pos? swap-total))
                 (double (/ (- swap-total swap-free) swap-total))))})))


(defn- measure-darwin-memory
  "Measure the memory usage on an OS X system."
  []
  (when-let [mem-line (->> (:lines (darwin/read-top))
                           (filter (partial re-matches #"PhysMem: (\d+)([BKMGT]) used \((\d+)([BKMGT]) wired\), (\d+)([BKMGT]) unused"))
                           (first))]
    (let [byte-scale (fn byte-scale
                       [[amount unit]]
                       (let [exp (* 10 (str/index-of "BKMGT" unit))
                             scale (bit-shift-left 1 exp)]
                         (* (Long/parseLong amount) scale)))
          [used _wired unused] (->> (rest mem-line)
                                    (partition 2)
                                    (map byte-scale))]
      {:usage (double (/ used (+ used unused)))})))


;; ## Load Source

(defrecord MemorySource
  [usage-states swap-states]

  source/Source

  (collect-events
    [this]
    (let [info (case (:mode this)
                 :linux (measure-linux-memory)
                 :darwin (measure-darwin-memory))]
      (concat
        (when-let [usage (:usage info)]
          [{:service "memory usage"
            :metric usage
            :state (source/state-over usage-states usage :ok)}])
        (when-let [buffers (:buffers info)]
          [{:service "memory buffers"
            :metric buffers}])
        (when-let [cached (:cached info)]
          [{:service "memory cached"
            :metric cached}])
        (when-let [swap (:swap info)]
          [{:service "swap usage"
            :metric swap
            :state (source/state-over swap-states swap :ok)}])))))


(defmethod source/initialize :memory
  [config]
  (map->MemorySource
    (select-keys config [:usage-states :swap-states])))
