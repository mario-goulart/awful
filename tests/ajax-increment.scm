(use tcp awful html-tags spiffy-request-vars)

(define counter 0)

(define-page (main-page-path)
  (lambda ()
    (++ (ajax-link "bug" 'bug-link "increment"
                   (lambda ()
                     (let ((c ($ 'counter as-number)))
                       (pp c)
                       (set! counter (add1 c))
                       (number->string counter)))
                   arguments: `((counter . "$('#counter').text()"))
                   target: "counter")
        (<div> id: "counter" (number->string counter))))
  use-ajax: #t)
