(use-package helm
  :ensure helm
  :init
  (use-package helm-swoop)
  :config
  (evil-leader/set-key
    "hl" 'helm-locate
    "he" 'helm-elscreen
    "hf" 'helm-find-files
    "hF" 'helm-complete-file-name-at-point
    "hh" 'helm-mini
    "hg" 'helm-do-grep
    "ho" 'helm-swoop
    "hs" 'helm-swoop))
(provide 'init-helm)
