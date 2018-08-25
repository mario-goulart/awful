;; Test for authentication.  Use the same string for user and
;; password.

(cond-expand
  (chicken-4
   (use awful))
  (chicken-5
   (import awful))
  (else
   (error "Unsupported CHICKEN version.")))

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
