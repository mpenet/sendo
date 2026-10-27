;; ABOUTME: Draws the board's lit LEDs as coloured text for the host simulator.
;; ABOUTME: Top row first, columns A.. left to right; each cell shows the LED its hold maps to.

(local grid (require :sendo.grid))
(local render (require :sendo.render))

(fn dot [[r g b]]
  (.. "\27[38;2;" r ";" g ";" b "m●\27[0m"))

(fn cell-text [config lit col row]
  (let [index (grid.cell->index config.board {: col : row})]
    (case (. lit (render.led-index config index))
      color (dot color)
      _ "·")))

(fn header [board]
  (.. "   " (table.concat (fcollect [col 1 board.cols] (string.char (+ 64 col))) " ")))

(fn row-line [config lit row]
  (.. (string.format "%2d " row)
      (table.concat (fcollect [col 1 config.board.cols] (cell-text config lit col row)) " ")))

(fn draw [config lit]
  (let [lines [(header config.board)]]
    (for [row config.board.rows 1 -1]
      (table.insert lines (row-line config lit row)))
    (.. (table.concat lines "\n") "\n")))

{: draw}
