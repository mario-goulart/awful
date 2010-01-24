(module awful
  (;; Parameters
   reload-path reload-message disable-reload? debug-file debug-db-query?
   debug-db-query-prefix db-credentials enable-db ajax-library
   enable-ajax ajax-namespace enable-session page-access-control
   page-access-denied-message page-doctype page-css page-charset
   login-page-path main-page-path app-root-path valid-password?
   page-template ajax-invalid-session-message web-repl-access-control
   web-repl-access-denied-message session-inspector-access-control
   session-inspector-access-denied-message page-exception-message
   http-request-variables db-connection page-javascript sid
   enable-javascript-compression javascript-compressor

   ;; Procedures
   ++ concat include-javascript add-javascript debug debug-pp $session
   $session-set! $ $db $db-row-obj sql-quote define-page ajax
   ajax-link periodical-ajax login-form define-login-trampoline
   enable-web-repl enable-session-inspector awful-version load-apps

   ;; Required by the awful server
   add-resource! register-dispatcher register-root-dir-handler)

(import scheme chicken data-structures utils extras regex ports srfi-69 files)

;; Units
(use posix srfi-13)

;; Eggs
(use miscmacros postgresql sql-null intarweb spiffy spiffy-request-vars
     html-tags html-utils uri-common http-session jsmin)

;;; Version
(define (awful-version) "0.2")


;;; Parameters

;; User-configurable parameters
(define-parameter reload-path "/reload")
(define-parameter reload-message (<h3> "Reloaded."))
(define-parameter disable-reload? #f)
(define-parameter debug-file #f)
(define-parameter debug-db-query? #t)
(define-parameter debug-db-query-prefix "")
(define-parameter db-credentials #f)
(define-parameter enable-db #f)
(define-parameter ajax-library "http://ajax.googleapis.com/ajax/libs/jquery/1.3/jquery.min.js")
(define-parameter enable-ajax #f)
(define-parameter ajax-namespace "ajax")
(define-parameter enable-session #f)
(define-parameter page-access-control (lambda (path) #t))
(define-parameter page-access-denied-message (lambda (path) (<h3> "Access denied.")))
(define-parameter page-doctype "")
(define-parameter page-css #f)
(define-parameter page-charset #f)
(define-parameter login-page-path "/login") ;; don't forget no-session: #t for this page
(define-parameter main-page-path "/main")
(define-parameter app-root-path "/")
(define-parameter valid-password? (lambda (user password) #f))
(define-parameter page-template html-page)
(define-parameter ajax-invalid-session-message "Invalid session.")
(define-parameter web-repl-access-control (lambda () #f))
(define-parameter web-repl-access-denied-message (<h3> "Access denied."))
(define-parameter session-inspector-access-control (lambda () #f))
(define-parameter session-inspector-access-denied-message (<h3> "Access denied."))
(define-parameter enable-javascript-compression #f)
(define-parameter javascript-compressor jsmin-string)
(define-parameter page-exception-message
  (lambda (exn)
    (<h3> "An error has accurred while processing your request.")))


;; Parameters for internal use
(define-parameter http-request-variables #f)
(define-parameter db-connection #f)
(define-parameter page-javascript "")
(define-parameter sid #f)

;;; Misc
(define ++ string-append)

(define (concat args #!optional (sep ""))
  (string-intersperse (map ->string args) sep))

(define (string->symbol* str)
  (if (string? str)
      (string->symbol str)
      str))

(define (load-apps apps)
  (set! *resources* (make-hash-table equal?))
  (for-each load apps)
  (reload-message))


;;; Javascript
(define (include-javascript file)
  (<script> type: "text/javascript" src: file))

(define (add-javascript . code)
  (page-javascript (++ (page-javascript) (concat code))))

(define (maybe-compress-javascript js no-javascript-compression)
  (if (and (enable-javascript-compression)
           (javascript-compressor)
           (not no-javascript-compression))
      (string-trim-both ((javascript-compressor) js))
      js))


;;; Debugging
(define (debug . args)
  (when (debug-file)
    (with-output-to-file (debug-file)
      (lambda ()
        (print (concat args)))
      append:)))

(define (debug-pp arg)
  (when (debug-file)
    (with-output-to-file (debug-file) (cut pp arg) append:)))


;;; Session access
(define ($session var #!optional default)
  (session-ref (sid) (string->symbol* var) default))

(define ($session-set! var #!optional val)
  (if (list? var)
      (for-each (lambda (var/val)
                  (session-set! (sid) (string->symbol* (car var/val)) (cdr var/val)))
                var)
      (session-set! (sid) (string->symbol* var) val)))

(define (awful-refresh-session!)
  (when (and (enable-session) (session-valid? (sid)))
    (session-refresh! (sid))))


;;; HTTP request variables access
(define ($ var #!optional default converter)
  ((http-request-variables) var default (or converter identity)))


;;; DB access
(define (debug-query q)
  (when (and (debug-file) (debug-db-query?))
    (debug (++ (debug-db-query-prefix) q))))

(define ($db q #!optional default)
  (debug-query q)
  (let ((result (query* (db-connection) q)))
    (if (zero? (row-count result))
        default
        (row-map identity result))))

(define ($db-row-obj q)
  (debug-query q)
  (let ((result (row-alist (query* (db-connection) q))))
    (lambda (field #!optional default)
      (or (alist-ref field result)
          default))))

(define (sql-quote . data)
  (++ "'" (escape-string (db-connection) (concat data)) "'"))


;;; Resources
(define *resources* (make-hash-table equal?))

(define (register-dispatcher)
  (handle-not-found
   (let ((old-handler (handle-not-found)))
     (lambda (_)
       (let* ((path-list (uri-path (request-uri (current-request))))
              (path (if (null? (cdr path-list))
                        (car path-list)
                        (++ "/" (concat (cdr path-list) "/"))))
              (proc (resource-ref path (root-path))))
         (if proc
             (let ((out (->string (proc))))
               (with-headers `((content-type text/html)
                               (content-length ,(string-length out)))
                             (lambda ()
                               (write-logged-response)
                               (unless (eq? 'HEAD (request-method (current-request)))
                                 (display out (response-port (current-response)))))))
             (old-handler _)))))))

(define (resource-ref path vhost-root-path #!optional default)
  (hash-table-ref/default *resources* (cons path vhost-root-path) default))

(define (resource-exists? path vhost-root-path)
  (not (not (resource-ref path vhost-root-path))))

(define (add-resource! path vhost-root-path proc)
  (unless (resource-exists? path vhost-root-path)
    (hash-table-set! *resources* (cons path vhost-root-path) proc)))


;;; Root dir
(define (register-root-dir-handler)
  (handle-directory
   (let ((old-handler (handle-directory)))
     (lambda (path)
       (if (equal? path "/")
           (let ((data (html-page
                        ""
                        headers: (<meta> http-equiv: "refresh" content: (++ "0;url=" (main-page-path))))))
             (with-headers `((content-type text/html)
                             (content-length ,(string-length data)))
                           (lambda ()
                             (write-logged-response)
                             (unless (eq? 'HEAD (request-method (current-request)))
                               (display data (response-port (current-response)))))))
           (old-handler path))))))


;;; Pages
(define (define-page path contents #!key css title doctype headers charset no-ajax
                     no-template no-session no-db vhost-root-path no-javascript-compression)
  (let ((path (make-pathname (app-root-path) path)))
    (add-resource!
     path
     (or vhost-root-path (root-path))
     (lambda ()
       (http-request-variables (request-vars))
       (sid ($ 'sid))
       (when (and (db-credentials) (enable-db) (not no-db))
         (db-connection (connect (db-credentials))))
       (page-javascript "")
       (awful-refresh-session!)
       (let ((out
              (if (or (not (enable-session))
                      no-session
                      (and (enable-session) (session-valid? (sid))))
                  (if (or no-session (not (enable-session)) ((page-access-control) path))
                      (let ((contents
                             (handle-exceptions
                              exn
                              (begin
                                (debug (with-output-to-string
                                         (lambda ()
                                           (print-call-chain)
                                           (print-error-message exn))))
                                ((page-exception-message) exn))
                              (contents))))
                        (if no-template
                            contents
                            ((page-template)
                             contents
                             css: (or css (page-css))
                             title: title
                             doctype: (or doctype (page-doctype))
                             headers: (++ (if (or no-ajax (not (ajax-library)) (not (enable-ajax)))
                                              ""
                                              (<script> type: "text/javascript"
                                                        src: (ajax-library)))
                                          (or headers "")
                                          (if (or no-ajax
                                                  (not (enable-ajax))
                                                  (not (ajax-library)))
                                              (if (string-null? (page-javascript))
                                                  ""
                                                  (<script> type: "text/javascript"
                                                            (maybe-compress-javascript
                                                             (page-javascript)
                                                             no-javascript-compression)))
                                              (<script> type: "text/javascript"
                                                        (maybe-compress-javascript
                                                         (++ "$(document).ready(function(){"
                                                             (page-javascript) "});")
                                                         no-javascript-compression))))
                             charset: (or charset (page-charset)))))
                      ((page-template) ((page-access-denied-message) path)))
                  ((page-template)
                   ""
                   headers: (<meta> http-equiv: "refresh"
                                    content: (++ "0;url=" (login-page-path)
                                                 "?reason=invalid-session&attempted-path=" path))))))
         (when (and (db-connection) (enable-db) (not no-db)) (disconnect (db-connection)))
         out)))))


;;; Ajax
(define (ajax path id event proc #!key target (action 'html) (method 'POST) (arguments '())
              js no-session no-db no-page-javascript vhost-root-path)
  (if (enable-ajax)
      (let ((path (make-pathname (list (app-root-path) (ajax-namespace)) path)))
        (add-resource! path
                       (or vhost-root-path (root-path))
                       (lambda ()
                         (http-request-variables (request-vars))
                         (sid ($ 'sid))
                         (when (and (db-credentials) (enable-db) (not no-db))
                           (db-connection (connect (db-credentials))))
                         (awful-refresh-session!)
                         (if (or (not (enable-session))
                                 no-session
                                 (and (enable-session) (session-valid? (sid))))
                             (if ((page-access-control) path)
                                 (let ((out (proc)))
                                   (when (and (db-credentials) (enable-db) (not no-db))
                                     (disconnect (db-connection)))
                                   out)
                                 ((page-access-denied-message) path))
                             (ajax-invalid-session-message))))
        (http-request-variables (request-vars))
        (sid ($ 'sid))
        (let* ((arguments (if (or (not (enable-session))
                                  no-session
                                  (not (and (enable-session) (session-valid? (sid)))))
                              arguments
                              (cons `(sid . ,(++ "'" (sid) "'")) arguments)))
               (js (++ (page-javascript)
                       (if (and id event)
                           (++ "$('#" (->string id) "')."
                               (if (list? event)
                                   (++ "bind('" (concat event " ") "',")
                                   (++ (->string event) "(")))
                           "")
                       "function(){$.ajax({type:'" (->string method) "',"
                       "url:'" path "',"
                       "success:function(h){"
                       (or js
                           (if target
                               (++ "$('#" target "')." (->string action) "(h);")
                               "return;"))
                       "},"
                       (++ "data:{"
                           (string-intersperse
                            (map (lambda (var/val)
                                   (conc  "'" (car var/val) "':" (cdr var/val)))
                                 arguments)
                            ",") "}")
                       "})}"
                       (if (and id event)
                           ");\n"
                           ""))))
          (unless no-page-javascript (page-javascript js))
          js))
      "")) ;; empty if no-ajax

(define (periodical-ajax path interval proc #!key target (action 'html) (method 'POST)
                         (arguments '()) js no-session no-db vhost-root-path)
  (if (enable-ajax)
      (page-javascript
       (++ "setInterval("
           (ajax path #f #f proc
                 target: target
                 action: action
                 method: method
                 arguments: arguments
                 js: js
                 no-session: no-session
                 no-db: no-db
                 no-page-javascript: #t)
           ", " (->string interval) ");\n"))
      ""))

(define (ajax-link path id text proc #!key target (action 'html) (method 'POST) (arguments '())
                   js no-session no-db (event 'click) vhost-root-path)
  (ajax path id event proc
        target: target
        action: action
        method: method
        arguments: arguments
        js: js
        no-session: no-session
        no-db: no-db)
  (<a> href: "#" id: id text))


;;; Login form
(define (login-form #!key (user-label "User: ")
                          (password-label "Password: ")
                          (submit-label "Submit")
                          (trampoline-path "/login-trampoline"))
  (let ((attempted-path ($ 'attempted-path)))
    (<form> action: trampoline-path method: "post"
            (if attempted-path
                (hidden-input 'attempted-path attempted-path)
                "")
            (<span> id: "user-label" user-label)
            (<input> type: "text" id: "user" name: "user")
            (<span> id: "password-label" password-label)
            (<input> type: "password" id: "password" name: "password")
            (<input> type: "submit" id: "login-submit" value: submit-label))))


;;; Login trampoline (for redirection)
(define (define-login-trampoline path #!key vhost-root-path hook)
  (define-page path
    (lambda ()
      (let* (($ (http-request-variables))
             (user ($ 'user))
             (password ($ 'password))
             (attempted-path ($ 'attempted-path))
             (password-valid? ((valid-password?) user password))
             (new-sid (and password-valid? (session-create))))
        (sid new-sid)
        (when hook (hook user))
        (html-page
         ""
         headers: (<meta> http-equiv: "refresh"
                          content: (++ "0;url="
                                       (if new-sid
                                           (++ (or attempted-path (main-page-path)) "?user=" user "&sid=" new-sid)
                                           (++ (login-page-path) "?reason=invalid-password")))))))
    vhost-root-path: vhost-root-path
    no-session: #t
    no-template: #t))


;;; Web repl
(define (enable-web-repl path #!key css title)
  (enable-ajax #t)
  (define-page path
    (lambda ()
      (if ((web-repl-access-control))
          (let ((web-eval
                 (lambda ()
                   (<pre> convert-to-entities?: #t
                          (with-output-to-string
                            (lambda ()
                              (pp (handle-exceptions
                                   exn
                                   (begin
                                     (print-error-message exn)
                                     (print-call-chain))
                                   (eval `(begin
                                            ,@(with-input-from-string ($ 'code "")
                                                read-file)))))))))))
            (page-javascript "$('#clear').click(function(){$('#prompt').val('');});")
            (ajax (++ path "-eval") 'eval 'click web-eval
                  target: "result"
                  arguments: '((code . "$('#prompt').val()")))

            (++ (<textarea> id: "prompt" name: "prompt" rows: "6" cols: "90")
                (itemize
                 (map (lambda (item)
                        (<a> href: "#" id: (car item) (cdr item)))
                      '(("eval"  . "Eval")
                        ("clear" . "Clear")))
                 list-id: "button-bar")
                (<div> id: "result")))
          (web-repl-access-denied-message)))
    title: (or title "Web REPL")
    css: css))


;;; Session inspector
(define (enable-session-inspector path #!key css title)
  (enable-session #t)
  (define-page path
    (lambda ()
      (if ((session-inspector-access-control))
          (let ((bindings (session-bindings (sid))))
            (if (null? bindings)
                (<h2> "Session for sid " (sid) " is empty")
                (++ (<h2> "Session for " (sid))
                    (tabularize
                     (map (lambda (binding)
                            (let ((var (car binding))
                                  (val (with-output-to-string
                                         (lambda ()
                                           (pp (cdr binding))))))
                              (list var (<pre> val))))
                          bindings)))))
          (session-inspector-access-denied-message)))
    title: (or title "Session inspector")
    css: css))

) ; end module
