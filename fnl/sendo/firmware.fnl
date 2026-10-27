;; ABOUTME: Entry point the firmware runs: feeds BLE events to the app and shows its LED effects.
;; ABOUTME: The LED module is passed in (C on the device, a fake in tests): clear, set, show.

(local app (require :sendo.app))
(local render (require :sendo.render))

(fn apply-effect [leds effect]
  (case effect
    {:leds lit} (do (leds.clear)
                    (each [led [r g b] (pairs lit)]
                      (leds.set led r g b))
                    (leds.show))))

;; The LED module knows how many LEDs the string has; it overrides the config.
(fn with-led-count [config leds]
  (let [c (collect [k v (pairs config)] k v)]
    (when leds.count
      (set c.led-count leds.count))
    c))

;; Returns the callbacks the firmware calls for each BLE event.
(fn start [leds config]
  (let [state (app.init (with-led-count (or config render.defaults) leds))
        handle (fn [event]
                 (each [_ effect (ipairs (app.handle state event))]
                   (apply-effect leds effect)))]
    {:received (fn [conn bytes] (handle {:type :received : conn : bytes}))
     :disconnected (fn [conn] (handle {:type :disconnected : conn}))}))

{: start}
