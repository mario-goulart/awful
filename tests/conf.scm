;; Configuration file for tests.  To be used together with with other
;; test files, like:
;;
;;    $ awful ajax.scm conf.scm

(cond-expand
  (chicken-4
   (use awful spiffy))
  (chicken-5
   (import awful spiffy))
  (else
   (error "Unsupported CHICKEN version.")))

(debug-log (current-error-port))

(page-exception-message
 (lambda (exn)
   `(pre
     ,(with-output-to-string
        (lambda ()
          (print-call-chain)
          (print-error-message exn))))))
