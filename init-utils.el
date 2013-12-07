;;; My custom Emacs lisp functions

(require 'cl)

(defun eas-join-dirs (prefix suffix)
  "Joins `prefix` and `suffix` into a directory"
  (file-name-as-directory (concat prefix suffix)))

(defun eas-require-list (items)
  "Takes a list of items to require"
  (interactive)
  (dolist (item items)
    (require `,item nil t)))


(provide 'init-utils)
