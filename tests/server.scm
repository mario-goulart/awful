#!/usr/bin/awful

(use awful)

(page-template (lambda (contents . rest) contents))

(define-page "a" (lambda () "a"))
