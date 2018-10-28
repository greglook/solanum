(ns solanum.main
  "Main entry for the daemon."
  (:gen-class)
  (:require
    [clojure.java.io :as io]
    [clojure.java.shell :as shell]
    [clojure.string :as str]
    [clojure.tools.cli :as cli]
    [clojure.tools.logging :as log]
    [solanum.channel :as chan]
    [solanum.config :as cfg]
    [solanum.scheduler :as scheduler]
    [solanum.util :as u]
    [solanum.writer :as writer]))


(def version
  "Project version string."
  (if-let [props-file (io/resource "META-INF/maven/mvxcvi/solanum/pom.properties")]
    (with-open [props-reader (io/reader props-file)]
      (let [props (doto (java.util.Properties.)
                    (.load props-reader))
            {:strs [groupId artifactId version revision]} props]
        (format "%s/%s %s (%s)" groupId artifactId version revision)))
    "HEAD"))


(defn- load-hostname
  "Look up the name of the local host."
  [ctx]
  (let [result (shell/sh "hostname")]
    (if (zero? (:exit result))
      (str/trim-newline (:out result))
      (log/warn "Failed to resolve local hostname:" (pr-str (:err result))))))


(defn- parse-attr-opt
  "Parse an attribute option and add it to the option map."
  [opts id arg]
  (let [[k v] (str/split arg #"=" 2)]
    (assoc-in opts [id k] v)))


(def cli-options
  "Command-line tool options."
  [["-H" "--host NAME" "Metric event host name"
    :default-fn load-hostname]
   ["-a" "--attribute KEY=VAL" "Attribute to add to every event (may be set multiple times)"
    :default {}
    :default-desc ""
    :assoc-fn parse-attr-opt]
   ["-t" "--tag TAG" "Tag to add to every event (may be set multiple times)"
    :default #{}
    :default-desc ""
    :assoc-fn #(update %1 %2 conj %3)]
   [nil "--ttl SECONDS" "Default TTL for events"
    :parse-fn #(Integer/parseInt %)
    :default 60]
   [nil "--batch-delay MILLISECONDS" "Maximum duration to wait for events in a batch"
    :parse-fn #(Integer/parseInt %)
    :default 1000]
   [nil "--batch-size COUNT" "Size threshold for sending a batch of events"
    :parse-fn #(Integer/parseInt %)
    :default 50]
   [nil "--test" "Run each source a fixed number of times, record the events, then exit."]
   [nil "--test-count N" "When in test mode, collect each source N times."
    :parse-fn #(Integer/parseInt %)
    :default 1]
   [nil "--test-delay SECONDS" "When in test mode, sleep this long between collections."
    :parse-fn #(Integer/parseInt %)
    :default 1]
   [nil  "--version" "Print program version information."]
   ["-h" "--help" "Show help and usage information."]])


(defn- register-cleanup!
  "Register a shutdown hook to cleanly terminate the process."
  [scheduler channel writer]
  ; TODO: this does run on SIGINT, but the app still exits 130
  (.addShutdownHook
    (Runtime/getRuntime)
    (Thread. (fn cleanup
               []
               (log/info "Shutting down...")
               (scheduler/stop! scheduler 1000)
               (let [remaining (chan/wait-drained channel 1000)]
                 (if (zero? remaining)
                   (log/info "Drained channel events")
                   (log/warn remaining "events remaining in channel")))
               (writer/stop! writer 1000)
               (log/info "Done"))
             "solanum-shutdown")))


(defn- event-base
  "Calculate the base set of fields for events."
  [options config]
  (u/merge-attrs (:defaults config)
                 (:attribute options)
                 {:host (:host options)
                  :tags (vec (:tag options))}))


(defn- run-daemon
  "Run the process in daemon mode."
  [options config]
  (let [channel (chan/create 1000)
        defaults (event-base options config)
        scheduler (scheduler/start! defaults (:sources config) channel)
        writer (writer/start! channel
                              (:outputs config)
                              (:batch-delay options)
                              (:batch-size options))]
    ; Register cleanup work.
    (register-cleanup! scheduler channel writer)
    ; Block while the threads do their thing.
    @(promise)))


(defn- run-test
  "Run the process in test mode."
  [options config]
  (let [defaults (event-base options config)]
    (loop [n (dec (:test-count options))]
      (let [events (into []
                         (mapcat (partial scheduler/collect-source defaults))
                         (:sources config))]
        (println "Collected" (count events) "events")
        (writer/write-outputs (:outputs config) events)
        (when (pos? n)
          (Thread/sleep (* 1000 (:test-delay options)))
          (recur (dec n)))))))


(defn -main
  "Main entry point."
  [& args]
  (let [parse (cli/parse-opts args cli-options)
        config-paths (parse :arguments)
        options (parse :options)]
    (when-let [errors (parse :errors)]
      (binding [*out* *err*]
        (run! println errors)
        (System/exit 1)))
    (when (:version options)
      (println version)
      (flush)
      (System/exit 0))
    (when (or (:help options) (empty? config-paths))
      (println "Usage: solanum [options] <config.yml> [config2.yml ...]")
      (newline)
      (println (parse :summary))
      (flush)
      (System/exit (if (:help options) 0 1)))
    (let [config (cfg/load-files config-paths)]
      (when (empty? (:sources config))
        (binding [*out* *err*]
          (println "No sources defined in configuration files")
          (System/exit 2)))
      (when (empty? (:outputs config))
        (binding [*out* *err*]
          (println "No outputs defined in configuration files")
          (System/exit 2)))
      (if (:test options)
        (run-test options config)
        (run-daemon options config)))
    ; NOTE: thread never gets here.
    (shutdown-agents)
    (System/exit 0)))
