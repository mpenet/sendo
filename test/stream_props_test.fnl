;; ABOUTME: Property tests for the stream: random chunking, random garbage and resync.
;; ABOUTME: Uses a fixed seed so any failure reproduces; the failing case is in the message.

(local fennel (require :fennel))
(local stream (require :sendo.stream))
(local {: is=} (require :check))

(local runs 500)
(local max-body-length 512)

(fn pick [s]
  (let [i (math.random 1 (length s))]
    (s:sub i i)))

(fn gen-options []
  (table.concat (fcollect [_ 1 (math.random 1 3)] (pick "ABCDEFGHIJKLMNOPQRSTUVWXYZ")) ","))

(fn gen-holds []
  (table.concat (fcollect [_ 1 (math.random 0 20)] (.. (pick "SPERLMF") (math.random 0 197))) ","))

;; Returns the wire text for a few messages and the frames it must produce.
(fn gen-messages []
  (let [frames []]
    (for [_ 1 (math.random 1 4)]
      (when (= 1 (math.random 1 2))
        (table.insert frames {:options (gen-options)}))
      (table.insert frames {:holds (gen-holds)}))
    (values (table.concat (icollect [_ f (ipairs frames)]
                            (if f.options (.. "~" f.options "*") (.. "l#" f.holds "#"))))
            frames)))

(fn gen-noise []
  (table.concat (fcollect [_ 1 (math.random 0 80)]
                  (if (= 1 (math.random 1 2))
                      (pick "~*l#,SPE0123456789AZ")
                      (string.char (math.random 0 255))))))

;; An opened frame whose body runs past the size limit.
(fn gen-overlong-frame []
  (.. (if (= 1 (math.random 1 2)) "~" "l#")
      (table.concat (fcollect [_ 1 (math.random max-body-length (* 2 max-body-length))]
                      (pick "ABZ019,")))))

(fn gen-garbage []
  (if (= 1 (math.random 1 4))
      (.. (gen-noise) (gen-overlong-frame) (gen-noise))
      (gen-noise)))

(fn chunk [text]
  (let [chunks []]
    (var i 1)
    (while (<= i (length text))
      (let [size (math.random 1 25)]
        (table.insert chunks (text:sub i (+ i size -1)))
        (set i (+ i size))))
    chunks))

(fn feed-chunks [s chunks]
  (let [out []]
    (each [_ c (ipairs chunks)]
      (each [_ frame (ipairs (stream.feed s c))]
        (table.insert out frame)))
    out))

(fn well-formed? [frame]
  (case frame
    {: options} (and (<= (length options) max-body-length)
                     (not= nil (options:match "^[A-Z,]*$")))
    {: holds} (and (<= (length holds) max-body-length)
                   (not= nil (holds:match "^[A-Z0-9,]*$")))
    _ false))

(fn last-n [list n]
  (fcollect [i (+ 1 (- (length list) n)) (length list)] (. list i)))

{:random-chunking-preserves-frames
 #(do
    (math.randomseed 1)
    (for [_ 1 runs]
      (let [(text frames) (gen-messages)
            chunks (chunk text)]
        (is= frames (feed-chunks (stream.new) chunks) (fennel.view chunks)))))

 :garbage-never-breaks-the-stream
 #(do
    (math.randomseed 2)
    (for [_ 1 runs]
      (let [s (stream.new)
            chunks (chunk (gen-garbage))]
        (each [_ c (ipairs chunks)]
          (each [_ frame (ipairs (stream.feed s c))]
            (is= true (well-formed? frame) (fennel.view {: frame : chunks})))
          (is= true (<= (length s.buffer) max-body-length) (fennel.view chunks))))))

 :valid-messages-are-recovered-after-garbage
 #(do
    (math.randomseed 3)
    (for [_ 1 runs]
      (let [(text frames) (gen-messages)
            chunks (chunk (.. (gen-garbage) text))
            out (feed-chunks (stream.new) chunks)]
        (is= frames (last-n out (length frames)) (fennel.view chunks)))))}
