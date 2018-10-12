(ns solanum.scheduler
  (:import
    (java.time
      Instant)
    (java.time.temporal
      ChronoUnit)
    (java.util
      PriorityQueue
      Queue)
    (java.util.concurrent
      LinkedBlockingQueue
      TimeUnit)))


(defn- next-run
  "Determine when the next run of the source should be."
  [source]
  (.plusSeconds (Instant/now) (or (:period source) 60)))


(defn- source-schedule
  "Construct a priority queue of tuples of a next-run timestamp and the source
  that should run at that time."
  ^Queue
  [sources]
  ; TODO: is it actually useful having a mutable queue here?
  (let [compare-first #(compare (first %1) (first %2))
        queue (PriorityQueue. (count sources) compare-first)]
    (run! #(.add queue [(next-run %) %]) sources)
    queue))


(defn- collect-source
  "Collect events from a source and put them onto the event channel."
  [source event-chan]
  (try
    (println "TODO: Collect events from" (pr-str source))
    (Thread/sleep 5000)
    (let [events [,,,]]
      ; TODO: merge in defaults from source
      (run! #(.put event-chan %) events))
    (catch Exception ex
      ; TODO: handle exception - at least log, maybe send an event?
      nil)))


(defn- scheduler-loop
  "Loop over the sources, scheduling each one in a new thread as its time
  comes."
  [sources event-chan]
  (try
    (let [schedule (source-schedule sources)]
      (loop []
        (locking schedule
          (let [[collect-at source :as entry] (.peek schedule)
                millis (.until (Instant/now) collect-at ChronoUnit/MILLIS)]
            (if (< millis 250)
              ; Close enough, schedule the source for collection.
              (do
                (.remove schedule entry)
                (future
                  (collect-source source event-chan)
                  ; Reschedule next collection from source.
                  (locking schedule
                    (.add schedule [(next-run source) source])
                    (.notifyAll schedule))))
              ; Next source collection isn't soon enough, so wait.
              (.wait schedule millis))))
        (recur)))
    (catch InterruptedException ie
      ; Exit cleanly
      nil)))
