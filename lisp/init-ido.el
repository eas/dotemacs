(use-package ido
  :init
  (progn
    (ido-mode t)
    (use-package smex
      :config (smex-initialize)
      :bind (("M-x" . smex)
             ("M-X" . smex-major-mode-commands))
      :ensure smex)
    (use-package ido-vertical-mode
      :init (ido-vertical-mode t)
      :ensure ido-vertical-mode))
  :config
  (progn
    (setq ido-save-directory-list-file (concat my-tmp-local-dir "ido.last"))
    (setq ido-enable-flex-matching t)
    (setq ido-use-filename-at-point 'guess)
    (setq ido-show-dot-for-dired t)))

(provide 'init-ido)
