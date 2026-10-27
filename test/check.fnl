;; ABOUTME: Assertion helpers for the test suite.
;; ABOUTME: Compares values structurally and reports both sides on mismatch.

(local fennel (require :fennel))

(fn deep= [a b]
  (if (and (= :table (type a)) (= :table (type b)))
      (do
        (var same true)
        (each [k v (pairs a) &until (not same)]
          (set same (deep= v (. b k))))
        (each [k (pairs b) &until (not same)]
          (set same (not= nil (. a k))))
        same)
      (= a b)))

(fn is= [expected actual message]
  (when (not (deep= expected actual))
    (error (.. (or message "values differ")
               "\n  expected: " (fennel.view expected)
               "\n  actual:   " (fennel.view actual))
           2)))

{: deep= : is=}
