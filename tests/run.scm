(use server-test test awful spiffy posix)

(test-server-port
 (cond ((get-environment-variable "SPIFFY_TEST_PORT")
        => (lambda (port)
             (string->number port)))
       (else (server-port))))

(server-port (test-server-port))

(with-test-server
 (lambda ()
   (awful-start
    (lambda ()
      (load-apps (list "server.scm")))))
  (lambda ()
    (load "client.scm")))

(test-exit)