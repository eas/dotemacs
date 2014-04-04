(use-package fill-column-indicator
  :ensure fill-column-indicator
  :config
  (progn
    (setq fci-rule-color "darkblue")
    (setq-default fill-column 80)
    (define-globalized-minor-mode global-fci-mode fci-mode (lambda () (fci-mode 1)))
    (global-fci-mode -1)))

(provide 'init-fci)
