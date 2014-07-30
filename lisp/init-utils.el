;;; My custom Emacs lisp functions

;; TODO eval-when-compile?
(require 'cl)

(defun my-join-dirs (prefix suffix)
  "Joins `prefix` and `suffix` into a directory"
  (file-name-as-directory (concat prefix suffix)))

(defun my-require-list (items)
  "Takes a list of items to require"
  (interactive)
  (dolist (item items)
    (require `,item nil t)))

(defmacro my-with-face (str &rest properties)
  `(propertize ,str 'face (list ,@properties)))


(provide 'init-utils)
