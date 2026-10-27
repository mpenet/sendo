;; ABOUTME: Turns parsed holds into the set of lit LEDs and their colours.
;; ABOUTME: Applies role colours, LED mapping, lights above holds, brightness and a current limit.

(local grid (require :sendo.grid))

(local defaults
  {:board grid.mini
   :led-count 150
   ;; Optional hold index -> LED index overrides; unmapped holds use their own index.
   :ledmap nil
   :brightness 255
   ;; WS2811 draws about 20 mA per channel at full intensity.
   :ma-per-channel 20
   :max-current-ma 3000
   :colors {:start [0 255 0]
            :move [0 0 255]
            :right [0 0 255]
            :left [128 0 255]
            :match [255 0 128]
            :foot [0 255 255]
            :end [255 0 0]
            :above [32 32 0]}})

(fn led-for [config index]
  (let [led (or (?. config :ledmap index) index)]
    (when (and (<= 0 led) (< led config.led-count))
      led)))

(fn index-above [board index]
  (let [{: col : row} (grid.index->cell board index)]
    (grid.cell->index board {: col :row (+ row 1)})))

(fn light [config lit index color]
  (case (led-for config index)
    led (tset lit led color)))

(fn map-channels [lit f]
  (collect [led color (pairs lit)]
    led (icollect [_ c (ipairs color)] (f c))))

(fn current-ma [config lit]
  (accumulate [sum 0 _ [r g b] (pairs lit)]
    (+ sum (/ (* (+ r g b) config.ma-per-channel) 255))))

(fn limit-current [config lit]
  (let [ma (current-ma config lit)]
    (if (< config.max-current-ma ma)
        (let [factor (/ config.max-current-ma ma)]
          (map-channels lit #(math.floor (* $ factor))))
        lit)))

(fn apply-brightness [config lit]
  (map-channels lit #(// (* $ config.brightness) 255)))

;; Returns {led-index [r g b]} for every LED that should be on.
(fn render [config holds options]
  (let [lit {}
        on-board (icollect [_ hold (ipairs holds)]
                   (when (grid.index->cell config.board hold.index) hold))]
    (when options.lights-above
      (each [_ {: role : index} (ipairs on-board)]
        (let [above (index-above config.board index)]
          (when (and above (not= role :end))
            (light config lit above config.colors.above)))))
    (each [_ {: role : index} (ipairs on-board)]
      (light config lit index (. config.colors role)))
    (->> lit
         (apply-brightness config)
         (limit-current config))))

{: defaults : render}
