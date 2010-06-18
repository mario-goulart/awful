#!/usr/bin/awful

(use awful html-tags)

(enable-ajax #t)

(define-page (main-page-path)
  (lambda ()

    (ajax "foo" 'foo 'click
          (lambda ()
            '((a . 1) (b . 2) (c . 3)))
          update-targets: '(a b c))

    (<div>
     (link "#" "foo" id: "foo")
     (<div> id: "a")
     (<div> id: "b")
     (<div> id: "c"))))
