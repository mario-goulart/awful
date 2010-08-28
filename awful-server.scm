#!/usr/bin/csi -script
;; -*- scheme -*-

(declare (uses chicken-syntax))
(use regex posix awful srfi-1 srfi-13)

(define (usage #!optional exit-code)
  (let ((awful (pathname-strip-directory (program-name))))
    (print awful " [ -h | --help ]")
    (print awful " [ -v | --version ]")
    (print awful " [ --development-mode ] "
           "[ --disable-web-repl-fancy-editor ] "
           "[ --ip-address=<ip address> ] "
           "[ --port=<port number> ] "
           "[ <app1> <app2> ... ]")
  (when exit-code (exit exit-code))))

(define (cmd-line-arg option args)
  ;; Returns the argument associated to the command line option OPTION
  ;; in ARGS or #f if OPTION is not found in ARGS or doesn't have any
  ;; argument.
  (let ((val (any (cut string-match (conc option "=(.*)") <>) args)))
    (and val (cadr val))))

(let ((args (command-line-arguments)))
  (when (or (member "-h" args)
            (member "--help" args))
    (usage 0))
  (when (or (member "-v" args)
            (member "--version" args))
    (print (awful-version))
    (exit 0))
  (let ((dev-mode? (member "--development-mode" args))
        (port (cmd-line-arg '--port args))
        (use-fancy-web-repl? (not (member "--disable-web-repl-fancy-editor" args)))
        (ip-address (cmd-line-arg '--ip-address args))
        (args (remove (lambda (arg)
                        (or (member arg '("--development-mode" "--disable-web-repl-fancy-editor"))
                            (string-prefix? "--port=" arg)
                            (string-prefix? "--ip-address=" arg)))
                      args)))
    (awful-apps args)
    (load-apps (awful-apps))
    (register-root-dir-handler)
    (register-dispatcher)
    (awful-start dev-mode?: dev-mode?
                 port: (and port (string->number port))
                 bind-address: ip-address
                 use-fancy-web-repl?: use-fancy-web-repl?)))
