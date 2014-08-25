(require 'use-package)

(use-package ido
  :init
  (progn
    (ido-mode t)
    (evil-leader/set-key
      "f" 'ido-find-file
      "F" 'ido-find-file-other-window
      "b" 'ido-switch-buffer
      "B" 'ido-switch-buffer-other-window))

  :commands (ido-find-file
             ido-find-file-other-window
             ido-switch-buffer
             ido-switch-buffer-other-window)
  :config
  (progn
    (setq ido-save-directory-list-file (concat my-tmp-local-dir "ido.last"))
    (setq ido-enable-flex-matching t)
    (setq ido-use-filename-at-point 'guess)
    (setq ido-show-dot-for-dired t)))

(use-package smex
      :init
      :bind (("M-x" . smex)
             ("M-X" . smex-major-mode-commands))
      :config
      (progn
        (smex-initialize)
        (evil-leader/set-key
          "x" 'smex))
      :ensure smex)

;; TODO: commands? Or move to ido's config section?
(use-package ido-vertical-mode
      :init (ido-vertical-mode t)
      :ensure ido-vertical-mode)

(provide 'init-ido)
