(ns solanum.source.core
  "Core event source protocol and methods.")


(defprotocol Source
  "Source of metrics events."

  (collect-events
    [source]
    "Return a sequence of metrics events collected from the source."))


(defmulti initialize
  "Construct a new source from a type keyword."
  :type)
