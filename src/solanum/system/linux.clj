(ns solanum.system.linux
  "Linux utility functions."
  (:require
    [clojure.string :as str])
  (:import
    java.io.FileReader))


(defn read-proc-file
  "Read a file from the `/proc` subsystem. Returns the file contents."
  [path]
  (-> (FileReader. path)
      (slurp)
      (str/trim-newline)))


(defn read-proc-lines
  "Read a vector of lines from the contents of a `/proc` file."
  [path]
  (str/split (read-proc-file path) #"\n"))
