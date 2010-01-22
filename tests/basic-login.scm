(require-extension awful)

(enable-session #t)

(define-login-trampoline "/login-trampoline")

(valid-password?
 (lambda (user password)
   (equal? user password)))
  
(define-page (main-page-path)
  (lambda ()
    "Hello world!"))

(define-page (login-page-path)
  (lambda ()
    (login-form))
  no-session: #t)
