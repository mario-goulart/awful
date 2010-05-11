#!/usr/bin/csi -script
;; -*- scheme -*-

(declare (uses chicken-syntax))
(use posix awful)

(define (usage #!optional exit-code)
  (print (pathname-strip-directory (program-name)) " <app1> [ <app2> ... ]")
  (when exit-code (exit exit-code)))

(awful-apps (command-line-arguments))
(when (null? (awful-apps)) (usage 1))
(load-apps (awful-apps))
(register-root-dir-handler)
(register-dispatcher)
(awful-start)
