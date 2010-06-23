(use awful html-utils spiffy-request-vars)

(define-session-page "said"
  (lambda ()
    (with-request-vars* $ (said)
      (cond (said
             ($session-set! 'said said)
             (link "said" "click here"))
            (($session 'said)
             => (lambda (said)
                  (++ "You said: " said)))
            (else (form (++ (text-input 'said)
                            (submit-input))
                        action: "said"
                        method: 'post))))))
