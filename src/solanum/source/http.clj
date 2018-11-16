(ns solanum.source.http
  "Metrics source that checks the availability of a local TCP port."
  (:require
    [clj-http.lite.client :as http]
    [clojure.data.json :as json]
    [clojure.edn :as edn]
    [clojure.string :as str]
    [clojure.tools.logging :as log]
    [solanum.source.core :as source]))


;; ## Measurements

(defn- parse-body
  "Return a parsed response body if the content type is advertized as a known
  data format. Returns nil otherwise."
  [response]
  (let [content-type (get-in response [:headers "content-type"])]
    (cond
      (str/starts-with? content-type "application/edn")
      (edn/read-string (:body response))

      (str/starts-with? content-type "application/json")
      (json/read-str (:body response))

      :else nil)))


(defn- acceptable-values
  "Determine the acceptable set of values for a given check config."
  [check]
  (let [single (:value check)
        multi (:values check)]
    (if (some? single)
      (set (cons single multi))
      (set multi))))


(defn- check-response
  "Test the response to an HTTP call to determine if it is healthy, based on
  the configured check. Returns a tuple of the check state (true or false) and
  a description fragment."
  [response check]
  (case (:type check)
    :status
    (let [acceptable (acceptable-values check)]
      (if (contains? acceptable (:status response))
        [true (str "status " (:status response))]
        [false (format "status %s is not in %s"
                       (:status response)
                       (str/join "/" (sort acceptable)))]))

    :pattern
    (let [pattern (re-pattern (:pattern check))]
      (if (re-seq pattern (:body response))
        [true (str "body matches " (pr-str pattern))]
        [false (str "body does not match " (pr-str pattern))]))

    :data
    (if-let [data @(:data response)]
      (let [acceptable (acceptable-values check)
            key-path (if (sequential? (:key check))
                       (vec (:key check))
                       [(:key check)])
            value (get-in data key-path)]
        (if (contains? acceptable value)
          [true (format "%s: %s"
                        (str/join "." key-path)
                        (pr-str value))]
          [false (format "%s: %s is not in %s"
                        (str/join "." key-path)
                        (pr-str value)
                        (str/join "/" (sort acceptable)))]))
      [false (format "Body content %s is not parseable for data check"
                     (get-in response [:headers "content-type"]))])

    ; else
    (log/error "Unknown HTTP response check type" (pr-str (:type check)))))


(defn- collect-fields
  "Collect additional event attributes from the response data to include in the
  health event."
  [fields data]
  (into {}
        (keep
          (fn collect
            [[attr-key data-key]]
            (let [key-path (if (sequential? data-key)
                             (vec data-key)
                             [data-key])
                  value (get-in data key-path)]
              (when (some? value)
                [attr-key (str value)]))))
        fields))



;; ## HTTP Source

(defrecord HTTPSource
  [url label timeout response-checks record-fields]

  source/Source

  (collect-events
    [this]
    (let [elapsed (source/stopwatch)]
      (try
        (let [resp (http/get url {:throw-exceptions false
                                  :socket-timeout 1000
                                  :conn-timeout timeout})
              data (delay (parse-body resp))
              checks (mapv (partial check-response (assoc resp :data data))
                           response-checks)
              healthy? (every? (comp true? first) checks)]
          [{:service "http url time"
            :label (or label url)
            :metric @elapsed}
           (merge
             (when (seq record-fields)
               (collect-fields record-fields @data))
             {:service "http url health"
              :label (or label url)
              :metric (if healthy? 1 0)
              :state (if healthy? "ok" "critical")
              :description (format "Checked %s in %.1f ms:\n%s"
                                   (or label url)
                                   @elapsed
                                   (str/join "\n" (map second checks)))})])
        (catch Exception ex
          [{:service "http url time"
            :label (or label url)
            :metric @elapsed}
           {:service "http url health"
            :label (or label url)
            :metric 0
            :state "critical"
            :description (format "%s: %s"
                                 (.getSimpleName (class ex))
                                 (.getMessage ex))}])))))


(defmethod source/initialize :http
  [config]
  (when-not (:url config)
    (throw (IllegalArgumentException.
             "Cannot initialize HTTP source without a URL")))
  (-> (merge {:timeout 1000
              :response-checks [{:type :status
                                 :values #{200}}]}
             config)
      (select-keys [:url :label :timeout
                    :response-checks
                    :record-fields])
      (map->HTTPSource)))
