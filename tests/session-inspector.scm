#!/usr/bin/awful

;; 1. Use any credentials to log in
;; 2. After logging in, you should see "hello"
;; 3. Request /session-inspector

(cond-expand
  (chicken-4
   (use awful))
  ((or chicken-5 chicken-6)
   (import awful))
  (else
   (error "Unsupported CHICKEN version.")))

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
    ($session-set! 'a-procedure (lambda () #f))
    ($session-set! 'a-list (list 1 2 3 4 5))
    ($session-set! 'a-vector (vector 1 2 3 4 5))
    ($session-set! 'a-string "hello world")
    "hello"))
