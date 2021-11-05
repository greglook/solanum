(ns solanum.scheduler
  "Event collection scheduling code."
  (:require
    [clojure.tools.logging :as log]
    [solanum.channel :as chan]
    [solanum.source.core :as source]
    [solanum.util :as u])
  (:import
    java.time.Instant
    java.time.temporal.ChronoUnit
    (java.util
      PriorityQueue
      Queue)))


(defn- next-run
  "Determine when the next run of the source should be."
  [source]
  (let [period (or (:period source) 60)
        jitter (or (:jitter source) 0.10)
        sleep (* 1000 period (+ 1.0 (rand jitter)))]
    (.plusMillis (Instant/now) sleep)))


(defn- source-schedule
  "Construct a priority queue of tuples of a next-run timestamp and the source
  that should run at that time."
  ^Queue
  [sources]
  (let [compare-first #(compare (first %1) (first %2))
        queue (PriorityQueue. (count sources) compare-first)]
    (run! #(.add queue [(next-run %) %]) sources)
    queue))


(defn- event-time
  "Return the current time to use for a collected event."
  []
  (/ (double (System/currentTimeMillis)) 1000))


(defn collect-source
  "Collect events from a source and put them onto the event channel."
  [defaults source]
  (let [prep-event (comp #(assoc % :time (event-time))
                         (partial u/merge-attrs
                                  defaults
                                  (:attributes source)))]
    (try
      (log/debug "Collecting events from" (pr-str source))
      (into [] (map prep-event) (source/collect-events source))
      (catch Exception ex
        (log/warn ex "Failure collecting from" (:type source) "source")
        [(prep-event
           {:service "solanum source error"
            :metric 1
            :state :critical
            :description (format "Failure collectiong from %s source:\n%s: %s"
                                 (name (:type source))
                                 (.getName (class ex))
                                 (.getMessage ex))})]))))


(defn- schedule-collection
  "Launch a new thread to collect metrics from the source."
  [^Queue schedule defaults source event-chan]
  (doto (Thread.
          ^Runnable
          (fn collector
            []
            (run! (partial chan/put! event-chan)
                  (collect-source defaults source))
            (locking schedule
              (.add schedule [(next-run source) source])
              (.notifyAll schedule)))
          (str (name (:type source)) "-source"))
    (.setDaemon true)
    (.start)))


(defn- scheduler-loop
  "Loop over the sources, scheduling each one in a new thread as its time
  comes."
  [defaults sources event-chan]
  (fn scheduler
    []
    (try
      (let [schedule (source-schedule sources)]
        (loop []
          (when-not (Thread/interrupted)
            (try
              (locking schedule
                (if-let [entry (.peek schedule)]
                  (let [[collect-at source] entry
                        millis (.until (Instant/now) collect-at ChronoUnit/MILLIS)]
                    (if (< millis 250)
                      ;; Close enough, schedule the source for collection.
                      (do (.remove schedule entry)
                          (schedule-collection schedule defaults source event-chan))
                      ;; Next source collection isn't soon enough, so wait.
                      (.wait schedule millis)))
                  ;; Nothing scheduled.
                  (.wait schedule 1000)))
              (catch InterruptedException ie
                (throw ie))
              (catch Exception ex
                (log/error ex "Failure while running scheduler logic")
                (Thread/sleep 500)))
            (recur))))
      (catch InterruptedException ie
        ;; Exit cleanly
        nil))))


(defn start!
  "Start a new thread to run the scheduling logic."
  [defaults sources event-chan]
  (doto (Thread.
          ^Runnable (scheduler-loop defaults sources event-chan)
          "solanum-scheduler")
    (.start)))


(defn stop!
  "Stop a running scheduler thread, waiting up to `timeout` milliseconds for it
  to terminate."
  [^Thread thread timeout]
  (.interrupt thread)
  (.join thread timeout))
