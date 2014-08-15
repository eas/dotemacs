;; Some usefull libs to ease ELisp coding.
(use-package s
  :ensure s)
(use-package f
  :ensure)
(use-package dash
  :ensure
  :init
  (use-package dash-functional
    :ensure)
  :config
  (dash-enable-font-lock))
(use-package request
  :ensure)

(provide 'init-libs)
