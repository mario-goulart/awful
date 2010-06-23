#!/usr/bin/awful

(use awful)

(page-template (lambda (contents . rest) contents))

(define-page "a" (lambda () "a"))

;; Redirections
(define-page "/foo"
  (lambda ()
    (redirect-to "/bar")))

(define-page "/bar"
  (lambda ()
    "bar"))

(define-page "/ra" (cut redirect-to "/rb"))
(define-page "/rb" (cut redirect-to "/rc"))
(define-page "/rc" (cut redirect-to "/rd"))
(define-page "/rd" (lambda () "D"))
