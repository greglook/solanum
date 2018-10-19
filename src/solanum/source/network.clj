(ns solanum.source.network
  "Metrics source that measures network IO."
  (:require
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [solanum.source.core :as source]
    [solanum.system.core :as sys]
    [solanum.system.linux :as linux]))


(def supported-modes
  "Set of supported source modes."
  #{:linux})


(def ^:private simple-stats
  "Stats to show in simple mode."
  #{:rx-bytes :rx-packets :tx-bytes :tx-packets})



;; ### Linux

(def ^:private linux-net-fields
  "Fields in the net device file."
  [:rx-bytes :rx-packets :rx-errs :rx-drop :rx-fifo
   :rx-frame :rx-compressed :rx-multicast
   :tx-bytes :tx-packets :tx-errs :tx-drop :tx-fifo
   :tx-colls :tx-carrier :tx-compressed])


(defn- parse-net-counters
  "Parse a line from `/proc/net/dev` into a tuple with the interface name and
  a map of stat keys to numeric counter values."
  [line]
  (let [columns (str/split (str/trim line) #"\s+")]
    [(str/replace (first columns) #":$" "")
     (->> (rest columns)
          (map #(Long/parseLong %))
          (zipmap linux-net-fields))]))


(defn- read-net-data
  "Read network device counters from `/proc/net/dev`."
  []
  (into {}
        (comp
          (drop 2)
          (map parse-net-counters))
        (linux/read-proc-lines "/proc/net/dev")))


(defn- measure-linux-network
  "Measure network IO on Linux systems by reading the proc subsystem."
  [tracker]
  (let [data (read-net-data)
        prev @tracker]
    (reset! tracker data)
    (when prev
      (source/diff-tracker prev data))))



;; ## Network Source

(defrecord NetworkSource
  [mode tracker interfaces ignore detailed]

  source/Source

  (collect-events
    [this]
    (let [info (case mode
                 :linux (measure-linux-network tracker))]
      (into []
            (comp
              (if (seq interfaces)
                (filter (comp (set interfaces) key))
                identity)
              (if (seq ignore)
                (remove (comp (set ignore) key))
                identity)
              (mapcat
                (fn expand-events
                  [[iface diffs]]
                  (keep (fn net-event
                          [[stat diff]]
                          (when (or detailed (contains? simple-stats stat))
                            {:service (str "net io " (name stat))
                             :metric diff
                             :interface iface}))
                        diffs))))
            info))))


(defmethod source/initialize :network
  [config]
  (-> (merge {:ignore #{"lo"}} config)
      (select-keys [:type :period :interfaces :ignore :detailed])
      (update :detailed boolean)
      (update :interfaces set)
      (update :ignore set)
      (assoc :mode (sys/detect :network supported-modes (:mode config) :linux)
             :tracker (atom {}))
      (map->NetworkSource)))
