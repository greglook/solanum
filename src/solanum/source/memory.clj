(ns solanum.source.memory
  "Metrics source that measures system memory usage."
  (:require
    [clojure.java.shell :as shell]
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [solanum.source.core :as source])
  (:import
    java.io.FileReader))


(def supported-modes
  "Set of supported source modes."
  #{:linux :darwin})


(defn- measure-linux-memory
  "Measure the memory usage on a linux system."
  []
  (let [lines (-> (FileReader. "/proc/meminfo")
                  (slurp)
                  (str/split #"\n"))
        info (into {}
                   (map (fn parse-line
                          [line]
                          (let [[measure amount unit] (str/split line #":? +")]
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
  (let [result (shell/sh "top" "-l" "1")]
    (if (zero? (:exit result))
      (when-let [mem-line (->> (str/split (:out result) #"\n")
                               (take 10)
                               (filter (partial re-matches #"PhysMem: (\d+)([BKMGT]) used \((\d+)([BKMGT]) wired\), (\d+)([BKMGT]) unused"))
                               (first))]
        (let [byte-scale (fn byte-scale
                           [[amount unit]]
                           (let [exp (* 10 (str/index-of "BKMGT" unit))
                                 scale (bit-shift-left 1 exp)]
                             (* (Long/parseLong amount) scale)))
              [used wired unused] (->> (rest mem-line)
                                       (partition 2)
                                       (map byte-scale))]
          {:usage (double (/ used (+ used unused)))}))
      (log/warn "Failed to measure process load:" (pr-str (:err result))))))



;; ## Load Source

(defrecord MemorySource
  [mode usage-states swap-states]

  source/Source

  (collect-events
    [this]
    (let [info (case mode
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
  (-> config
      (select-keys [:type :period :usage-states :swap-states])
      (assoc :mode (source/detect-mode :memory supported-modes
                                       (:mode config) :linux))
      (map->MemorySource)))
