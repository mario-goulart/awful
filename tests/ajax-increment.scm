(cond-expand
  (chicken-4
   (use awful))
  (chicken-5
   (import awful))
  (else
   (error "Unsupported CHICKEN version.")))

(define-page (main-page-path)
  (let ((counter 0))
    (lambda ()
      (ajax "inc" 'inc 'click
            (lambda ()
              (with-request-variables ((current-number as-number))
                (set! counter (+ current-number 1))
                counter))
            arguments: `((current-number . "$('#current-number').text()"))
            target: "current-number")
      `((div (@ (id "current-number"))
             ,counter)
        (a (@ (href "#")
              (id "inc"))
           "Increment"))))
  use-ajax: #t)
