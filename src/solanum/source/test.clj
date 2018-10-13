(ns solanum.source.uptime
  "A test source that generates fake events."
  (:require
    [solanum.source.core :as source]))


(defrecord TestSource
  [min-count max-count]

  source/Source

  (collect-events
    [this]
    (mapv
      (fn ->event
        [i]
        {:service (str "test " (rand-nth ["foo" "bar" "baz"]))
         :metric (rand 100.0)
         :description (rand-nth ["A" "B" "C"])})
      (range (+ min-count (rand-int (inc max-count)))))))


(defmethod source/initialize :test
  [config]
  (map->TestSource
    (merge
      {:min-count 1
       :max-count 1}
      (select-keys config [:type :period :min-count :max-count]))))
