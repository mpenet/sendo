;; ABOUTME: Interprets the bodies of options and holds frames sent by the MoonBoard app.
;; ABOUTME: Hold indices stay raw; mapping them onto the board happens elsewhere.

(local option-names {:D :lights-above :Z :clear})

(local roles {:S :start :P :move :E :end
              :R :right :L :left :M :match :F :foot})

(fn parse-options [options]
  (collect [option (options:gmatch "[^,]+")]
    (case (. option-names option)
      name (values name true))))

(fn parse-holds [holds]
  (icollect [token (holds:gmatch "[^,]+")]
    (let [(letter digits) (token:match "^(%u)(%d+)$")
          role (and letter (. roles letter))]
      (when role
        {: role :index (tonumber digits)}))))

{: parse-options : parse-holds}
