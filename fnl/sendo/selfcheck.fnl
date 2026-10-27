;; ABOUTME: Boot self-check: runs a fixed app message through the protocol core and summarises the result.
;; ABOUTME: The firmware prints the line at startup; it must match what the host produces.

(local app (require :sendo.app))
(local render (require :sendo.render))

(local message "~D*l#S0,P5,E131#")

(fn run []
  (let [[effect] (app.handle (app.init render.defaults) {:type :received :conn 0 :bytes message})
        leds (doto (icollect [led (pairs effect.leds)] led) (table.sort))]
    (.. "selfcheck leds=" (length leds)
        (table.concat (icollect [_ led (ipairs leds)]
                        (.. " " led ":" (table.concat (. effect.leds led) ",")))))))

{: run}
