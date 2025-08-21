(cond-expand
  (chicken-4
   (use awful))
  ((or chicken-5 chicken-6)
   (import (chicken string)
           (chicken time))
   (import awful jsmin))
  (else
   (error "Unsupported CHICKEN version.")))

(enable-ajax #t)
(enable-javascript-compression #t)

(javascript-compressor jsmin-string)

(define-page (main-page-path)
  (lambda ()
    (add-javascript "/* Here's some JavaScript comment that should "
                    "be stripped from the page. */")
    (ajax "/click" 'clickme '(click dblclick)
          (lambda () (->string (current-seconds)))
          target: "clicked")
    `((a (@ (href "#")
            (id "clickme"))
         "Click me")
      (span (@ (id "clicked"))))))
