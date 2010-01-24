;; Configuration file for tests.  To be used together with with other
;; test files, like:
;;
;;    $ awful ajax.scm conf.scm

(require-extension spiffy awful html-tags)

(root-path ".")
(debug-log (current-error-port))

(page-exception-message
 (lambda (exn)
   (<pre> convert-to-entities?: #t
          (with-output-to-string
            (lambda ()
              (print-call-chain)
              (print-error-message exn))))))
