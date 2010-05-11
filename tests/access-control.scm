(use awful)

(enable-session #t)

(define-login-trampoline "/login-trampoline")

(valid-password?
 (lambda (user password)
   (equal? user password)))

(page-access-control
 (lambda (path)
   (or (member path `(,(login-page-path) "/login-trampoline"))
       (and (equal? ($ 'user) "mario")
            (equal? path (main-page-path))))))

(define-page (main-page-path)
  (lambda ()
    "Hello world"))

(define-page (login-page-path)
  (lambda ()
    (login-form))
  no-session: #t)
