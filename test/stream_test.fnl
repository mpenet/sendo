;; ABOUTME: Tests for splitting chunked BLE writes into options and holds frames.
;; ABOUTME: Covers chunk boundaries, resync on garbage and size limits.

(local stream (require :sendo.stream))
(local {: is=} (require :check))

(fn feed-all [chunks]
  (let [s (stream.new)
        out []]
    (each [_ chunk (ipairs chunks)]
      (each [_ frame (ipairs (stream.feed s chunk))]
        (table.insert out frame)))
    out))

(fn split-at [text i]
  [(text:sub 1 i) (text:sub (+ i 1))])

(fn bytes [text]
  (fcollect [i 1 (length text)] (text:sub i i)))

{:single-write
 #(is= [{:holds "S5,P9,E18"}] (feed-all ["l#S5,P9,E18#"]))

 :options-are-their-own-frame
 #(is= [{:options "D,M"} {:holds "S5,E18"}] (feed-all ["~D,M*l#S5,E18#"]))

 :any-split-point-gives-the-same-frames
 #(let [text "~D,M*l#S5,P9,E18#"]
    (for [i 0 (length text)]
      (is= [{:options "D,M"} {:holds "S5,P9,E18"}] (feed-all (split-at text i))
           (.. "split at " i))))

 :one-byte-per-write
 #(is= [{:options "D,M"} {:holds "S5,E18"}] (feed-all (bytes "~D,M*l#S5,E18#")))

 :several-frames-in-one-write
 #(is= [{:holds "S1"} {:options "Z"} {:holds "E2"}]
       (feed-all ["l#S1#~Z*l#E2#"]))

 :empty-problem-is-a-frame
 #(is= [{:holds ""}] (feed-all ["l##"]))

 :bytes-outside-a-frame-are-ignored
 #(is= [{:holds "S5"}] (feed-all ["xx\255l" "l#S5#"]))

 :invalid-byte-drops-the-open-problem
 #(is= [{:holds "E2"}] (feed-all ["l#S5\255,P9#" "l#E2#"]))

 :invalid-byte-drops-the-open-options
 #(is= [{:holds "S1"}] (feed-all ["~D,x*l#S1#"]))

 :start-marker-restarts-an-open-problem
 #(is= [{:holds "P9"}] (feed-all ["l#S5,l#P9#"]))

 :options-marker-restarts-an-open-problem
 #(is= [{:options "D"} {:holds "S1"}] (feed-all ["l#S5,~D*l#S1#"]))

 :oversized-problem-is-dropped
 #(let [huge (.. "l#" (string.rep "P1," 200) "#")]
    (is= [{:holds "E2"}] (feed-all [huge "l#E2#"])))

 :oversized-options-are-dropped
 #(let [huge (.. "~" (string.rep "D," 300) "*")]
    (is= [{:holds "E2"}] (feed-all [huge "l#E2#"])))

 :streams-are-independent
 #(let [a (stream.new)
        b (stream.new)]
    (stream.feed a "~D*l#S1")
    (is= [{:holds "E2"}] (stream.feed b "l#E2#"))
    (is= [{:holds "S1,P3"}] (stream.feed a ",P3#")))}
