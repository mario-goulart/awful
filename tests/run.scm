(use server-test test awful spiffy posix)

(test-server-port
 (cond ((get-environment-variable "SPIFFY_TEST_PORT")
        => (lambda (port)
             (string->number port)))
       (else (server-port))))

(server-port (test-server-port))

(test-begin "awful")

(with-test-server
 (lambda ()
   (awful-start
    (lambda ()
      (load-apps (list "server.scm")))))
  (lambda ()
    (load "client.scm")))

(test-begin "form")
(parameterize ((enable-sxml #t))
  (test "\n<form method=\"post\" action=\"/\"><input type=\"submit\" /></form>"
        ((sxml->html) (form '(input (@ (type "submit"))) method: 'post action: "/"))))
(test-end "form")

(test-begin "link")
(parameterize ((enable-sxml #t))
  (test '(a (@ (href "/foo")) "bar")
        (link "/foo" "bar")))
(test-end "link")

(test-end "awful")

(test-exit)
