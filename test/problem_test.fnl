;; ABOUTME: Tests for interpreting options and holds frames sent by the app.
;; ABOUTME: Covers option names, hold roles and skipping malformed tokens.

(local problem (require :sendo.problem))
(local {: is=} (require :check))

{:holds-keep-their-order-and-roles
 #(is= [{:role :start :index 5} {:role :move :index 9} {:role :end :index 18}]
       (problem.parse-holds "S5,P9,E18"))

 :hand-and-foot-roles
 #(is= [{:role :right :index 1} {:role :left :index 2}
        {:role :match :index 3} {:role :foot :index 4}]
       (problem.parse-holds "R1,L2,M3,F4"))

 :empty-holds-is-an-empty-problem
 #(is= [] (problem.parse-holds ""))

 :malformed-hold-tokens-are-skipped
 #(is= [{:role :start :index 1} {:role :end :index 2}]
       (problem.parse-holds "S1,X5,S,P,,E2"))

 :lights-above-option
 #(is= {:lights-above true} (problem.parse-options "D,M"))

 :clear-option
 #(is= {:clear true} (problem.parse-options "Z"))

 :unknown-options-are-ignored
 #(is= {} (problem.parse-options "M"))

 :options-are-single-letters
 #(is= {} (problem.parse-options "DZ"))}
