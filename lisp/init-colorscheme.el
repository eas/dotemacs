(use-package zenburn-theme
  :ensure)

(load-theme 'zenburn t)
(when (facep 'hl-line)
  (set-face-background 'hl-line "#808080"))
(provide 'init-colorscheme)
