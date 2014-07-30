(use-package haskell-mode
  :ensure haskell-mode
  :config
  (progn
    (use-package flycheck-haskell
      :ensure flycheck-haskell)
    (add-hook 'haskell-mode-hook 'turn-on-haskell-decl-scan)
    (add-hook 'haskell-mode-hook 'turn-on-haskell-doc-mode)
    (add-hook 'haskell-mode-hook 'turn-on-haskell-indentation)
    (add-hook 'haskell-mode-hook 'interactive-haskell-mode)
    (set 'haskell-font-lock-symbols nil)))

(provide 'init-haskell)
