(ns solanum.channel-test
  (:require
    [clojure.test :refer [deftest is testing]]
    [solanum.channel :as chan]))


(deftest channel-behavior
  (let [channel (chan/create 3)]
    (is (nil? (chan/take! channel 1)))
    (is (nil? (chan/put! channel :a)))
    (is (nil? (chan/put! channel :b)))
    (is (nil? (chan/put! channel :c)))
    (is (= :a (chan/take! channel 1)))
    (is (= :b (chan/take! channel 1)))
    (is (= 1 (chan/wait-drained channel 5)))
    (is (= :c (chan/take! channel 1)))
    (is (= 0 (chan/wait-drained channel 5)))))
