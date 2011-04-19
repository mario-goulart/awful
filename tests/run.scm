(use server-test test awful posix)

(awful-apps (list "server.scm"))

(define awful-pid (start-test-server awful-start))

(load "client.scm")

(stop-test-server awful-pid)
