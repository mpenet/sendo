;; ABOUTME: Host simulator: feeds stdin lines to the firmware logic as BLE writes and draws the board.
;; ABOUTME: Each line is one write from a single connection; usage: make sim < sim/samples.txt

(local app (require :sendo.app))
(local render (require :sendo.render))
(local terminal (require :terminal))

(local state (app.init render.defaults))

(each [line (io.lines)]
  (print (.. "write: " line))
  (each [_ effect (ipairs (app.handle state {:type :received :conn 1 :bytes line}))]
    (io.write "\n" (terminal.draw state.config effect.leds) "\n")))
