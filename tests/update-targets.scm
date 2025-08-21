#!/usr/bin/awful

(cond-expand
  (chicken-4
   (use awful))
  ((or chicken-5 chicken-6)
   (import awful))
  (else
   (error "Unsupported CHICKEN version.")))

(enable-ajax #t)

(define-page (main-page-path)
  (lambda ()

    (ajax "foo" 'foo 'click
          (lambda ()
            '((a . 1) (b . 2) (c . 3)))
          update-targets: #t)

    `(div
      ,(link "#" "foo" id: "foo")
      (div (@ (id "a")))
      (div (@ (id "b")))
      (div (@ (id "c"))))))
