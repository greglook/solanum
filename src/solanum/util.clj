(ns solanum.util
  "Shared utility code. Should not be used by source or output
  implementations.")


(defn- merge-tags
  "Combine two tag vectors together."
  [a b]
  (vec (distinct (concat a b))))


(defn merge-attrs
  "Merge attribute maps, handling tags correctly."
  ([a b]
   (let [attrs (merge a b)]
     (if (or (seq (:tags a)) (seq (:tags b)))
       (assoc attrs :tags (merge-tags (:tags a) (:tags b)))
       attrs)))
  ([a b & more]
   (reduce merge-attrs (list* a b more))))
