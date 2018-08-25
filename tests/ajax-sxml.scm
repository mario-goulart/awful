(cond-expand
  (chicken-4
   (use awful))
  (chicken-5
   (import awful))
  (else
   (error "Unsupported CHICKEN version.")))

(define-page (main-page-path)
  (lambda ()
    (ajax "foo" 'foo 'click
          (lambda ()
            `((bar . '(b "bold"))
              (baz . '(i "italic"))
              (a-link . ,(link "/" "this"))))
          update-targets: #t)

    `((a (@ (href "#") (id "foo")) "Click me")
      (div (@ (id "bar")))
      (div (@ (id "baz")))
      (div (@ (id "a-link")))))
  use-ajax: #t)
