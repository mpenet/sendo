;; ABOUTME: Splits BLE writes from the MoonBoard app into frames, wherever the writes break.
;; ABOUTME: Emits {:options "D,M"} for "~D,M*" and {:holds "S5,E18"} for "l#S5,E18#"; drops anything malformed.

;; Longest frame body accepted; longer input is treated as garbage.
(local max-body-length 512)

(local tilde (string.byte "~"))
(local star (string.byte "*"))
(local lower-l (string.byte "l"))
(local hash (string.byte "#"))
(local comma (string.byte ","))

(fn upper? [b]
  (<= 65 b 90))

(fn digit? [b]
  (<= 48 b 57))

(fn options-byte? [b]
  (or (upper? b) (= b comma)))

(fn holds-byte? [b]
  (or (upper? b) (digit? b) (= b comma)))

(fn new []
  {:state :idle :buffer []})

(fn start [s state]
  (set s.state state)
  (set s.buffer []))

(fn collect-body [s b allowed? terminator kind out]
  (if (= b terminator)
      (do (table.insert out {kind (string.char (table.unpack s.buffer))})
          (start s :idle))
      (and (allowed? b) (< (length s.buffer) max-body-length))
      (table.insert s.buffer b)
      (start s :idle)))

;; "~" and "l" open a new frame from any state, which resyncs after garbage.
(fn step [s b out]
  (if (= b tilde) (start s :options)
      (= b lower-l) (start s :marker)
      (case s.state
        :options (collect-body s b options-byte? star :options out)
        :marker (start s (if (= b hash) :holds :idle))
        :holds (collect-body s b holds-byte? hash :holds out))))

(fn feed [s chunk]
  (let [out []]
    (for [i 1 (length chunk)]
      (step s (string.byte chunk i) out))
    out))

{: new : feed}
