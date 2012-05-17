(use awful)

(define (ticket-id path)
  (and (string-prefix? "/ticket/" path)
       (and-let* ((tokens (string-split path "/"))
                  (_ (not (null? (cdr tokens))))
                  (id (string->number (cadr tokens))))
         (and id (list id)))))

(define-page ticket-id
  (lambda (id)
    (conc "This is ticket " id)))


(define (ticket-reporter+severity path)
  (and (string-prefix? "/ticket/" path)
       (and-let* ((tokens (string-split path "/"))
                  (_ (> (length tokens) 2)))
         (list (cadr tokens)
               (caddr tokens)))))

(define-page ticket-reporter+severity
  (lambda (reporter severity)
    (sprintf "Reporter=~a, severity=~a"
             reporter
             severity)))
