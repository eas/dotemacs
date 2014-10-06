(use-package color-identifiers-mode
  :ensure t
  :init
  (progn
    (add-hook 'emacs-lisp-mode-hook 'color-identifiers-mode)))

(provide 'init-color-identifiers)
