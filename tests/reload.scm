;; Steps:
;; 1. access http://localhost:8080/test => You should see "foo"
;; 2. edit this file so the test page shows "bar" instead of "foo"
;; 3. access http://localhost:8080/reload => You should see "Reloaded"
;; 4. access http://localhost:8080/test => You should see "bar"

(cond-expand
  (chicken-4
   (use awful))
  ((or chicken-5 chicken-6)
   (import awful))
  (else
   (error "Unsupported CHICKEN version.")))

(define-page "test"
  (lambda ()
    "foo"))

(define-page "reload"
  (lambda ()
    (load-apps (awful-apps))
    "Reloaded"))
