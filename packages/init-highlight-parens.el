(use-package highlight-parentheses
  :ensure highlight-parentheses
  :config
  (progn
    (define-globalized-minor-mode global-highlight-parentheses-mode
      highlight-parentheses-mode
      (lambda ()
        (highlight-parentheses-mode t)))
    (global-highlight-parentheses-mode t)))
(provide 'init-highlight-parens)
