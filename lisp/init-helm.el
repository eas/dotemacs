(use-package helm
  :ensure helm
  :init
  (progn
    (use-package helm-descbinds
      :ensure helm-descbinds
      :init
      (helm-descbinds-mode))
    (use-package helm-swoop
      :ensure helm-swoop))
  :config
  (evil-leader/set-key
    "hl" 'helm-locate
    "he" 'helm-elscreen
    "hf" 'helm-find-files
    "hF" 'helm-complete-file-name-at-point
    "hh" 'helm-mini
    "hi" 'helm-semantic-or-imenu
    "hg" 'helm-do-grep
    "ho" 'helm-swoop
    "hs" 'helm-swoop
    "ha" 'helm-apropos
    "hy" 'helm-show-kill-ring))
(provide 'init-helm)
