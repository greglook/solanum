(ns solanum.output.core
  "Core event sink protocol and methods.")


(defprotocol Output
  "..."

  (write-events
    [output events]
    "Write a sequence of metrics events to the output."))


(defmulti initialize
  "Construct a new output from a type keyword."
  :type)
