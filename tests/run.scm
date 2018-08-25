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
(test "\n<form method=\"post\" action=\"/\"><input type=\"submit\" /></form>"
      ((sxml->html) (form '(input (@ (type "submit"))) method: 'post action: "/")))
(test-end "form")

(test-begin "link")
(test '(a (@ (href "/foo")) "bar")
      (link "/foo" "bar"))
(test '(a (@ (href "/foo") (id "foo")) "bar")
      (link "/foo" "bar" id: "foo"))
(test-end "link")

(test-end "awful")

(unless (zero? (test-failure-count))
  (print "=====")
  (printf "===== ~a ~a failed!\n"
          (test-failure-count)
          (if (> (test-failure-count) 1) "tests" "test"))
  (print "====="))

(test-exit)
