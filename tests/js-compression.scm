#!/usr/bin/csi -script

(use posix html-tags jsmin)

(enable-ajax #t)
(enable-javascript-compression #t)

(javascript-compressor jsmin-string)

(define-page (main-page-path)
  (lambda ()
    (add-javascript "/* Here's some javascript comment that should "
                    "be stripped from the page. */")
    (ajax "/click" 'clickme '(click dblclick)
          (lambda () (->string (current-seconds)))
          target: "clicked")
    (++ (<a> href: "#" id: "clickme" "Click me")
        (<div> id: "clicked"))))
