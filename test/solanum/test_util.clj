(ns solanum.test-util)


(defn quiet-exception
  "Construct a runtime exception which elides stacktrace data."
  [message]
  (doto (RuntimeException. ^String message)
    (.setStackTrace (into-array StackTraceElement []))))


(defn boom!
  "Always throws a quiet exception, no matter what it is called with."
  [& _]
  (throw (quiet-exception "BOOM")))
