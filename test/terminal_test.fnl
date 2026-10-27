;; ABOUTME: Tests for drawing the board's lit LEDs as coloured text.
;; ABOUTME: Covers grid orientation, colours and following the LED mapping.

(local terminal (require :terminal))
(local {: is=} (require :check))

(local board {:cols 2 :rows 2})

(fn dot [r g b]
  (.. "\27[38;2;" r ";" g ";" b "m●\27[0m"))

{:empty-board
 #(is= "   A B\n 2 · ·\n 1 · ·\n" (terminal.draw {: board} {}))

 :lit-holds-are-coloured-dots-with-row-one-at-the-bottom
 #(is= (.. "   A B\n 2 · " (dot 255 0 0) "\n 1 " (dot 0 255 0) " ·\n")
       (terminal.draw {: board} {0 [0 255 0] 2 [255 0 0]}))

 :cells-show-the-led-they-are-mapped-to
 #(is= (.. "   A B\n 2 · ·\n 1 " (dot 0 255 0) " ·\n")
       (terminal.draw {: board :ledmap {0 3 3 0}} {3 [0 255 0]}))}
