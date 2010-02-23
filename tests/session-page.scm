(use posix awful html-tags)

(define-session-page (main-page-path)
  (lambda ()
    ($session-set! 'foo 'bar)
    (->string ($session 'foo))))

(define-page "/no-session"
  (lambda ()
    (handle-exceptions
     exn
     "no session"
     ($session 'foo))))

