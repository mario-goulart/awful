#!/usr/bin/csi -script

(use test http-client posix setup-api)

(define (get path/vars)
  (let ((val (with-input-from-request
              (string-append "http://localhost:8080" path/vars)
              #f read-string)))
    (close-all-connections!)
    val))


;;; cleanup
(if (and (file-exists? "a") (not (directory? "a")))
    (delete-file* "a")
    (remove-directory "a" #f))

(test-begin "awful")

;; When a procedure is bound to a path and the path does not exist,
;; just execute the procedure
(test "a" (get "/a"))
(test "a" (get "/a/"))

;; When a procedure is bound to a path and the path exists and is a
;; directory, but does not contain an index-file, executed the
;; procedure bound to the path
(create-directory "a")
(test "a" (get "/a"))
(test "a" (get "/a/"))

;; When a procedure is bound to a path and the path exists, is a
;; directory and contains an index-file, the response is the file
;; contents
(with-output-to-file (make-pathname "a" "index.html") (cut display "index"))
(test "index" (get "/a"))
(test "index" (get "/a/"))

(remove-directory "a")

;; When a procedure is bound to a path and the path exists and is a
;; file, if the request is either for for <path> or <path>/, the
;; response is the file contents
(with-output-to-file "a" (cut display "file"))
(test "file" (get "/a"))
(test "file" (get "/a/"))

(delete-file* "a")

;; Redirections
(test "bar" (get "/foo"))
(test "D" (get "/ra"))

(test-end "awful")
