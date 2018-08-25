#!/usr/bin/awful

(cond-expand
  (chicken-4
   (use irregex)
   (use awful))
  (chicken-5
   (import (chicken irregex))
   (import awful))
  (else
   (error "Unsupported CHICKEN version.")))

;; / -> /foo
(define-page (main-page-path) (cut redirect-to "/foo"))

;; /bar.* -> /foo
(define-page (irregex "/bar.*")
  (lambda (_)
    (redirect-to "/foo")))

(define-page "/foo"
  (lambda ()
    "foo"))


;; A chain of redirections.  Access http://localhost:8080/a and you
;; should be redirected to /d through /b and /c
(define-page "/a" (cut redirect-to "/b"))
(define-page "/b" (cut redirect-to "/c"))
(define-page "/c" (cut redirect-to "/d"))
(define-page "/d" (lambda () "D"))

(define-page "/chicken"
  (cut redirect-to "http://www.call-cc.org"))
