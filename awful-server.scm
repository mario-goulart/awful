;; Copyright (c) 2010-2013, Mario Domenech Goulart
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

(declare (uses chicken-syntax))
(use posix awful srfi-1 srfi-13)

(define (usage #!optional exit-code)
  (let ((awful (pathname-strip-directory (program-name))))
    (print awful " [ -h | --help ]")
    (print awful " [ -v | --version ]")
    (print awful " [ --development-mode ] "
           "[ --privileged-code=<code to be run with admin privileges> ]"
           "[ --disable-web-repl-fancy-editor ] "
           "[ --ip-address=<ip address> ] "
           "[ --port=<port number> ] "
           "[ <app1> <app2> ... ]")
  (when exit-code (exit exit-code))))

(define (cmd-line-arg option args)
  ;; Returns the argument associated to the command line option OPTION
  ;; in ARGS or #f if OPTION is not found in ARGS or doesn't have any
  ;; argument.
  (let ((val (any (cut irregex-match (conc option "=(.*)") <>) args)))
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
        (privileged-code (cmd-line-arg '--privileged-code args))
        (args (remove (lambda (arg)
                        (or (member arg '("--development-mode" "--disable-web-repl-fancy-editor"))
                            (string-prefix? "--port=" arg)
                            (string-prefix? "--privileged-code=" arg)
                            (string-prefix? "--ip-address=" arg)))
                      args)))
    (awful-apps args)
    (awful-start
     (lambda ()
       (load-apps args))
     privileged-code: (and privileged-code
                           (lambda () (load privileged-code)))
     dev-mode?: dev-mode?
     port: (and port (string->number port))
     bind-address: ip-address
     use-fancy-web-repl?: use-fancy-web-repl?)))
