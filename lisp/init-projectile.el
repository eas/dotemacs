(use-package projectile
  :ensure
  :idle
  :config
  (progn
   (setq projectile-enable-caching t)
   (evil-leader/set-key
     "hp" 'helm-projectile)
   (use-package helm-projectile
     :ensure)))

(provide 'init-projectile)
