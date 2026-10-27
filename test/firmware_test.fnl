;; ABOUTME: Tests for the firmware glue that turns BLE events into calls on the LED module.
;; ABOUTME: Uses a fake LED module that records every frame passed to show.

(local firmware (require :sendo.firmware))
(local render (require :sendo.render))
(local {: is=} (require :check))

(local colors render.defaults.colors)

;; Same interface as the firmware's C module: clear, set, show.
(fn fake-leds []
  (let [leds {:shown [] :frame {}}]
    (set leds.clear #(set leds.frame {}))
    (set leds.set (fn [i r g b] (tset leds.frame i [r g b])))
    (set leds.show #(table.insert leds.shown leds.frame))
    leds))

{:problem-is-shown
 #(let [leds (fake-leds)
        fw (firmware.start leds)]
    (fw.received 1 "l#S0,E131#")
    (is= [{0 colors.start 131 colors.end}] leds.shown))

 :nothing-is-shown-until-a-problem-is-complete
 #(let [leds (fake-leds)
        fw (firmware.start leds)]
    (fw.received 1 "l#S0,")
    (is= [] leds.shown)
    (fw.received 1 "E131#")
    (is= [{0 colors.start 131 colors.end}] leds.shown))

 :each-problem-replaces-the-previous-one
 #(let [leds (fake-leds)
        fw (firmware.start leds)]
    (fw.received 1 "l#S0#l#E131#")
    (is= [{0 colors.start} {131 colors.end}] leds.shown))

 :clear-shows-an-empty-frame
 #(let [leds (fake-leds)
        fw (firmware.start leds)]
    (fw.received 1 "l#S0#~Z*")
    (is= [{0 colors.start} {}] leds.shown))

 :disconnect-drops-partial-input
 #(let [leds (fake-leds)
        fw (firmware.start leds)]
    (fw.received 1 "l#S0")
    (fw.disconnected 1)
    (fw.received 1 "#")
    (is= [] leds.shown))

 :led-count-comes-from-the-led-module
 #(let [leds (doto (fake-leds) (tset :count 2))
        fw (firmware.start leds)]
    (fw.received 1 "l#S0,E131#")
    (is= [{0 colors.start}] leds.shown))

 :config-can-be-overridden
 #(let [leds (fake-leds)
        config (collect [k v (pairs render.defaults)] k v)]
    (set config.brightness 0)
    ((. (firmware.start leds config) :received) 1 "l#S0#")
    (is= [{0 [0 0 0]}] leds.shown))}
