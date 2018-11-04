(ns solanum.source.core-test
  (:require
    [clojure.test :refer :all]
    [solanum.source.core :as source]))


(deftest timing-utils
  (let [elapsed (source/stopwatch)]
    (is (not (realized? elapsed)))
    (is (pos? @elapsed))
    (is (realized? elapsed))
    (is (= @elapsed @elapsed))))


(deftest format-utils
  (testing "byte-str"
    (is (= "0 B" (source/byte-str 0)))
    (is (= "1000 B" (source/byte-str 1000)))
    (is (= "3 KB" (source/byte-str (* 3 1024))))
    (is (= "6.0 KB" (source/byte-str (* 6.0 1024))))
    (is (= "3.5 MB" (source/byte-str (* 3.5 1024 1024))))
    (is (= "100.0 GB" (source/byte-str (* 100.0 1024 1024 1024))))
    (is (= "600 TB" (source/byte-str (* 600 1024 1024 1024 1024))))
    (is (= "2000.0 PB" (source/byte-str (* 2000.0 1024 1024 1024 1024 1024)))))
  (testing "duration-str"
    (is (= "00:00:00" (source/duration-str 0)))
    (is (= "00:00:05" (source/duration-str 5)))
    (is (= "00:01:00" (source/duration-str 60)))
    (is (= "00:27:38" (source/duration-str (+ (* 27 60) 38))))
    (is (= "05:27:38" (source/duration-str (+ (* 5 60 60) (* 27 60) 38))))
    (is (= "23:59:59" (source/duration-str (dec (* 24 60 60)))))
    (is (= "1 days, 00:00:00" (source/duration-str (* 24 60 60))))
    (is (= "3 days, 08:10:30" (source/duration-str (+ (* 3 24 60 60) (* 8 60 60) (* 10 60) 30))))))


(deftest state-utils
  (testing "state-over"
    (is (= :x (source/state-over {} 10 :x)))
    (is (= :x (source/state-over {:y 15} 10 :x)))
    (is (= :y (source/state-over {:y 15} 15 :x)))
    (is (= :y (source/state-over {:y 15} 20 :x)))
    (is (= :y (source/state-over {:y 15, :z 30} 20 :x)))
    (is (= :z (source/state-over {:y 15, :z 30} 30 :x)))
    (is (= :z (source/state-over {:y 15, :z 30} 35 :x))))
  (testing "state-under"
    (is (= :x (source/state-under {} 30 :x)))
    (is (= :x (source/state-under {:y 25} 30 :x)))
    (is (= :y (source/state-under {:y 25} 25 :x)))
    (is (= :y (source/state-under {:y 25} 20 :x)))
    (is (= :y (source/state-under {:y 25, :z 15} 20 :x)))
    (is (= :z (source/state-under {:y 25, :z 15} 15 :x)))
    (is (= :z (source/state-under {:y 25, :z 15} 10 :x)))))


(deftest counter-diffing
  (is (= {:foo {:x 0, :y 5}
          :bar {:x 10, :y 8, :z 3}}
         (source/diff-tracker
           {:foo {:x 200, :y 123, :z 805}
            :bar {:x 320, :y 241, :z 800}}
           {:foo {:x 200, :y 128, :a 1}
            :bar {:x 330, :y 249, :z 803}}))))
