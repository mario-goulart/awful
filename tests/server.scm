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

(use awful spiffy regex)

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

;;; Trailing slash
;; "/trailing-slash/[^/]*" should match "/trailing-slash/foo", but
;; should not match "/trailing-slash/foo/"
(define-page (regexp "/trailing-slash/[^/]*")
  (lambda (path)
    "match"))

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


;;; awful-resources-table
(define-page "/resources-table-is-hash-table"
  (lambda ()
    (let ((resources (awful-resources-table)))
      (if (hash-table? resources)
          "ok"
          "fail"))))

(define-page "/resources-table-contains-return-procedure"
  (lambda ()
    (let loop ((resources (hash-table->alist (awful-resources-table))))
      (if (null? resources)
          "fail"
          (let* ((res (car resources))
                 (path (caar res))
                 (vhost-path (cadar res))
                 (method (caddar res))
                 (handler (cdr res)))
            ;; checking /return-procedure
            (or (and (equal? path "/return-procedure")
                     (equal? vhost-path (current-directory))
                     (eq? method 'GET)
                     (procedure? handler)
                     "ok")
                (loop (cdr resources))))))))


;;; path matcher as procedure
(define (match-path path)
  (and (string-prefix? "/path-procedure" path)
       (let ((tokens (string-split path "/")))
         (and (not (null? (cdr tokens)))
              (list (cadr tokens))))))

(define-page match-path
  (lambda (id)
    id))


;;; Multiple methods
(define-page "/multiple-methods"
  (lambda ()
    "foo")
  method: '(GET POST))


;;; Handler returning procedure
(let ((file "handler-returning-procedure"))
  (delete-file* file)
  (with-output-to-file file (cut display "foo"))

  (define-page (string-append "/" file)
    (lambda ()
      (lambda ()
        (send-static-file file)))))


;;; literal-script/style?
(add-request-handler-hook!
 'literal-js
 (lambda (path handler)
   (cond ((string-prefix? "/literal-js/enable-sxml" path)
          (parameterize ((literal-script/style? #t)
                         (enable-sxml #t))
            (handler)))
         ((string-prefix? "/literal-js" path)
          (parameterize ((literal-script/style? #t))
            (handler))))))

(define-page "/literal-js/use-sxml"
  (lambda ()
    (add-javascript "<b>"))
  use-sxml: #t)

(define-page "/no-literal-js/use-sxml"
  (lambda ()
    (add-javascript "<b>"))
  use-sxml: #t)

(parameterize ((enable-sxml #t))
  (define-page "/literal-js/enable-sxml"
    (lambda ()
      (add-javascript "<b>"))))

(parameterize ((enable-sxml #t))
  (define-page "/no-literal-js/enable-sxml"
    (lambda ()
      (add-javascript "<b>"))))

(define-page "/literal-js/strings"
  (lambda ()
    (add-javascript "<b>")))

(define-page "/no-literal-js/strings"
  (lambda ()
    (add-javascript "<b>")))


;;; add-css
(add-request-handler-hook!
 'literal-css
 (lambda (path handler)
   (cond ((string-prefix? "/add-literal-css/enable-sxml" path)
          (parameterize ((literal-script/style? #t)
                         (enable-sxml #t))
            (handler)))
         ((string-prefix? "/add-literal-css" path)
          (parameterize ((literal-script/style? #t))
            (handler))))))

(define-page "/add-literal-css"
  (lambda ()
    (add-css ".foo { font-size: 12pt; }")
    "foo"))

(parameterize ((enable-sxml #t))
  (define-page "/add-literal-css/enable-sxml"
    (lambda ()
      (add-css ".foo { font-size: \"12pt\"; }")
      "foo")))

(define-page "/add-css"
  (lambda ()
    (add-css ".foo { font-size: \"12pt\"; }")
    "foo"))

(parameterize ((enable-sxml #t))
  (define-page "/add-css/enable-sxml"
    (lambda ()
      (add-css ".foo { font-size: \"12pt\"; }")
      "foo")))

(define-page "/add-2-css"
  (lambda ()
    (add-css ".foo { font-size: 12pt; }")
    (add-css ".bar { font-size: 12pt; }")
    "foo"))

;;; SXML
(define-page "/sxml-foo"
  (lambda ()
    '(span "foo"))
  use-sxml: #t)

(define-page "/sxml-link"
  (lambda ()
    (link "foo" '(i "bar")))
  use-sxml: #t)

(define-page "/sxml-link-no-template"
  (lambda ()
    (link "foo" '(i "bar")))
  no-template: #t
  use-sxml: #t)

(parameterize ((enable-sxml #t))
  (define-page "/sxml/headers"
    (lambda ()
      '("foo"))
    headers: (include-javascript "some-js.js")))


;;; undefine-page
(define-app undefine-page
  matcher: '("/" "undefine")

  (define-page "/undefine/page/get-only"
    (lambda ()
      (undefine-page "/undefine/page/get-only")
      "undefined")
    method: 'get)

  (define-page "/undefine/page"
    (lambda ()
      (undefine-page "/undefine/page")
      "undefined"))

) ;; end undefine-page app

;;; define-app

(define define-app-param (make-parameter #f))

(define (define-app-test-handler)
  (conc "app" (define-app-param)))

;; Matcher as procedure
(define-app app1
  matcher: (lambda (path) (string-prefix? "/app1" path))
  parameters: ((define-app-param 1))

  (define-page "/app1" define-app-test-handler)
  (define-page "/app1/another-page" define-app-test-handler))

;; Matcher as list
(define-app app2
  matcher: '("/" "app2")
  parameters: ((define-app-param 2))

  (define-page "/app2" define-app-test-handler)
  (define-page "/app2/another-page" define-app-test-handler))

;; Matcher as regex
(define-app app3
  matcher: (regexp "(/app3|/app3/.*)")
  parameters: ((define-app-param 3))

  (define-page "/app3" define-app-test-handler)
  (define-page "/app3/another-page" define-app-test-handler))

;; Using handler-hook
(define-app app4
  matcher: '("/" "app4")
  handler-hook: (lambda (handler)
                  (parameterize ((define-app-param 4))
                    (handler)))

  (define-page "/app4" define-app-test-handler)
  (define-page "/app4/another-page" define-app-test-handler))

;; app-root-path
(parameterize ((app-root-path "/app-root-path"))

  (define-page (main-page-path)
    (lambda ()
      "app-root-path"))

  (define-page "foo"
    (lambda ()
      "app-root-path/foo"))
  )

;;; DB mock
(let ()

  (define *the-db* '())

  (define (enable-db . ignore) ;; backward compatibility: `enable-db' was a parameter
    (switch-to-mock-db))

  (define (switch-to-mock-db)
    (db-enabled? #t)
    (db-connect (lambda (credentials) credentials))
    (db-disconnect void)
    (db-inquirer
     ;; Query lang:
     ;; * get <key>
     ;; * set <key> <value>
     (lambda (q #!key (default '()) values)
       (when (or (not (list q))
                 (null? (cdr q)))
         (error '$db "Invalid query syntax"))
       (case (car q)
         ((get) (let* ((not-set (list 'not-set))
                       (val (alist-ref (cadr q) *the-db* equal? not-set)))
                  (if (eq? val not-set)
                      default
                      val)))
         ((set) (if (null? (cddr q))
                    (error '$db "Invalid query syntax")
                    (set! *the-db* (alist-update (cadr q) (caddr q) *the-db*))))
         (else (error '$db "Unknown query statement" (car q))))))
    )

  (define-app db-mock
    matcher: (lambda (path) (string-prefix? "/db" path))
    handler-hook: (lambda (handler)
                    (switch-to-mock-db)
                    (parameterize ((page-template
                                    (lambda (content . args)
                                      content))
                                   (db-credentials 'a-connection))
                      (handler)))

    (define *the-db* '())

    (define-page "/db/get"
      (lambda ()
        (with-request-variables ((key as-symbol) default)
          (->string ($db `(get ,key) default: (or default '()))))))

    (define-page "/db/set"
      (lambda ()
        (with-request-variables ((key as-symbol) value)
          ($db `(set ,key ,value))
          value)))

    (define-page "/db/connection"
      (lambda ()
        (->string (db-connection))))

    )) ;; end db-mock app
