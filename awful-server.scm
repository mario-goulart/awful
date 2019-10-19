;; Copyright (c) 2010-2018, Mario Domenech Goulart
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

(module awful-server ()

(import scheme)
(cond-expand
  (chicken-4
   (import chicken)
   (declare (uses chicken-syntax))
   (use data-structures files irregex posix srfi-1 srfi-13)
   (use awful))
  (chicken-5
   (import (chicken base)
           (chicken irregex)
           (chicken pathname)
           (chicken process-context)
           (chicken string))
   (import awful srfi-1 srfi-13))
  (else
   (error "Unsupported CHICKEN version.")))

(define (usage #!optional exit-code)
  (let ((awful (pathname-strip-directory (program-name)))
        (port (if (and exit-code (not (zero? exit-code)))
                  (current-error-port)
                  (current-output-port))))
    (display #<#EOF
Usage:
  #awful [ -h | --help ]
  #awful [ -v | --version ]
  #awful [ <options> ] [ <app1> [ <app2> ... ] ]

<options>:

--development-mode
  Run awful in development mode.  When in development mode, the
  web-repl, the session inspector and a special path for reload
  applications are automatically activated.  They get bound to /web-repl,
  /session-inspector and /reload, respectively, and access to them is only
  permited from the local host.  In this mode, error messages and call
  chains are printed to the client.  Running awful with --development-mode
  is not recommended for applications in production.

--privileged-code=<file1>[,<file2> ...]
  Files with code to be run with administrator privileges (e.g., setting
  port < 1024).

--disable-web-repl-fancy-editor
  By default, the web-repl uses the "fancy" editor (Codemirror), with
  JavaScript to perform code highlight and other useful editor features.
  This option disables the "fancy" editor -- the web-repl will then
  provide a simple textarea for editing code.

--ip-address=<ip address>
  Bind the web server to the given IP address.

--port=<port number>
  Make the web server listen to the given port number.

EOF
    port)
    (when exit-code (exit exit-code))))

(define (cmd-line-arg option args)
  ;; Returns the argument associated to the command line option OPTION
  ;; in ARGS or #f if OPTION is not found in ARGS or doesn't have any
  ;; argument.
  (let ((val (any (lambda (arg)
                    (irregex-match
                     `(seq ,(->string option) "=" (submatch (* any)))
                     arg))
                  args)))
    (and val (irregex-match-substring val 1))))

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
                           (lambda ()
                             (for-each (lambda (file)
                                         (load file))
                                       (string-split privileged-code ","))))
     dev-mode?: dev-mode?
     port: (and port (string->number port))
     ip-address: ip-address
     use-fancy-web-repl?: use-fancy-web-repl?)))

) ;; end of module
