(use-package helm
  :ensure helm
  :init
  (use-package helm-swoop)
  :config
  (evil-leader/set-key
    "hl" 'helm-locate
    "he" 'helm-elscreen
    "hf" 'helm-find
    "hF" 'helm-complete-file-name-at-point
    "hg" 'helm-do-grep
    "ho" 'helm-swoop
    "hs" 'helm-swoop))
(provide 'init-helm)
