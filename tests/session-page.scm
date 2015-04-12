(use posix awful)

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
