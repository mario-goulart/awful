;; Copyright (c) 2010-2014, Mario Domenech Goulart
;; All rights reserved.
;;
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions
;; are met:
;; 1. Redistributions of source code must retain the above copyright
;;    notice, this list of conditions and the following disclaimer.
;; 2. Redistributions in binary form must reproduce the above copyright
;;    notice, this list of conditions and the following disclaimer in the
;;    documentation and/or other materials provided with the distribution.
;; 3. The name of the authors may not be used to endorse or promote products
;;    derived from this software without specific prior written permission.
;;
;; THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS
;; OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY
;; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
;; GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
;; IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
;; OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
;; IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

(use test http-client posix setup-api intarweb uri-common awful html-tags)

(define server-uri (sprintf "http://localhost:~a" (server-port)))

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

(define (expect text #!key title headers)
  ((page-template) text
   title: title
   headers: headers))

(define (expect/sxml text #!key title no-template headers)
  (let ((no-template-page
         (lambda (contents . kw-args)
           contents)))
    (parameterize ((generate-sxml? #t))
      ((sxml->html) ((if no-template
                         no-template-page
                         (page-template))
                     `(,(text))
                     title: title
                     headers: headers)))))


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


;;; literal-script/style?
(test-begin "literal-script/style?")
(test (expect/sxml (lambda ()
                     "<b>")
                   headers: '(script (@ (type "text/javascript")) (literal "<b>")))
      (get "/literal-js/use-sxml"))

(test (expect/sxml (lambda ()
                     "<b>")
                   headers: '(script (@ (type "text/javascript")) "<b>"))
      (get "/no-literal-js/use-sxml"))

(test (expect/sxml (lambda ()
                     "<b>")
                   headers: '(script (@ (type "text/javascript")) (literal "<b>")))
      (get "/literal-js/enable-sxml"))

(test (expect/sxml (lambda ()
                     "<b>")
                   headers: '(script (@ (type "text/javascript")) (literal "&lt;b&gt;")))
      (get "/no-literal-js/enable-sxml"))

(test (expect "<b>" headers: "<script type='text/javascript'><b></script>")
      (get "/literal-js/strings"))

(test (expect "<b>" headers: "<script type='text/javascript'><b></script>")
      (get "/no-literal-js/strings"))
(test-end "literal-script/style?")


;;; add-css
(test-begin "add-css")
(test (expect "foo" headers: (<style> ".foo { font-size: 12pt; }"))
      (get "/add-literal-css"))

(test (expect/sxml (lambda () "foo") headers: '(style (literal ".foo { font-size: \"12pt\"; }")))
      (get "/add-literal-css/enable-sxml"))

(test (expect "foo" headers: (<style> ".foo { font-size: &quot;12pt&quot;; }"))
      (get "/add-css"))

(test (expect/sxml (lambda () "foo") headers: '(style (literal ".foo { font-size: &quot;12pt&quot;; }")))
      (get "/add-css/enable-sxml"))

(test (expect "foo" headers: (<style> ".foo { font-size: 12pt; }.bar { font-size: 12pt; }"))
      (get "/add-2-css"))
(test-end "add-css")


;;; SXML
(test-begin "SXML")
(test (expect/sxml (lambda () '(span "foo"))) (get "/sxml-foo"))
(test (expect/sxml (lambda () (link "foo" '(i "bar")))) (get "/sxml-link"))
(test (expect/sxml (lambda () (link "foo" '(i "bar"))) no-template: #t)
      (get "/sxml-link-no-template"))
(test #f (string-contains (get "/sxml/headers") "&lt"))
(test-end "SXML")

;;; undefine-page
(test-begin "undefine-page")
(test (expect "undefined") (get "/undefine/page"))
(test-error (get "/undefine/page"))
(test (expect "undefined") (get "/undefine/page/get-only"))
(test-error (get "/undefine/page/get-only"))
(test-end "undefine-page")

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

;;; app-root-path
(test-begin "app-root-path")
(test (expect "app-root-path") (get "/app-root-path"))
(test (expect "app-root-path/foo") (get "/app-root-path/foo"))
(test-end "app-root-path")

;;; DB mock
(test-begin "db-mock")
(test "a-connection" (get "/db/connection"))
(test "()" (get "/db/get?key=foo"))
(test "a-default" (get "/db/get?key=foo&default=a-default"))
(get "/db/set?key=foo&value=a-foo")
(get "/db/set?key=bar&value=a-bar")
(get "/db/set?key=baz&value=a-baz")
(test "a-foo" (get "/db/get?key=foo"))
(test "a-bar" (get "/db/get?key=bar"))
(test "a-baz" (get "/db/get?key=baz"))
(test-end "db-mock")

(test-end "awful")
