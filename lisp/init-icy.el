(use-package icicles
  :ensure icicles
  :init
  (progn (icy-mode t))
  :config
  (progn
    (setq
     icicle-files-ido-like-flag t
     icicle-buffers-ido-like-flag t)))
(provide 'init-icy)
