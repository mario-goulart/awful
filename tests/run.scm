(use server-test test awful posix)

(awful-apps (list "server.scm"))

(with-test-server awful-start
  (lambda ()
    (load "client.scm")))
