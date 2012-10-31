(use test http-client posix setup-api intarweb uri-common awful html-tags)

(define server-uri "http://localhost:8080")

(define (get path/vars)
  (let ((val (with-input-from-request
              (make-pathname server-uri path/vars)
              #f
              read-string)))
    (close-all-connections!)
    val))

(define (post path)
  (let ((val (with-input-from-request
              (make-request
               uri: (uri-reference (make-pathname server-uri path))
               method: 'POST)
              #f
              read-string)))
    (close-all-connections!)
    val))

(define (expect text #!key title)
  ((page-template) text title: title))

(define (expect/sxml text #!key title no-template)
  (let ((no-template-page
         (lambda (contents . kw-args)
           contents)))
    (parameterize ((generate-sxml? #t))
      ((sxml->html) ((if no-template
                         no-template-page
                         (page-template))
                     `(,(text)) title: title)))))


;;; cleanup
(if (and (file-exists? "a") (not (directory? "a")))
    (delete-file* "a")
    (remove-directory "a" #f))

(test-begin "awful")

;; When a procedure is bound to a path and the path does not exist,
;; just execute the procedure
(test (expect "a") (get "/a"))
(test (expect "a") (get "/a/"))

;; When a procedure is bound to a path and the path exists and is a
;; directory, but does not contain an index-file, executed the
;; procedure bound to the path
(create-directory "a")
(test (expect "a") (get "/a"))
(test (expect "a") (get "/a/"))

;; When a procedure is bound to a path and the path exists, is a
;; directory and contains an index-file, the response is the file
;; contents
(with-output-to-file (make-pathname "a" "index.html") (cut display "index"))
(test "index" (get "/a"))
(test "index" (get "/a/"))

(remove-directory "a")

;; When a procedure is bound to a path and the path exists and is a
;; file, if the request is either for for <path> or <path>/, the
;; response is the file contents
(with-output-to-file "a" (cut display "file"))
(test "file" (get "/a"))
(test "file" (get "/a/"))

(delete-file* "a")

;; Redirections
(test (expect "bar") (get "/foo"))
(test (expect "D") (get "/ra"))

;; hooks
(test (expect "prefix1") (get "/prefix1"))
(test (expect "prefix2") (get "/prefix2"))
(test (expect "prefix3") (get "/prefix3"))
(test (expect "unset") (get "/param-unset"))

;;; RESTful
(test (expect "post") (post "/post"))
(test (expect "get") (get "/get"))
(test (expect "get") (get "/get2"))
(test (expect "get") (get "/same-path"))
(test (expect "post") (post "/same-path"))


;;; set-page-title!
(test (expect "" title: "a nice title") (get "/a-nice-title"))
(test (expect "" title: "another nice title") (get "/another-nice-title"))
(test (expect "" title: "set-by-set") (get "/confusing-titles"))


;;; define-page returning procedure
(test "foo" (get "/return-procedure"))
(delete-file "ret-proc")


;;; awful-resources-table
(test (expect "ok") (get "/resources-table-is-hash-table"))
(test (expect "ok") (get "/resources-table-contains-return-procedure"))


;;; path matcher as procedure
(test (expect "foo") (get "/path-procedure/foo"))
(test (expect "bar") (get "/path-procedure/bar/baz"))
(test 'ok (handle-exceptions exn
            (if ((condition-predicate 'client-error) exn) ;; 404
                'ok
                'fail)
            (get "/path-procedure")))

;;; Multiple methods
(test (expect "foo") (get "/multiple-methods"))
(test (expect "foo") (post "/multiple-methods"))


;;; Handler returning procedure
(test "foo" (get "/handler-returning-procedure"))


;;; SXML
(test-begin "SXML")
(test (expect/sxml (lambda () '(span "foo"))) (get "/sxml-foo"))
(test (expect/sxml (lambda () (link "foo" '(i "bar")))) (get "/sxml-link"))
(test (expect/sxml (lambda () (link "foo" '(i "bar"))) no-template: #t)
      (get "/sxml-link-no-template"))
(test #f (string-contains (get "/sxml/headers") "&lt"))
(test-end "SXML")

(test-end "awful")


;;; define-app
(test-begin "define-app")
(test (expect "app1") (get "/app1"))
(test (expect "app1") (get "/app1/another-page"))
(test (expect "app2") (get "/app2"))
(test (expect "app2") (get "/app2/"))
(test (expect "app2") (get "/app2/another-page"))
(test (expect "app3") (get "/app3"))
(test (expect "app3") (get "/app3"))
(test (expect "app3") (get "/app3/another-page"))
(test (expect "app4") (get "/app4"))
(test (expect "app4") (get "/app4/another-page"))
(test-end "define-app")
