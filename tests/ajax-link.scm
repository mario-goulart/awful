(cond-expand
  (chicken-4
   (use awful posix))
  (chicken-5
   (import (chicken time))
   (import awful))
  (else
   (error "Unsupported CHICKEN version.")))

(enable-ajax #t)

(define-page (main-page-path)
  (lambda ()
    `(,(ajax-link "foo" 'foo "ajax-link"
                  (lambda ()
                    (current-seconds))
                  charset: "foo"
                  target: "bar")
      (span (@ (id "bar"))))))
