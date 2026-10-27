;; ABOUTME: Tests for the event handler tying connections, frames and rendering together.
;; ABOUTME: Covers option scoping, clearing, multiple connections and disconnects.

(local app (require :sendo.app))
(local render (require :sendo.render))
(local {: is=} (require :check))

(local colors render.defaults.colors)

(fn receive [state conn bytes]
  (app.handle state {:type :received : conn : bytes}))

{:problem-lights-leds
 #(is= [{:leds {0 colors.start}}] (receive (app.init render.defaults) 1 "l#S0#"))

 :problem-split-across-writes
 #(let [state (app.init render.defaults)]
    (is= [] (receive state 1 "l#S"))
    (is= [{:leds {0 colors.start}}] (receive state 1 "0#")))

 :options-apply-to-the-next-problem
 #(is= [{:leds {0 colors.start 1 colors.above}}]
       (receive (app.init render.defaults) 1 "~D*l#S0#"))

 :options-do-not-carry-over
 #(let [state (app.init render.defaults)]
    (receive state 1 "~D*l#S0#")
    (is= [{:leds {0 colors.start}}] (receive state 1 "l#S0#")))

 :clear-turns-everything-off
 #(is= [{:leds {}}] (receive (app.init render.defaults) 1 "~Z*"))

 :clear-discards-pending-options
 #(let [state (app.init render.defaults)]
    (receive state 1 "~D*~Z*")
    (is= [{:leds {0 colors.start}}] (receive state 1 "l#S0#")))

 :each-frame-gives-an-effect-in-order
 #(is= [{:leds {0 colors.start}} {:leds {}}]
       (receive (app.init render.defaults) 1 "l#S0#~Z*"))

 :connections-are-independent
 #(let [state (app.init render.defaults)]
    (is= [] (receive state 1 "~D*l#S"))
    (is= [{:leds {5 colors.end}}] (receive state 2 "l#E5#"))
    (is= [{:leds {0 colors.start 1 colors.above}}] (receive state 1 "0#")))

 :disconnect-drops-partial-input
 #(let [state (app.init render.defaults)]
    (receive state 1 "~D*l#S0")
    (is= [] (app.handle state {:type :disconnected :conn 1}))
    (is= [] (receive state 1 "#"))
    (is= [{:leds {0 colors.start}}] (receive state 1 "l#S0#")))

 ;; Too big for a 32-bit integer: parses as a float on the firmware's Lua.
 :huge-hold-indices-are-skipped
 #(is= [{:leds {0 colors.start}}]
       (receive (app.init render.defaults) 1 "l#S99999999999,S2147483648,S0#"))

 :garbage-has-no-effect
 #(is= [] (receive (app.init render.defaults) 1 "hello"))

 :unknown-events-have-no-effect
 #(is= [] (app.handle (app.init render.defaults) {:type :connected :conn 1}))}
