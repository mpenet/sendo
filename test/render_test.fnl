;; ABOUTME: Tests for turning parsed holds into lit LEDs and colours.
;; ABOUTME: Covers role colours, LED mapping, lights above holds and power limits.

(local render (require :sendo.render))
(local grid (require :sendo.grid))
(local {: is=} (require :check))

(fn config [overrides]
  (let [c (collect [k v (pairs render.defaults)] k v)]
    (each [k v (pairs (or overrides {}))]
      (tset c k v))
    c))

(local colors render.defaults.colors)

{:hold-lights-its-led-in-the-role-colour
 #(is= {0 colors.start} (render.render (config) [{:role :start :index 0}] {}))

 :every-role-has-a-colour
 #(each [_ role (ipairs [:start :move :end :right :left :match :foot])]
    (is= {5 (. colors role)} (render.render (config) [{: role :index 5}] {}) role))

 :holds-off-the-board-are-skipped
 #(is= {} (render.render (config) [{:role :start :index 132}] {}))

 :ledmap-moves-holds-to-other-leds
 #(is= {7 colors.end}
       (render.render (config {:ledmap {3 7}}) [{:role :end :index 3}] {}))

 :leds-past-the-strip-are-skipped
 #(is= {} (render.render (config {:ledmap {3 150}}) [{:role :end :index 3}] {}))

 :lights-above-in-an-upward-column
 #(is= {0 colors.start 1 colors.above}
       (render.render (config) [{:role :start :index 0}] {:lights-above true}))

 :lights-above-in-a-downward-column
 #(let [b11 (grid.name->index grid.mini "B11")
        b12 (grid.name->index grid.mini "B12")]
    (is= {b11 colors.move b12 colors.above}
         (render.render (config) [{:role :move :index b11}] {:lights-above true})))

 :no-light-above-the-top-row
 #(let [a12 (grid.name->index grid.mini "A12")]
    (is= {a12 colors.move}
         (render.render (config) [{:role :move :index a12}] {:lights-above true})))

 :no-light-above-end-holds
 #(is= {0 colors.end}
       (render.render (config) [{:role :end :index 0}] {:lights-above true}))

 :hold-colour-wins-over-light-above
 #(is= {0 colors.start 1 colors.move 2 colors.above}
       (render.render (config) [{:role :start :index 0} {:role :move :index 1}]
                      {:lights-above true}))

 :brightness-scales-colours
 #(is= {0 [0 127 0]}
       (render.render (config {:brightness 127 :colors {:start [0 255 0]}})
                      [{:role :start :index 0}] {}))

 :current-limit-scales-everything-down
 #(let [c (config {:colors {:start [255 0 0]} :ma-per-channel 20 :max-current-ma 30})
        lit (render.render c [{:role :start :index 0} {:role :start :index 1}] {})]
    (is= {0 [191 0 0] 1 [191 0 0]} lit))

 :within-current-limit-is-untouched
 #(let [c (config {:colors {:start [255 0 0]} :ma-per-channel 20 :max-current-ma 40})]
    (is= {0 [255 0 0] 1 [255 0 0]}
         (render.render c [{:role :start :index 0} {:role :start :index 1}] {})))}
