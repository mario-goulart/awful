(module awful
  (;; Parameters
   awful-apps debug-file debug-db-query?
   debug-db-query-prefix db-credentials ajax-library
   enable-ajax ajax-namespace enable-session page-access-control
   page-access-denied-message page-doctype page-css page-charset
   login-page-path main-page-path app-root-path valid-password?
   page-template ajax-invalid-session-message web-repl-access-control
   web-repl-access-denied-message session-inspector-access-control
   session-inspector-access-denied-message page-exception-message
   http-request-variables db-connection page-javascript sid
   enable-javascript-compression javascript-compressor debug-resources
   enable-session-cookie session-cookie-name awful-response-headers
   development-mode? enable-web-repl-fancy-editor web-repl-fancy-editor-base-uri
   awful-listen awful-accept awful-backlog awful-listener javascript-position

   ;; Procedures
   ++ concat include-javascript add-javascript debug debug-pp $session
   $session-set! $ $db $db-row-obj sql-quote define-page undefine-page
   define-session-page ajax ajax-link periodical-ajax login-form
   define-login-trampoline enable-web-repl enable-session-inspector
   awful-version load-apps link form redirect-to
   add-request-handler-hook! remove-request-handler-hook!

   ;; spiffy-request-vars wrapper
   with-request-variables true-boolean-values as-boolean as-list
   as-number as-alist as-vector as-hash-table as-string as-symbol
   nonempty

   ;; Required by the awful server
   add-resource! register-dispatcher register-root-dir-handler awful-start

   ;; Required by db-support eggs
   db-enabled? db-inquirer db-connect db-disconnect sql-quoter db-make-row-obj

  ) ; end export list

(import scheme chicken data-structures utils extras ports srfi-69 files srfi-1)

;; Units
(use posix srfi-13 tcp)

;; Eggs
(use intarweb spiffy spiffy-request-vars html-tags html-utils uri-common
     http-session json spiffy-cookies regex)

;;; Version
(define (awful-version) "0.31")


;;; Parameters

;; User-configurable parameters
(define awful-apps (make-parameter '()))
(define debug-file (make-parameter #f))
(define debug-db-query? (make-parameter #t))
(define debug-db-query-prefix (make-parameter ""))
(define db-credentials (make-parameter #f))
(define ajax-library (make-parameter "//ajax.googleapis.com/ajax/libs/jquery/1.5.1/jquery.min.js"))
(define enable-ajax (make-parameter #f))
(define ajax-namespace (make-parameter "ajax"))
(define enable-session (make-parameter #f))
(define page-access-control (make-parameter (lambda (path) #t)))
(define page-access-denied-message (make-parameter (lambda (path) (<h3> "Access denied."))))
(define page-doctype (make-parameter ""))
(define page-css (make-parameter #f))
(define page-charset (make-parameter #f))
(define login-page-path (make-parameter "/login")) ;; don't forget no-session: #t for this page
(define main-page-path (make-parameter "/"))
(define app-root-path (make-parameter "/"))
(define valid-password? (make-parameter (lambda (user password) #f)))
(define page-template (make-parameter html-page))
(define ajax-invalid-session-message (make-parameter "Invalid session."))
(define web-repl-access-control (make-parameter (lambda () #f)))
(define web-repl-access-denied-message (make-parameter (<h3> "Access denied.")))
(define session-inspector-access-control (make-parameter (lambda () #f)))
(define session-inspector-access-denied-message (make-parameter (<h3> "Access denied.")))
(define enable-javascript-compression (make-parameter #f))
(define javascript-compressor (make-parameter identity))
(define awful-response-headers (make-parameter #f))
(define development-mode? (make-parameter #f))
(define enable-web-repl-fancy-editor (make-parameter #t))
(define web-repl-fancy-editor-base-uri (make-parameter "http://parenteses.org/awful/codemirror"))
(define page-exception-message
  (make-parameter
   (lambda (exn)
     (<h3> "An error has accurred while processing your request."))))
(define debug-resources (make-parameter #f)) ;; usually useful for awful development debugging
(define enable-session-cookie (make-parameter #t))
(define session-cookie-name (make-parameter "awful-cookie"))
(define javascript-position (make-parameter 'top))

;; Parameters for internal use (but exported, since they are internally used by other eggs)
(define http-request-variables (make-parameter #f))
(define db-connection (make-parameter #f))
(define page-javascript (make-parameter ""))
(define sid (make-parameter #f))
(define db-enabled? (make-parameter #f))
(define awful-listen (make-parameter tcp-listen))
(define awful-accept (make-parameter tcp-accept))
(define awful-backlog (make-parameter 10))
(define awful-listener (make-parameter
                        (let ((listener #f))
                          (lambda ()
                            (unless listener
                              (set! listener
                                    ((awful-listen)
                                     (server-port)
                                     (awful-backlog)
                                     (server-bind-address))))
                            listener))))

;; Parameters for internal use and not exported
(define %redirect (make-parameter #f))
(define %web-repl-path (make-parameter #f))
(define %session-inspector-path (make-parameter #f))
(define %error (make-parameter #f))

;; db-support parameters (set by awful-<db> eggs)
(define missing-db-msg "Database access is not enabled (see `enable-db').")
(define db-inquirer (make-parameter (lambda (query) (error '$db missing-db-msg))))
(define db-connect (make-parameter (lambda (credentials) (error 'db-connect missing-db-msg))))
(define db-disconnect (make-parameter (lambda (connection) (error 'db-disconnect missing-db-msg))))
(define sql-quoter (make-parameter (lambda args (error 'sql-quote missing-db-msg))))
(define db-make-row-obj (make-parameter (lambda (q) (error '$db-row-obj missing-db-msg))))


;;; Misc
(define ++ string-append)

(define (concat args #!optional (sep ""))
  (string-intersperse (map ->string args) sep))

(define-syntax with-request-variables
  (syntax-rules ()
    ((_ bindings body ...) (with-request-vars* $ bindings body ...))))

(define (string->symbol* str)
  (if (string? str)
      (string->symbol str)
      str))

(define (load-apps apps)
  (set! *resources* (make-hash-table equal?))
  (for-each load apps)
  (when (development-mode?) (development-mode-actions)))

(define (define-reload-page)
  ;; Define a /reload page for reloading awful apps
  (define-page "/reload"
    (lambda ()
      (load-apps (awful-apps))
      (++ (<p> "The following awful apps have been reloaded on "
               (seconds->string (current-seconds)))
          (itemize (map <code> (awful-apps)))))
    no-ajax: #t
    title: "Awful reloaded applications"))

(define (development-mode-actions)
  (print "Awful is running in development mode.")
  (debug-log (current-error-port))

  ;; Print the call chain, the error message and links to the
  ;; web-repl and session-inspector (if enabled)
  (page-exception-message
   (lambda (exn)
     (++ (<pre> convert-to-entities?: #t
                (with-output-to-string
                  (lambda ()
                    (print-call-chain)
                    (print-error-message exn))))
         (<p> "[" (<a> href: (or (%web-repl-path) "/web-repl") "Web REPL") "]"
              (if (enable-session)
                  (++ " [" (<a> href: (or (%session-inspector-path) "/session-inspector")
                                "Session inspector") "]")
                  "")))))

  ;; If web-repl has not been activated, activate it allowing access
  ;; to the localhost at least (`web-repl-access-control' can be
  ;; used to provide more permissive control)
  (unless (%web-repl-path)
    (let ((old-access-control (web-repl-access-control)))
      (web-repl-access-control
       (lambda ()
         (or (old-access-control)
             (equal? (remote-address) "127.0.0.1")))))
    (enable-web-repl "/web-repl"))

  ;; If session-inspector has not been activated, and if
  ;; `enable-session' is #t, activate it allowing access to the
  ;; localhost at least (`session-inspector-access-control' can be
  ;; used to provide more permissive control)
  (when (and (enable-session) (not (%session-inspector-path)))
    (let ((old-access-control (session-inspector-access-control)))
      (session-inspector-access-control
       (lambda ()
         (or (old-access-control)
             (equal? (remote-address) "127.0.0.1"))))
      (enable-session-inspector "/session-inspector")))

  ;; The reload page
  (define-reload-page))

(define (awful-start #!key dev-mode? port ip-address use-fancy-web-repl? privileged-code)
  (enable-web-repl-fancy-editor use-fancy-web-repl?)
  (when dev-mode? (development-mode? #t))
  ;; `load-apps' also calls `development-mode-actions', so only call
  ;; `development-mode-actions' when `(awful-apps)' is null (in this
  ;; case `load-apps' is not called).
  (when (and dev-mode? (null? (awful-apps)))
    (development-mode-actions))
  (when port (server-port port))
  (when ip-address (server-bind-address ip-address))
  ;; if privileged-code is provided, it is loaded before switching
  ;; user/group
  (when privileged-code (load privileged-code))
  (let ((listener ((awful-listener))))
    (switch-user/group (spiffy-user) (spiffy-group))
    (when (zero? (current-effective-user-id))
      (print "WARNING: awful is running with administrator privileges (not recommended)"))
    ;; load apps
    (load-apps (awful-apps))
    ;; Check for invalid javascript positioning
    (unless (memq (javascript-position) '(top bottom))
      (error 'awful-start
             "Invalid value for `javascript-position'.  Valid ones are: `top' and `bottom'."))
    (register-root-dir-handler)
    (register-dispatcher)
    (accept-loop listener (awful-accept))))

(define (get-sid #!optional force-read-sid)
  (and (or (enable-session) force-read-sid)
       (if (enable-session-cookie)
           (or (read-cookie (session-cookie-name)) ($ 'sid))
           ($ 'sid))))

(define (redirect-to new-uri)
  ;; Just set the `%redirect' internal parameter, so `run-resource' is
  ;; able to know where to redirect.
  (%redirect new-uri))


;;; Javascript
(define (include-javascript . files)
  (string-intersperse
   (map (lambda (file)
          (<script> type: "text/javascript" src: file))
        files)))

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


;;; Session-aware procedures for HTML code generation
(define (link url text . rest)
  (let ((pass-sid? (and (not (enable-session-cookie))
                        (sid)
                        (session-valid? (sid))
                        (not (get-keyword no-session: rest))))
        (arguments (or (get-keyword arguments: rest) '()))
        (separator (or (get-keyword separator: rest) ";&")))
    (apply <a>
           (append
            (list href: (if url
                            (++ url
                                (if (or pass-sid? (not (null? arguments)))
                                    (++ "?"
                                        (form-urlencode
                                         (append arguments
                                                 (if pass-sid?
                                                     `((sid . ,(sid)))
                                                     '()))
                                         separator: separator))
                                    ""))
                            "#"))
            rest
            (list text)))))

(define (form contents . rest)
  (let ((pass-sid? (and (not (enable-session-cookie))
                        (sid)
                        (session-valid? (sid))
                        (not (get-keyword no-session: rest)))))
    (apply <form>
           (append rest
                   (list
                    (++ (if pass-sid?
                            (hidden-input 'sid (sid))
                            "")
                        contents))))))


;;; HTTP request variables access
(define ($ var #!optional default/converter)
  (unless (http-request-variables)
    (http-request-variables (request-vars)))
  ((http-request-variables) var default/converter))


;;; DB access
(define ($db q #!key default values)
  (unless (db-enabled?)
    (error '$db "Database access doesn't seem to be enabled. Did you call `(enable-db)'?"))
  (debug-query q)
  ((db-inquirer) q default: default values: values))

(define (debug-query q)
  (when (and (debug-file) (debug-db-query?))
    (debug (++ (debug-db-query-prefix) q))))

(define ($db-row-obj q)
  (debug-query q)
  ((db-make-row-obj) q))

(define (sql-quote . data)
  ((sql-quoter) data))


;;; Parameters reseting
(define (reset-per-request-parameters) ;; to cope with spiffy's thread reuse
  (http-request-variables #f)
  (awful-response-headers #f)
  (db-connection #f)
  (sid #f)
  (%redirect #f)
  (%error #f))


;;; Request handling hooks
(define *request-handler-hooks* '())

(define (add-request-handler-hook! name proc)
  (set! *request-handler-hooks*
        (cons (cons name proc) *request-handler-hooks*)))

(define (remove-request-handler-hook! name)
  (set! *request-handler-hooks*
        (alist-delete! name *request-handler-hooks*)))

;;; Resources
(root-path (current-directory))

(define *resources* (make-hash-table equal?))

(define (register-dispatcher)
  (handle-not-found
   (let ((old-handler (handle-not-found)))
     (lambda (_)
       (let* ((path-list (uri-path (request-uri (current-request))))
              (dir? (equal? (last path-list) ""))
              (path (if (null? (cdr path-list))
                        (car path-list)
                        (++ "/" (concat (cdr path-list) "/"))))
              (proc (resource-ref path (root-path))))
         (if proc
             (run-resource proc path)
             (if dir? ;; try to find a procedure with the trailing slash removed
                 (let ((proc (resource-ref (string-chomp path "/") (root-path))))
                   (if proc
                       (run-resource proc path)
                       (old-handler _)))
                 (old-handler _))))))))

(define (run-resource proc path)
  (reset-per-request-parameters)
  (let ((handler
         (lambda (path proc)
           (let ((out (->string (proc path))))
             (if (%error)
                 (send-response code: 500
                                reason: "Internal server error"
                                body: ((page-template) ((page-exception-message) (%error)))
                                headers: '((content-type text/html)))
                 (if (%redirect) ;; redirection
                     (let ((new-uri (if (string? (%redirect))
                                        (uri-reference (%redirect))
                                        (%redirect))))
                       (with-headers `((location ,new-uri))
                                     (lambda ()
                                       (%redirect #f)
                                       (send-status 302 "Found"))))
                     (with-headers (append
                                    (or (awful-response-headers)
                                        `((content-type text/html)))
                                    (or (and-let* ((headers (awful-response-headers))
                                                   (content-length (alist-ref 'content-length headers)))
                                          (list (cons 'content-length content-length)))
                                        `((content-length ,(string-length out)))))
                                   (lambda ()
                                     (write-logged-response)
                                     (unless (eq? 'HEAD (request-method (current-request)))
                                       (display out (response-port (current-response))))))))))))
    (call/cc (lambda (continue)
               (for-each (lambda (hook)
                           ((cdr hook) (car hook)
                                       path
                                       (lambda ()
                                         (handler path proc)
                                         (continue #f))))
                         *request-handler-hooks*)
               (handler path proc)))))

(define (resource-ref path vhost-root-path)
  (when (debug-resources)
    (debug-pp (hash-table->alist *resources*)))
  (or (hash-table-ref/default *resources* (cons path vhost-root-path) #f)
      (resource-match path vhost-root-path)))

(define (resource-match path vhost-root-path)
  (let loop ((resources (hash-table->alist *resources*)))
    (if (null? resources)
        #f
        (let* ((current-resource (car resources))
               (current-path (caar current-resource))
               (current-vhost (cdar current-resource))
               (current-proc (cdr current-resource)))
          (if (and (regexp? current-path)
                   (equal? current-vhost vhost-root-path)
                   (string-match current-path path))
              current-proc
              (loop (cdr resources)))))))

(define (add-resource! path vhost-root-path proc)
  (hash-table-set! *resources* (cons path vhost-root-path) proc))


;;; Root dir
(define (register-root-dir-handler)
  (handle-directory
   (let ((old-handler (handle-directory)))
     (lambda (path)
       (cond ((resource-ref path (root-path))
              => (cut run-resource <> path))
             (else (old-handler path)))))))

;;; Pages
(define (undefine-page path #!optional vhost-root-path)
  (hash-table-delete! *resources* (cons path (or vhost-root-path (root-path)))))

(define (include-page-javascript ajax? no-javascript-compression)
  (++ (if ajax?
          (++ (<script> type: "text/javascript"
                        (maybe-compress-javascript
                         (++ "$(document).ready(function(){"
                             (page-javascript) "});")
                         no-javascript-compression)))
          (if (string-null? (page-javascript))
              ""
              (<script> type: "text/javascript"
                        (maybe-compress-javascript
                         (page-javascript)
                         no-javascript-compression))))))

(define (page-path path #!optional namespace)
  (if (regexp? path)
      path
      (string-chomp
       (make-pathname (cons (app-root-path)
                            (if namespace
                                (list namespace)
                                '()))
                      path)
       "/")))

(define (define-page path contents #!key css title doctype headers charset no-ajax
                     no-template no-session no-db vhost-root-path no-javascript-compression
                     use-ajax use-session) ;; for define-session-page
  (##sys#check-closure contents 'define-page)
  (let ((path (page-path path)))
    (add-resource!
     path
     (or vhost-root-path (root-path))
     (lambda (#!optional given-path)
       (sid (get-sid use-session))
       (when (and (db-credentials) (db-enabled?) (not no-db))
         (db-connection ((db-connect) (db-credentials))))
       (page-javascript "")
       (awful-refresh-session!)
       (let ((out
              (if (or (not (enable-session))
                      no-session
                      use-session
                      (and (enable-session) (session-valid? (sid))))
                  (if ((page-access-control) (or given-path path))
                      (begin
                        (when use-session
                          (if (session-valid? (sid))
                              (awful-refresh-session!)
                              (begin
                                (sid (session-create))
                                (set-cookie! (session-cookie-name) (sid)))))
                        (let* ((ajax? (cond (no-ajax #f)
                                            ((not (ajax-library)) #f)
                                            ((and (ajax-library) use-ajax) #t)
                                            ((enable-ajax) #t)
                                            (else #f)))
                               (contents
                                (handle-exceptions
                                    exn
                                  (begin
                                    (%error exn)
                                    (debug (with-output-to-string
                                             (lambda ()
                                               (print-call-chain)
                                               (print-error-message exn))))
                                    ((page-exception-message) exn))
                                  (++ (if (regexp? path)
                                          (contents given-path)
                                          (contents))
                                      (if (eq? (javascript-position) 'bottom)
                                          (include-page-javascript ajax? no-javascript-compression)
                                          "")))))
                          (if (%redirect)
                              #f ;; no need to do anything.  Let `run-resource' perform the redirection
                              (if no-template
                                  contents
                                  ((page-template)
                                   contents
                                   css: (or css (page-css))
                                   title: title
                                   doctype: (or doctype (page-doctype))
                                   headers: (++ (if ajax?
                                                    (<script> type: "text/javascript" src: (ajax-library))
                                                    "")
                                                (or headers "")
                                                (if (eq? (javascript-position) 'top)
                                                    (include-page-javascript ajax? no-javascript-compression)
                                                    ""))
                                   charset: (or charset (page-charset)))))))
                      ((page-template) ((page-access-denied-message) (or given-path path))))
                  ((page-template)
                   ""
                   headers: (<meta> http-equiv: "refresh"
                                    content: (++ "0;url=" (login-page-path)
                                                 "?reason=invalid-session&attempted-path=" (or given-path path)
                                                 "&user=" ($ 'user "")
                                                 (if (and (not (enable-session-cookie)) ($ 'sid))
                                                     (++ "&sid=" ($ 'sid))
                                                     "")))))))
         (when (and (db-connection) (db-enabled?) (not no-db)) ((db-disconnect) (db-connection)))
         out))))
  path)

(define (define-session-page path contents . rest)
  ;; `rest' are same keyword params as for `define-page' (except `no-session', obviously)
  (apply define-page (append (list path contents) (list use-session: #t) rest)))


;;; Ajax
(define (ajax path id event proc #!key (action 'html) (method 'POST) (arguments '())
              target success no-session no-db no-page-javascript vhost-root-path
              live content-type prelude update-targets (cache 'not-set))
  (let ((path (page-path path (ajax-namespace))))
    (add-resource! path
                   (or vhost-root-path (root-path))
                   (lambda (#!optional given-path)
                     (sid (get-sid 'force))
                     (when (and (db-credentials) (db-enabled?) (not no-db))
                       (db-connection ((db-connect) (db-credentials))))
                     (awful-refresh-session!)
                     (if (or (not (enable-session))
                             no-session
                             (and (enable-session) (session-valid? (sid))))
                         (if ((page-access-control) path)
                             (let ((out (if update-targets
                                            (with-output-to-string
                                              (lambda ()
                                                (json-write (list->vector (proc)))))
                                            (proc))))
                               (when (and (db-credentials) (db-enabled?) (not no-db))
                                 ((db-disconnect) (db-connection)))
                               out)
                             ((page-access-denied-message) path))
                         (ajax-invalid-session-message))))
    (let* ((arguments (if (and (sid) (session-valid? (sid)))
                          (cons `(sid . ,(++ "'" (sid) "'")) arguments)
                          arguments))
           (js-code
            (++ (if (and id event)
                    (let ((events (concat (if (list? event) event (list event)) " "))
                          (binder (if live "live" "bind")))
                      (++ "$('" (if (symbol? id)
                                    (conc "#" id)
                                    id)
                          "')." binder "('" events "',"))
                    "")
                (++ "function(){"
                    (or prelude "")
                    "$.ajax({type:'" (->string method) "',"
                    "url:'" path "',"
                    (if content-type
                        (conc "contentType: '" content-type "',")
                        "")
                    "success:function(response){"
                    (or success
                        (cond (update-targets
                               "$.each(response, function(id, html) { $('#' + id).html(html);});")
                              (target
                               (++ "$('#" target "')." (->string action) "(response);"))
                              (else "return;")))
                    "},"
                    (if update-targets
                        "dataType: 'json',"
                        "")
                    (if (eq? cache 'not-set)
                        ""
                        (if cache
                            "cache:true,"
                            "cache:false,"))
                    (++ "data:{"
                        (string-intersperse
                         (map (lambda (var/val)
                                (conc  "'" (car var/val) "':" (cdr var/val)))
                              arguments)
                         ",") "}")
                    "})}")
                (if (and id event)
                    ");\n"
                    ""))))
      (unless no-page-javascript (add-javascript js-code))
      js-code)))

(define (periodical-ajax path interval proc #!key target (action 'html) (method 'POST)
                         (arguments '()) success no-session no-db vhost-root-path live
                         content-type prelude update-targets cache)
  (add-javascript
   (++ "setInterval("
       (ajax path #f #f proc
             target: target
             action: action
             method: method
             arguments: arguments
             success: success
             no-session: no-session
             no-db: no-db
             vhost-root-path: vhost-root-path
             live: live
             content-type: content-type
             prelude: prelude
             update-targets: update-targets
             cache: cache
             no-page-javascript: #t)
       ", " (->string interval) ");\n")))

(define (ajax-link path id text proc #!key target (action 'html) (method 'POST) (arguments '())
                   success no-session no-db (event 'click) vhost-root-path live class
                   hreflang type rel rev charset coords shape accesskey tabindex a-target
                   content-type prelude update-targets cache)
  (ajax path id event proc
        target: target
        action: action
        method: method
        arguments: arguments
        success: success
        no-session: no-session
        vhost-root-path: vhost-root-path
        live: live
        content-type: content-type
        prelude: prelude
        update-targets: update-targets
        cache: cache
        no-db: no-db)
  (<a> href: "#"
       id: id
       class: class
       hreflang: hreflang
       type: type
       rel: rel
       rev: rev
       charset: charset
       coords: coords
       shape: shape
       accesskey: accesskey
       tabindex: tabindex
       target: a-target
       text))


;;; Login form
(define (login-form #!key (user-label "User: ")
                          (password-label "Password: ")
                          (submit-label "Submit")
                          (trampoline-path "/login-trampoline")
                          (refill-user #t))
  (let ((attempted-path ($ 'attempted-path))
        (user ($ 'user)))
    (<form> action: trampoline-path method: "post"
            (if attempted-path
                (hidden-input 'attempted-path attempted-path)
                "")
            (<span> id: "user-container"
                    (<span> id: "user-label" user-label)
                    (<input> type: "text" id: "user" name: "user" value: (and refill-user user)))
            (<span> id: "password-container"
                    (<span> id: "password-label" password-label)
                    (<input> type: "password" id: "password" name: "password"))
            (<input> type: "submit" id: "login-submit" value: submit-label))))


;;; Login trampoline (for redirection)
(define (define-login-trampoline path #!key vhost-root-path hook)
  (define-page path
    (lambda ()
      (let* ((user ($ 'user))
             (password ($ 'password))
             (attempted-path ($ 'attempted-path))
             (password-valid? ((valid-password?) user password))
             (new-sid (and password-valid? (session-create))))
        (sid new-sid)
        (when (enable-session-cookie)
          (set-cookie! (session-cookie-name) new-sid))
        (when hook (hook user))
        (html-page
         ""
         headers: (<meta> http-equiv: "refresh"
                          content: (++ "0;url="
                                       (if new-sid
                                           (++ (or attempted-path (main-page-path))
                                               "?user=" user
                                               (if (enable-session-cookie)
                                                   ""
                                                   (++ "&sid=" new-sid)))
                                           (++ (login-page-path) "?reason=invalid-password&user=" user)))))))
    vhost-root-path: vhost-root-path
    no-session: #t
    no-template: #t))


;;; Web repl
(define (enable-web-repl path #!key css (title "Awful Web REPL") headers)
  (unless (development-mode?) (%web-repl-path path))
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
            (page-javascript
             (++ "$('#clear').click(function(){"
                 (if (enable-web-repl-fancy-editor)
                     "editor.setCode('');"
                     "$('#prompt').val('');")
                 "});"))

            (ajax (++ path "-eval") 'eval 'click web-eval
                  target: "result"
                  arguments: `((code . ,(if (enable-web-repl-fancy-editor)
                                            "editor.getCode()"
                                            "$('#prompt').val()"))))

            (when (enable-web-repl-fancy-editor)
              (ajax (++ path "-eval") 'eval-region 'click web-eval
                    target: "result"
                    arguments: `((code . "editor.selection()"))))

            (++ (<h1> title)
                (<h2> "Input area")
                (let ((prompt (<textarea> id: "prompt" name: "prompt" rows: "10" cols: "90")))
                  (if (enable-web-repl-fancy-editor)
                      (<div> class: "border" prompt)
                      prompt))
                (itemize
                 (map (lambda (item)
                        (<button> id: (car item) (cdr item)))
                      (append '(("eval"  . "Eval"))
                              (if (enable-web-repl-fancy-editor)
                                  '(("eval-region" . "Eval region"))
                                  '())
                              '(("clear" . "Clear"))))
                 list-id: "button-bar")
                (<h2> "Output area")
                (<div> id: "result")
                (if (enable-web-repl-fancy-editor)
                    (<script> type: "text/javascript" "
  function addClass(element, className) {
    if (!editor.win.hasClass(element, className)) {
      element.className = ((element.className.split(' ')).concat([className])).join(' ');}}

  function removeClass(element, className) {
    if (editor.win.hasClass(element, className)) {
      var classes = element.className.split(' ');
      for (var i = classes.length - 1 ; i >= 0; i--) {
        if (classes[i] === className) {
            classes.splice(i, 1)}}
      element.className = classes.join(' ');}}

  var textarea = document.getElementById('prompt');
  var editor = new CodeMirror(CodeMirror.replace(textarea), {
    height: '250px',
    width: '600px',
    content: textarea.value,
    parserfile: ['" (web-repl-fancy-editor-base-uri) "/tokenizescheme.js',
                 '" (web-repl-fancy-editor-base-uri) "/parsescheme.js'],
    stylesheet:  '" (web-repl-fancy-editor-base-uri) "/schemecolors.css',
    autoMatchParens: true,
    path: '" (web-repl-fancy-editor-base-uri) "/',
    disableSpellcheck: true,
    markParen: function(span, good) {addClass(span, good ? 'good-matching-paren' : 'bad-matching-paren');},
    unmarkParen: function(span) {removeClass(span, 'good-matching-paren'); removeClass(span, 'bad-matching-paren');}
  });")
                    "")))
          (web-repl-access-denied-message)))
    headers: (++ (if (enable-web-repl-fancy-editor)
                     (include-javascript (make-pathname (web-repl-fancy-editor-base-uri) "codemirror.js")
                                         (make-pathname (web-repl-fancy-editor-base-uri) "mirrorframe.js"))
                     "")
                 (let ((builtin-css (if css
                                        #f
                                        (<style> type: "text/css"
"h1 { font-size: 18pt; background-color: #898E79; width: 590px; color: white; padding: 5px;}
h2 { font-size: 14pt; background-color: #898E79; width: 590px; color: white; padding: 5px;}
ul#button-bar { margin-left: 0; padding-left: 0; }
#button-bar li {display: inline; list-style-type: none; padding-right: 10px; }"
(if (enable-web-repl-fancy-editor)
    "div.border { border: 1px solid black; width: 600px;}"
    "#prompt { width: 600px; }")
"#result { border: 1px solid #333; padding: 5px; width: 590px; }"))))
                   (if headers
                       (++ (or builtin-css "") headers)
                       builtin-css)))
    use-ajax: #t
    title: title
    css: css))


;;; Session inspector
(define (enable-session-inspector path #!key css (title "Awful session inspector") headers)
  (unless (development-mode?) (%session-inspector-path path))
  (define-page path
    (lambda ()
      (parameterize ((enable-session #t))
        (if ((session-inspector-access-control))
            (let ((bindings (session-bindings (sid))))
              (++ (<h1> title)
                  (if (null? bindings)
                      (<p> "Session for sid " (sid) " is empty")
                      (++ (<p> "Session for " (sid))
                          (tabularize
                           (map (lambda (binding)
                                  (let ((var (car binding))
                                        (val (with-output-to-string
                                               (lambda ()
                                                 (pp (cdr binding))))))
                                    (list (<span> class: "session-inspector-var" var)
                                          (<pre> convert-to-entities?: #t
                                                 class: "session-inspector-value"
                                                 val))))
                                bindings)
                           header: '("Variables" "Values")
                           table-id: "session-inspector-table")))))
            (session-inspector-access-denied-message))))
    headers: (let ((builtin-css (if css
                                    #f
                                    (<style> type: "text/css"
"h1 { font-size: 16pt; background-color: #898E79; width: 590px; color: white; padding: 5px;}
.session-inspector-value { margin: 2px;}
.session-inspector-var { margin: 0px; }
#session-inspector-table { margin: 0px; width: 600px;}
#session-inspector-table tr td, th { padding-left: 10px; border: 1px solid #333; vertical-align: middle; }"))))
               (if headers
                   (++ (or builtin-css "") headers)
                   builtin-css))
    title: title
    css: css))

) ; end module
