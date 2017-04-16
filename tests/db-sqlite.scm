(use awful awful-sqlite3 sqlite3)

(define db-file "sqlite-test.db")

(db-credentials db-file)
(enable-db)

(when (file-exists? db-file)
  (delete-file db-file))

(let* ((conn (open-database (db-credentials)))
       (query (lambda (q) (map-row (lambda args args) conn q))))
  (query "create table users (name varchar(50), address varchar(50) );")
  (query "insert into users (name, address) values ('mario', 'here')")
  (finalize! conn))

(define-page (main-page-path)
  (lambda ()
    `(table
      ,@(map (lambda (row)
               `(tr ,@(map (lambda (i)
                             `(td ,i))
                           row)))
             ($db "select * from users")))))
