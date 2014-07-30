(use-package auto-complete
  :ensure auto-complete
  :config
  (progn
    (require 'auto-complete-config)
    (global-auto-complete-mode t)
    ;; (set-default 'ac-sources
    ;;              '(ac-source-imenu
    ;;                ac-source-dictionary
    ;;                ac-source-words-in-buffer
    ;;                ac-source-words-in-same-mode-buffers
    ;;                ac-source-words-in-all-buffer))
    (dolist (mode '(magit-log-edit-mode
                    log-edit-mode org-mode text-mode haml-mode
                    git-commit-mode
                    sass-mode yaml-mode csv-mode espresso-mode haskell-mode
                    html-mode nxml-mode sh-mode smarty-mode clojure-mode
                    lisp-mode textile-mode markdown-mode tuareg-mode
                    js3-mode css-mode less-css-mode sql-mode
                    sql-interactive-mode
                    inferior-emacs-lisp-mode))
      (add-to-list 'ac-modes mode))
    ;; Exclude very large buffers from dabbrev
    (defun my-dabbrev-friend-buffer (other-buffer)
      (< (buffer-size other-buffer) (* 1 1024 1024)))
    (setq dabbrev-friend-buffer-function 'my-dabbrev-friend-buffer)))


(provide 'init-auto-complete)
