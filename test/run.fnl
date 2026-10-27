;; ABOUTME: Runs every test in the test files given as arguments.
;; ABOUTME: A test file returns a table of name -> function; exits non-zero on failure.

(local fennel (require :fennel))

(fn sorted-keys [t]
  (doto (icollect [k (pairs t)] k) (table.sort)))

(var test-count 0)
(local failures [])

(each [_ path (ipairs arg)]
  (case (xpcall fennel.dofile debug.traceback path)
    (true tests)
    (each [_ name (ipairs (sorted-keys tests))]
      (set test-count (+ test-count 1))
      (let [(ok err) (xpcall (. tests name) debug.traceback)]
        (when (not ok)
          (table.insert failures (.. path " :: " name "\n" err)))))
    (_ err)
    (table.insert failures (.. path " :: failed to load\n" err))))

(each [_ failure (ipairs failures)]
  (print (.. "FAIL " failure "\n")))

(print (string.format "%d tests, %d failures" test-count (length failures)))
(os.exit (if (= 0 (length failures)) 0 1))
