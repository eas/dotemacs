(use-package paredit
  :ensure paredit
  :config
  (progn
    ;; Enable `paredit-mode' in the minibuffer, during `eval-expression'.
    (defun conditionally-enable-paredit-mode ()
      (if (eq this-command 'eval-expression)
          (paredit-mode 1)))

    (add-hook 'minibuffer-setup-hook 'conditionally-enable-paredit-mode)))

(provide 'init-paredit)
