;; Only strip trailing whitespace on lines I edited.
(use-package ws-butler
  :ensure ws-butler
  :init
  (progn
    (ws-butler-global-mode)
    (setq ws-butler-keep-whitespace-before-point nil)))

(provide 'init-ws-butler)
