;; ABOUTME: Tests for the boot self-check that runs the protocol core on a fixed message.
;; ABOUTME: Its output line must be identical on the host and on the firmware.

(local selfcheck (require :sendo.selfcheck))
(local {: is=} (require :check))

{:summarises-lit-leds-in-led-order
 #(is= "selfcheck leds=5 0:0,255,0 1:32,32,0 5:0,0,255 6:32,32,0 131:255,0,0"
       (selfcheck.run))}
