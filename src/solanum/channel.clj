(ns solanum.channel
  "Shared event channel logic for sending collected metric events to be written
  to outputs."
  (:import
    (java.util.concurrent
      LinkedBlockingQueue
      TimeUnit)))


(defn create
  "Create a new channel with the given capacity."
  [capacity]
  (LinkedBlockingQueue. (long capacity)))


(defn put!
  "Put an event onto the channel."
  [^LinkedBlockingQueue channel event]
  (.put channel event))


(defn take!
  "Take an event off the channel."
  [^LinkedBlockingQueue channel timeout]
  (.poll channel timeout TimeUnit/MILLISECONDS))


(defn wait-drained
  "Wait up to `timeout` milliseconds for the channel to empty. Returns the
  number of events left in the channel."
  [^LinkedBlockingQueue channel timeout]
  (let [deadline (+ (System/nanoTime) (* 1000000 timeout))]
    (loop []
      (if (.isEmpty channel)
        0
        (let [now (System/nanoTime)]
          (if (< now deadline)
            (do (Thread/sleep 10) (recur))
            (.size channel)))))))
