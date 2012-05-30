(use awful spiffy)

(define-page "a" (lambda () "a"))

;;; Redirections
(define-page "/foo"
  (lambda ()
    (redirect-to "/bar")))

(define-page "/bar"
  (lambda ()
    "bar"))

(define-page "/ra" (cut redirect-to "/rb"))
(define-page "/rb" (cut redirect-to "/rc"))
(define-page "/rc" (cut redirect-to "/rd"))
(define-page "/rd" (lambda () "D"))


;;; Hooks
(define param (make-parameter "unset"))

(add-request-handler-hook!
 'test
 (lambda (path handler)
   (cond ((string-prefix? "/prefix1" path)
          (parameterize ((param "prefix1"))
            (handler)))
         ((string-prefix? "/prefix2" path)
          (parameterize ((param "prefix2"))
            (handler)))
         ((string-prefix? "/prefix3" path)
          (parameterize ((param "prefix3"))
            (handler))))))

(define-page "/prefix1" (lambda () (param)))
(define-page "/prefix2" (lambda () (param)))
(define-page "/prefix3" (lambda () (param)))
(define-page "/param-unset" (lambda () (param)))


;;; RESTful
(define-page "/post" (lambda () "post") method: 'POST)
(define-page "/get" (lambda () "get") method: 'GET)
(define-page "/get2" (lambda () "get"))
(define-page "/same-path" (lambda () "get") method: 'GET)
(define-page "/same-path" (lambda () "post") method: 'POST)


;;; set-page-title!
(define-page "/a-nice-title"
  (lambda ()
    (set-page-title! "a nice title")
    ""))

(define-page "/another-nice-title"
  (lambda ()
    "")
  title: "another nice title")

(define-page "/confusing-titles"
  (lambda ()
    (set-page-title! "set-by-set")
    "")
  title: "set-by-keyword-param")


;;; define-page returning procedure
(with-output-to-file "ret-proc" (cut display "foo"))

(define-page "/return-procedure"
  (lambda ()
    (lambda ()
      (send-static-file "ret-proc")))
  no-template: #t)
