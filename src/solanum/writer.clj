(ns solanum.writer
  "Event writer code."
  (:require
    [clojure.tools.logging :as log]
    [solanum.channel :as chan]
    [solanum.output.core :as output]))


(defn- write-output-batch
  "Write a batch of events to a collection of outputs."
  [outputs events]
  (when (seq events)
    (run!
      (fn write
        [output]
        (try
          (output/write-events output events)
          (catch InterruptedException ie
            (throw ie))
          (catch Exception ex
            (log/warn ex "Failure while writing events to"
                      (:type output) "output"))))
      outputs)))


(defn- writer-loop
  "Batch up events and report them to the outputs."
  [outputs event-chan max-delay max-size]
  (fn writer
    []
    (try
      (loop [last-send (System/nanoTime)
             batch []]
        (when-not (Thread/interrupted)
          (let [batch (if-let [event (chan/take! event-chan 100)]
                        (conj batch event)
                        batch)]
            (if (or (<= max-size (count batch))
                    (<= max-delay (- (System/nanoTime) last-send)))
              ; Need to send off the batch.
              (do (write-output-batch outputs batch)
                  (recur (System/nanoTime) []))
              ; Keep aggregating.
              (recur last-send batch)))))
      (catch InterruptedException ie
        ; Exit cleanly
        nil))))


(defn start!
  "Start a new thread to run event writer. The events will be batched for up to
  `max-delay` milliseconds or `max-size` events, whichever occurs first."
  [event-chan outputs max-delay max-size]
  (doto (Thread. (writer-loop outputs event-chan max-delay max-size)
                 "solanum-writer")
    (.start)))


(defn stop!
  "Stop a running writer thread, waiting up to `timeout` milliseconds for it
  to terminate."
  [^Thread thread timeout]
  (.interrupt thread)
  (.join thread timeout))
