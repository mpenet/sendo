;; ABOUTME: Handles BLE events: tracks each connection's input and turns problems into LED effects.
;; ABOUTME: Options apply to the next problem only; the "Z" option clears the board.

(local stream (require :sendo.stream))
(local problem (require :sendo.problem))
(local render (require :sendo.render))

(fn init [config]
  {: config :connections {}})

(fn connection [state conn]
  (or (. state.connections conn)
      (let [c {:stream (stream.new) :options {}}]
        (tset state.connections conn c)
        c)))

;; Returns the frame's effect, or nil when the frame only updates the connection.
(fn handle-frame [state c frame]
  (case frame
    {: options} (let [parsed (problem.parse-options options)]
                  (if parsed.clear
                      (do (set c.options {})
                          {:leds {}})
                      (do (set c.options parsed)
                          nil)))
    {: holds} (let [lit (render.render state.config (problem.parse-holds holds) c.options)]
                (set c.options {})
                {:leds lit})))

;; Returns the effects of the event, in order.
(fn handle [state event]
  (case event
    {:type :received : conn : bytes}
    (let [c (connection state conn)]
      (icollect [_ frame (ipairs (stream.feed c.stream bytes))]
        (handle-frame state c frame)))
    {:type :disconnected : conn}
    (do (tset state.connections conn nil)
        [])
    _ []))

{: init : handle}
