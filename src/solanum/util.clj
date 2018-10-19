(ns solanum.util
  "Shared utility code. Should not be used by source or output
  implementations."
  (:require
    [clojure.string :as str]))


(defn tagged?
  "True if the attributes include some tag values."
  [x]
  (boolean (seq (:tags x))))


(defn merge-tags
  "Combine two tag vectors together."
  [a b]
  (vec (distinct (concat a b))))


(defn merge-attrs
  "Merge attribute maps, handling tags correctly."
  ([a b]
   (let [attrs (merge a b)]
     (if (or (tagged? a) (tagged? b))
       (assoc attrs :tags (merge-tags (:tags a) (:tags b)))
       attrs)))
  ([a b & more]
   (reduce merge-attrs (list* a b more))))


(defn merge-vec
  "Merge two vectors of configuration together by concatenating them."
  [a b]
  (into (vec a) b))


(defn keybabify
  "Replace underscores in a keyword with hyphens. Only uses the name portion."
  [k]
  (keyword (str/replace (name k) "_" "-")))