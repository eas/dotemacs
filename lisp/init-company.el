(use-package company
  :ensure company
  :config
  (progn
    (bind-key "C-n" 'company-select-next company-active-map)
    (bind-key "C-p" 'company-select-previous company-active-map)
    (global-company-mode)))

(provide 'init-company)
