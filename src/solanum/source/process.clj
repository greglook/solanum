(ns solanum.source.process
  "Metrics source that measures processes running on the host."
  (:require
    [clojure.java.shell :as shell]
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [solanum.source.core :as source]
    [solanum.system.core :as sys]
    [solanum.system.linux :as linux]))


;; ## Measurements

(source/defsupport :process
  #{:linux})


(defn- parse-linux-process
  "Parse a line of output from the `ps` command and return a map with
  information about each process."
  [line]
  (when-let [[_ pid rss vsize state user group lstart command] (re-matches #" *(\d+) +(\d+) +(\d+) +(.) +(\S+) +(\S+) +(\w+ +\w+ +\d+ +\d\d:\d\d:\d\d \d+) +(.+)" line)]
    {:pid (Long/parseLong pid)
     :rss (Long/parseLong rss)
     :vsize (Long/parseLong vsize)
     :state (case state
              "D" :uninterruptible-sleep ; usually IO
              "R" :running
              "S" :sleep ; interruptable
              "T" :stopped
              "W" :paging ; defunct since 2.6.x
              "X" :dead
              "Z" :zombie
              :unknown)
     :user user
     :group group
     :start-time lstart ; TODO: parse?
     :command command}))


(defn- measure-linux
  "Measure process stats on a Linux system."
  []
  (let [result (shell/sh "ps" "axo" "pid=,rss=,vsize=,state=,user:32=,group:32=,lstart=,command=")]
    (if (zero? (:exit result))
      ; IDEA: capture process fd usage and thread counts?
      (keep parse-linux-process (str/split (:out result) #"\n"))
      (log/error "Failed to list processes on linux:" (pr-str (:err result))))))


(defn- format-process
  "Format a process info map for human consumption."
  [proc]
  (format "%d %s %s %s rss %s vsize %s (%s) %s"
          (:pid proc)
          (:user proc)
          (:group proc)
          (source/byte-str (:rss proc))
          (source/byte-str (:vsize proc))
          (:start-time proc)
          (name (:state proc))
          (:command proc)))



;; ## Process Source

(defrecord ProcessSource
  [pattern label user min-states max-states]

  source/Source

  (collect-events
    [this]
    (let [processes (case (:mode this)
                      :linux (measure-linux))
          matching (into []
                         (comp
                           (filter #(re-seq pattern (:command %)))
                           (if user
                             (filter #(= user (:user %)))
                             identity))
                         processes)
          proc-label (or label (str pattern))
          proc-count (count matching)
          description (->> matching
                           (sort-by :pid)
                           (map format-process)
                           (str/join "\n"))]
      [{:service "process count"
        :process proc-label
        :metric proc-count
        :description description
        :state (or (source/state-under min-states proc-count nil)
                   (source/state-over max-states proc-count nil)
                   :ok)}
       {:service "process resident-set bytes"
        :process proc-label
        :metric (apply + (keep :rss matching))}
       {:service "process virtual-memory bytes"
        :process proc-label
        :metric (apply + (keep :vsize matching))}])))


(defmethod source/initialize :process
  [config]
  (when-not (:pattern config)
    (throw (IllegalArgumentException.
             "Cannot initialize process source without a pattern.")))
  (-> config
      (select-keys [:pattern :label :user :min-states :max-states])
      (update :pattern re-pattern)
      (map->ProcessSource)))
