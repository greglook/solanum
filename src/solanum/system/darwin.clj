(ns solanum.system.darwin
  "Darwin (OS X) utilities."
  (:require
    [clojure.java.shell :as shell]
    [clojure.string :as str]
    [clojure.tools.logging :as log]))


(def ^:private top-info
  "Atom containing information extracted from Darwin's `top` output."
  (atom {}))


(def ^:private top-cooldown
  "Minimum duration in seconds to wait between `top` invocations."
  10)


(defn- parse-top-output
  "Parse textual top output data, returning a map of parsed info."
  [lines]
  {:lines lines})


(defn- run-top
  "Run top and parse the output."
  []
  (let [result (shell/sh "top" "-l" "1")]
    (if (zero? (:exit result))
     (->> (str/split (:out result) #"\n")
          (take 10)
          (parse-top-output))
     (log/error "Failed to run top:" (pr-str (:err result))))))


(defn read-top
  "Read information from `top`, using a cached value when still within the
  cooldown."
  []
  (let [old-info @top-info
        last-run (:last-run old-info)
        now (System/currentTimeMillis)]
    (if (or (nil? last-run) (< (+ last-run (* 1000 top-cooldown)) now))
      (reset! top-info (assoc (run-top) :last-run now))
      old-info)))
