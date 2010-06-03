#!/usr/bin/csi -script
;; -*- scheme -*-

(declare (uses chicken-syntax))
(use posix awful)

(define (usage #!optional exit-code)
  (print (pathname-strip-directory (program-name))
         " [ -h | --help ] | [ <app1> <app2> ... ]")
  (when exit-code (exit exit-code)))

(let ((args (command-line-arguments)))
  (when (or (member "-h" args)
            (member "--help" args))
    (usage 0))
  (awful-apps args)
  (load-apps (awful-apps))
  (register-root-dir-handler)
  (register-dispatcher)
  (awful-start))
