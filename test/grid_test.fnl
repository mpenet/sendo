;; ABOUTME: Tests for mapping hold indices to grid cells and names.
;; ABOUTME: Covers the Mini snake layout, round trips and out-of-range input.

(local grid (require :sendo.grid))
(local {: is=} (require :check))

(local mini grid.mini)

{:first-column-runs-up
 #(do
    (is= "A1" (grid.index->name mini 0))
    (is= "A12" (grid.index->name mini 11)))

 :second-column-runs-down
 #(do
    (is= "B12" (grid.index->name mini 12))
    (is= "B1" (grid.index->name mini 23)))

 :last-index-is-top-of-last-column
 #(is= "K12" (grid.index->name mini 131))

 :cells-are-one-based
 #(is= {:col 2 :row 12} (grid.index->cell mini 12))

 :every-index-round-trips-through-its-name
 #(for [i 0 131]
    (is= i (grid.name->index mini (grid.index->name mini i)) (.. "index " i)))

 :every-cell-is-reached-exactly-once
 #(let [seen {}]
    (for [i 0 131]
      (let [name (grid.index->name mini i)]
        (is= nil (. seen name) (.. name " reached twice"))
        (tset seen name true)))
    (is= 132 (length (icollect [k (pairs seen)] k))))

 :indices-outside-the-board-have-no-cell
 #(do
    (is= nil (grid.index->cell mini -1))
    (is= nil (grid.index->cell mini 132))
    (is= nil (grid.index->cell mini 1.5)))

 :malformed-or-off-board-names-have-no-index
 #(each [_ name (ipairs ["L1" "A13" "A0" "a1" "A01" "A" "1A" ""])]
    (is= nil (grid.name->index mini name) name))

 :board-size-is-configurable
 #(let [standard {:cols 11 :rows 18}]
    (is= "A18" (grid.index->name standard 17))
    (is= "K18" (grid.index->name standard 197))
    (is= nil (grid.index->name standard 198)))}
