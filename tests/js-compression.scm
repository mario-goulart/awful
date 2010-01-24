#!/usr/bin/csi -script

(require-extension posix html-tags)

(enable-ajax #t)
(enable-javascript-compression #f)

(define-page (main-page-path)
  (lambda ()
    (add-javascript "/* Here's some javascript comment that should "
                    "be stripped from the page. */")
    (ajax "/click" 'clickme '(click dblclick)
          (lambda () (->string (current-seconds)))
          target: "clicked")
    (++ (<a> href: "#" id: "clickme" "Click me")
        (<div> id: "clicked"))))
