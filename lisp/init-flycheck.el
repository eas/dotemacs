(use-package flycheck
  :ensure
  :init
  (progn
    (setq-default flycheck-disabled-checkers '(emacs-lisp-checkdoc))
    (global-flycheck-mode t)
    (use-package flycheck-cask
      :ensure
      :init (add-hook 'flycheck-mode-hook #'flycheck-cask-setup))))
(provide 'init-flycheck)
