(use awful srfi-1 regex)

;; Using regex egg
(define-page (regexp "/add/.*")
  (lambda (path)
    (let ((numbers (filter-map string->number (string-split path "/"))))
      (->string (apply + numbers)))))

;; Using irregex unit
(define-page (irregex "/mult/.*")
  (lambda (path)
    (let ((numbers (filter-map string->number (string-split path "/"))))
      (->string (apply * numbers)))))

