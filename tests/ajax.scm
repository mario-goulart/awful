#!/usr/bin/csi -script

(use posix awful html-tags)

(enable-ajax #t)

(define-page (main-page-path)
  (lambda ()
    (ajax "/click" 'clickme '(click dblclick)
          (lambda () (->string (current-seconds)))
          target: "clicked")
    (++ (<a> href: "#" id: "clickme" "Click me")
        (<div> id: "clicked"))))
