;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2020 Konrad Hinsen <konrad.hinsen@fastmail.net>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (guix scripts run-script)
  #:use-module (guix ui)
  #:use-module (guix scripts)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-37)
  #:use-module (ice-9 match)
  #:export (guix-run-script))

;;; Commentary:
;;;
;;; This command allows to run Guile scripts in an environment
;;; that contains all the modules comprising Guix.

(define %default-options
  '())

(define %options
  (list (option '(#\h "help") #f #f
                (lambda args
                  (show-help)
                  (exit 0)))
        (option '(#\V "version") #f #f
                (lambda args
                  (show-version-and-exit "guix run-script")))
        (option '(#\q) #f #f
                (lambda (opt name arg result)
                  (alist-cons 'ignore-dot-guile? #t result)))
        (option '(#\L "load-path") #t #f
                (lambda (opt name arg result)
                  ;; XXX: Imperatively modify the search paths.
                  (set! %load-path (cons arg %load-path))
                  (set! %load-compiled-path (cons arg %load-compiled-path))
                  result))))


(define (show-help)
  (display (G_ "Usage: guix run-script [OPTIONS...] FILE
Run FILE as a Guile script in the Guix execution environment.\n"))
  (display (G_ "
  -q                     inhibit loading of ~/.guile"))
  (newline)
  (display (G_ "
  -L, --load-path=DIR    prepend DIR to the package module search path"))
  (newline)
  (display (G_ "
  -h, --help             display this help and exit"))
  (display (G_ "
  -V, --version          display version information and exit"))
  (newline)
  (show-bug-report-information))

(define user-module
  ;; Module where we execute user code.
  (let ((module (resolve-module '(guix-user) #f #f #:ensure #t)))
    (beautify-user-module! module)
    module))


(define (guix-run-script . args)
  (define opts
    (args-fold* args %options
                (lambda (opt name arg result)
                  (leave (G_ "~A: unrecognized option~%") name))
                (lambda (arg result)
                  (when (assq 'argument result)
                    (leave (G_ "~A: extraneous argument~%") arg))
                  (alist-cons 'argument arg result))
                %default-options))

  (define script
    (or (assq-ref opts 'argument)
        (leave (G_ "no script filename specified~%"))))

  (define user-config
    (and=> (getenv "HOME")
           (lambda (home)
             (string-append home "/.guile"))))

  (with-error-handling
    (save-module-excursion
     (lambda ()
       (set-current-module user-module)
       (when (and (not (assoc-ref opts 'ignore-dot-guile?))
                  user-config
                  (file-exists? user-config))
         (load user-config))
       (load script)))))
