#!/usr/bin/awful

(use awful)

(valid-password? (lambda _ #t))

(enable-session #t)

(enable-session-inspector "/session-inspector")

(session-inspector-access-control (lambda _ #t))

(define-login-trampoline "/login-trampoline")

(define-page (login-page-path)
  (lambda ()
    (login-form))
  no-session: #t)

(define-page (main-page-path)
  (lambda ()
    ($session-set! 'foo 'bar)
    ($session-set! 'proc (lambda () #f))
    "hello"))
