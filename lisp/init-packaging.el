;; Packaging configuration

;; Packages I always want
(defvar my-package-list
  '(use-package
    fuzzy-match
    fuzzy
    el-swank-fuzzy)
  "Packages from ELPA I always want to install.")

(eval-after-load 'package
  '(progn
     (add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/") t)
     (when (< emacs-major-version 24)
       (add-to-list 'package-archives '("gnu" . "http://elpa.gnu.org/packages/")))
     (ignore-errors (require 'local-packaging))
     (package-initialize)

     (defun essential-packages-installed-p (to-install)
       "Checks whether all my essential packages are installed."
       (loop for p in to-install
             when (not (package-installed-p p)) do (return nil)
             finally (return t)))

     (defun install-essential-packages (to-install)
       "Auto-installs all my packages"
       (unless (essential-packages-installed-p to-install)
         (message "%s" "Installing essential packages...")
         (package-refresh-contents)
         (dolist (p to-install)
           (unless (package-installed-p p)
             (package-install p)))
         (delete-other-windows)))

     (install-essential-packages my-package-list)))

(require 'package nil t)
(provide 'init-packaging)
