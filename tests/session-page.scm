(cond-expand
  (chicken-4
   (use awful))
  ((or chicken-5 chicken-6)
   (import (chicken string))
   (import awful))
  (else
   (error "Unsupported CHICKEN version.")))

(define-session-page (main-page-path)
  (lambda ()
    ($session-set! 'foo 'bar)
    `((p ,(->string ($session 'foo)))
      (p ,(link "no-session" "no-session")))))

(define-page "/no-session"
  (lambda ()
    `((p ,(handle-exceptions exn
            "no session"
            ($session 'foo)))
      (p ,(link "with-ajax" "with-ajax")))))

(define-session-page "/with-ajax"
  (lambda ()
    `(,(ajax-link "sid" 'sid "show sid"
                  (lambda ()
                    (sid))
                  target: "echo-area")
      (div (@ (id "echo-area")))))
  use-ajax: #t)
