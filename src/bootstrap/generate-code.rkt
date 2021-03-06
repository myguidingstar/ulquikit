;;
;; This file is part of Ulquikit project.
;;
;; Copyright (C) 2014 Duong H. Nguyen <cmpitg AT gmailDOTcom>
;;
;; Ulquikit is free software: you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free
;; Software Foundation, either version 3 of the License, or (at your option)
;; any later version.
;;
;; Ulquikit is distributed in the hope that it will be useful, but WITHOUT ANY
;; WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;; FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
;; details.
;;
;; You should have received a copy of the GNU General Public License along with
;; Ulquikit.  If not, see <http://www.gnu.org/licenses/>.
;;

;;;
;;; Generate source code for Ulquikit from snippets residing at ./src/
;;;

#lang rackjure

(require racket/pretty)
(require srfi/1)
(require "utils-file.rkt")
(require "utils-path.rkt")
(require "utils-html.rkt")
(require "utils-alist.rkt")

(provide (all-defined-out))

(current-curly-dict hash)

(define +code-snippet-regexp+     #rx"^( *)--> ([a-zA-Z0-9_/.-]+) <-- *$")
(define +file-snippet-regexp+     #rx"^( *)___ ([a-zA-Z0-9_/.-]+) ___ *$")
(define +end-of-snippet-regexp+   #rx"^ *``` *$")
(define +include-regexp+          #rx"^( *)-{ +([a-zA-Z0-9_/.-]+) +}- *$")
(define +include-regexp-for-text+ #rx"-{ +[a-zA-Z0-9_/.-]+ +}-")

(define +comment-syntax+          ";;")

(module+ test
  (require rackunit))

;;
;; Extract code snippet from a literate document in +docs-location+ and merge
;; it into a hash.  Return the merged hash.
;;
;; Each snippet is a hash with the following keys:
;; * `type`: type of snippet, either `code` or `file`
;; * `content`: content of the snippet
;; * `literate-path`: full path to the literate source file that defines the
;;   snippet
;; * `line-number`: the line number at which the snippet is defined in
;;   `literate-path`
;;
(define (extract-code-snippet-from-file filename snippets-hash)
  (local [(define doc-content (read-file filename))

          (define (extract-snippet snippet-regexp
                                   #:line line
                                   #:line-number line-number
                                   #:type type)
            (let* ([matches       (regexp-match snippet-regexp line)]
                   [indent-length (string-length (list-ref matches 1))]
                   [snippet-name  (list-ref matches 2)])

              ;; Add snippet to the hash of snippets
              (hash-ref! snippets-hash
                         snippet-name
                         {'type           type
                          'content        #f
                          'literate-path  filename
                          'line-number    line-number})

              ;; Return new snippet info
              {'current-snippet-name snippet-name
               'inside-snippet       #t
               'indent-length        indent-length}))

          (define (close-snippet)
            {'inside-snippet       #f
             'current-snippet-name ""
             'indent-length        0})

          (define (update-current-snippet snippet-info
                                          #:line line)
            (let* ([snippet-name  (snippet-info 'current-snippet-name)]
                   [indent-length (snippet-info 'indent-length)]
                   [code-line     (if (>= (string-length line) indent-length)
                                      (substring line indent-length)
                                      line)])
              (hash-update! snippets-hash
                            snippet-name
                            (λ (snippet)
                              (let* ([current-content (snippet 'content)]
                                     [new-content (if current-content
                                                      (str current-content
                                                           "\n"
                                                           code-line)
                                                      code-line)])
                                (snippet 'content new-content))))))]

    (~>> (string-split doc-content "\n")
      (foldl (λ (line snippet-info)
               (let ([old-line-number (snippet-info 'line-number)]
                     [snippet-info
                      (cond [ ;; Begining of code snippet
                             (regexp-match? +code-snippet-regexp+ line)
                             (extract-snippet +code-snippet-regexp+
                                              #:line line
                                              #:line-number (snippet-info 'line-number)
                                              #:type 'code)]

                            [ ;; Begining of file snippet
                             (regexp-match? +file-snippet-regexp+ line)
                             (extract-snippet +file-snippet-regexp+
                                              #:line line
                                              #:line-number (snippet-info 'line-number)
                                              #:type 'file)]

                            [ ;; End of snippet
                             (regexp-match? +end-of-snippet-regexp+ line)
                             (close-snippet)]

                            [else
                             (when (hash-ref snippet-info 'inside-snippet)
                               (update-current-snippet snippet-info
                                                       #:line line))
                             snippet-info])])
                 (snippet-info 'line-number (add1 old-line-number))))
             {'line-number          0   ; Should be counted from 1, as we when
                                        ; we generate reference back to
                                        ; literate doc, the Markdown code
                                        ; block fence should be counted.  The
                                        ; beginning of the code block is the
                                        ; previous line of the line containing
                                        ; snippet name
              'inside-snippet       #f
              'current-snippet-name ""
              'indent-length        0})))
  snippets-hash)

;;
;; Determine if a snippet is a file snippet.
;;
(define (is-file-snippet? snippet)
  (eq? 'file (snippet 'type)))

;;
;; This functions takes the hash that contains all snippets, include all code
;; snippet into their appropriate places in file snippets, and return the hash
;; of file snippets afterward.
;;
(define (include-code-snippets snippets-hash)
  (local [(define (indent-code code indentation)
            (string-join (~>> (string-split code "\n")
                           (map (λ (line) (str indentation line))))
                         "\n"))

          (define (get-snippet-indentation line)
            (let* ([matches       (regexp-match +include-regexp+ line)]
                   [indentation   (if matches
                                      (list-ref matches 1)
                                      "")])
              indentation))

          (define (get-included-snippet-name text)
            (if (contains-include-instruction? text)
                (list-ref (regexp-match +include-regexp+ text) 2)
                ""))

          (define (replace-line-with-snippet line)
            (let* ([indentation   (get-snippet-indentation line)]
                   [snippet-name  (get-included-snippet-name line)])
              ;; (displayln (~a "-> Replacing " line))
              (indent-code (if (snippets-hash snippet-name)
                               ((snippets-hash snippet-name) 'content)
                               "{{ No snippet defined }}")
                           indentation)))

          (define (get-ref-to-literate-doc #:generated-code-path generated-code-path
                                           #:literate-path       literate-path
                                           #:line-number         line-number
                                           #:indentation         indentation)
            (str indentation
                 +comment-syntax+
                 " "
                 (~> (find-relative-path (expand-path generated-code-path)
                                         (expand-path literate-path))
                     path->string
                     (str ":" line-number "\n"))))

          (define (contains-include-instruction? text)
            (or (regexp-match? +include-regexp-for-text+ text)
                (regexp-match? +include-regexp+ text)))

          (define (process-line line
                                #:generated-code-path generated-code-path)
            (if (contains-include-instruction? line)
                (let* ([new-line                 (replace-line-with-snippet line)]
                       [indentation              (get-snippet-indentation line)]
                       [included-snippet-name    (get-included-snippet-name line)]
                       [included-snippet         (snippets-hash included-snippet-name)]

                       [literate-doc-line-number (included-snippet 'line-number)]
                       [literate-path            (included-snippet 'literate-path)])
                  (str (get-ref-to-literate-doc
                        #:generated-code-path generated-code-path
                        #:literate-path       literate-path
                        #:line-number         literate-doc-line-number
                        #:indentation         indentation)
                       new-line))
                line))

          ;;
          ;; Find all lines that match +include-regexp+ and replace them with
          ;; the appropriate snippet.
          ;;
          ;; If the result snippet content still contains other include
          ;; instructions, process with recursion.
          ;;
          ;; This function returns the content of the snippet after all
          ;; replacements.
          ;;
          ;; `current-file` is used to calculate the relative path of the
          ;; generated code that would refer back to its literate doc.
          ;;
          ;; Note that one-line snippets are not supported, so a line that has
          ;; multiple include instructions is not supported.
          ;;
          (define (process-snippet-content content
                                           #:generated-code-path generated-code-path)
            (let* ([lines (string-split content "\n")]
                   [content
                    (~> (map (λ (line)
                               (let ([processed-line
                                      (process-line line
                                                    #:generated-code-path generated-code-path)])
                                 (if (contains-include-instruction? processed-line)
                                     (process-snippet-content processed-line
                                                              #:generated-code-path generated-code-path)
                                     processed-line)))
                             lines)
                      (string-join "\n"))])
              content))

          (define (get-directory generated-code-path)
            (let-values ([(dir _ __) (split-path generated-code-path)])
              (path->string dir)))]

    (~>> (hash-map snippets-hash (λ (snippet-name snippet)
                                   (cons snippet-name snippet)))
      (filter (λ (snippet-and-name)
                (eq? 'file ((cdr snippet-and-name) 'type))))
      (map (λ (snippet-and-name)
             (let* ([snippet-name        (car snippet-and-name)]
                    [snippet             (cdr snippet-and-name)]
                    [generated-code-path (get-directory (expand-path
                                                         (get-output-src-path snippet-name)))]
                    [content             (snippet 'content)]
                    [new-content         (if (contains-include-instruction? content)
                                             (process-snippet-content
                                              content
                                              #:generated-code-path generated-code-path)
                                             content)])
               (cons snippet-name (snippet 'content new-content))))))))

;;
;; Create file from file snippets.  `snippets` is an alist of the following
;; format: `(snippet-name . snippet)`, where `snippet` is a hash which has the
;; following keys:
;;
;; * `'type`: `file`, there isn't code snippet anymore, not used in this
;;   function
;; * `literate-path`: path to its literate doc, not used in this function
;; * `line-number`: its line number in the literate doc, not used in this
;;   function
;; * `content`: its content
;;
;; As stated in the explanation, we only care about its `'content` value.
;;
;; This function reads all file snippets and creates their appropriate files
;; in `./generated-src/`directory
;;
(define (create-files snippets)
  (make-directory* +generated-src-location+)

  (map (λ (snippet)
         (let ([file-path (get-output-src-path (car snippet))]
               [content   ((cdr snippet) 'content)])
           (displayln (~a "-> Generating " file-path))
           (call-with-output-file file-path
             (λ (out)
               (displayln content out))
             #:mode 'text
             #:exists 'truncate)))
       snippets))

(define (generate-code)
  (~>> (list-doc-filenames)
    (map (λ (filename) (get-doc-path filename)))
    (foldl extract-code-snippet-from-file (make-hash))
    include-code-snippets
    create-files))

(define (main)
  (void (generate-code)))
