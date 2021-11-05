(ns solanum.writer
  "Event writer code."
  (:require
    [clojure.tools.logging :as log]
    [solanum.channel :as chan]
    [solanum.output.core :as output]))


(defn write-outputs
  "Write a batch of events to a collection of outputs. Returns the number of
  errors encountered during writes."
  [outputs events]
  (if (seq events)
    (let [errors (volatile! 0)]
      (run!
        (fn write
          [output]
          (try
            (log/debug "Writing" (count events) "to" output)
            (output/write-events output events)
            (catch InterruptedException ie
              (throw ie))
            (catch Exception ex
              (log/warn ex "Failure while writing events to"
                        (:type output) "output")
              (vswap! errors inc))))
        outputs)
      @errors)
    0))


(defn- writer-loop
  "Batch up events and report them to the outputs."
  [outputs event-chan {:keys [max-delay max-size max-errors]}]
  (fn writer
    []
    (try
      (loop [write-errors 0
             last-send (System/nanoTime)
             batch []]
        (when-not (Thread/interrupted)
          (when (and max-errors (< max-errors write-errors))
            (log/fatalf "Write error count of %d exceeds maximum error limit %d, exiting!"
                        write-errors max-errors)
            (System/exit 42))
          (let [batch (if-let [event (chan/take! event-chan 100)]
                        (conj batch event)
                        batch)]
            (if (or (<= max-size (count batch))
                    (<= max-delay (- (System/nanoTime) last-send)))
              ;; Need to send off the batch.
              (let [errors (write-outputs outputs batch)]
                (recur (long (+ write-errors errors)) (System/nanoTime) []))
              ;; Keep aggregating.
              (recur write-errors last-send batch)))))
      (catch InterruptedException _
        ;; Exit cleanly
        nil))))


(defn start!
  "Start a new thread to run event writer. The events will be batched for up to
  `max-delay` milliseconds or `max-size` events, whichever occurs first."
  [event-chan outputs opts]
  (doto (Thread.
          ^Runnable (writer-loop outputs event-chan opts)
          "solanum-writer")
    (.start)))


(defn stop!
  "Stop a running writer thread, waiting up to `timeout` milliseconds for it
  to terminate."
  [^Thread thread timeout]
  (.interrupt thread)
  (.join thread timeout))
