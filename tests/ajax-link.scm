(use awful)

(enable-ajax #t)

(define-page (main-page-path)
  (lambda ()
    `(,(ajax-link "foo" 'foo "ajax-link"
                  (lambda ()
                    (current-seconds))
                  charset: "foo"
                  target: "bar")
      (span (@ (id "bar"))))))
