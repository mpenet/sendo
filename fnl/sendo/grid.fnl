;; ABOUTME: Maps MoonBoard hold indices to grid cells and names like "A1".
;; ABOUTME: Indices start at 0 and follow the LED strip: column by column, alternately up and down.

(local mini {:cols 11 :rows 12})

(fn on-board? [board col row]
  (and (<= 1 col board.cols) (<= 1 row board.rows)))

(fn index->cell [board index]
  (when (= :integer (math.type index))
    (let [col (+ 1 (// index board.rows))
          step (% index board.rows)
          row (if (= 1 (% col 2)) (+ step 1) (- board.rows step))]
      (when (and (<= 0 index) (on-board? board col row))
        {: col : row}))))

(fn cell->index [board {: col : row}]
  (when (on-board? board col row)
    (let [step (if (= 1 (% col 2)) (- row 1) (- board.rows row))]
      (+ (* (- col 1) board.rows) step))))

(fn cell->name [{: col : row}]
  (.. (string.char (+ 64 col)) row))

(fn name->cell [name]
  (let [(letter digits) (string.match name "^(%u)([1-9]%d*)$")]
    (when letter
      {:col (- (string.byte letter) 64) :row (tonumber digits)})))

(fn index->name [board index]
  (let [cell (index->cell board index)]
    (when cell
      (cell->name cell))))

(fn name->index [board name]
  (let [cell (name->cell name)]
    (when cell
      (cell->index board cell))))

{: mini : index->cell : cell->index : index->name : name->index}
