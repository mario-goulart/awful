(use awful)

(define-session-page "said"
  (lambda ()
    (with-request-variables (said)
      (cond (said
             ($session-set! 'said said)
             `(a (@ (href "said")) "click here"))
            (($session 'said)
             => (lambda (said)
                  `("You said: " ,said)))
            (else
             `(form (@ (action "said")
                       (method "post"))
                    `((input (@ (type "text") (name "said")))
                      (input (@ (type "submit")))))))))
  method: '(get post))
