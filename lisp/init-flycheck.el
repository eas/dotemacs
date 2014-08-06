(use-package flycheck
  :ensure flycheck
  :init
  (progn
    (setq-default flycheck-disabled-checkers '(emacs-lisp-checkdoc))
    (global-flycheck-mode t)))
(provide 'init-flycheck)
