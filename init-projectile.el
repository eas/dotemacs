(use-package projectile
  :ensure projectile
  :idle
  :config
  (progn
   (projectile-global-mode)
   (setq projectile-enable-caching t)
   (evil-leader/set-key
     "hp" 'helm-projectile)))

(provide 'init-projectile)
