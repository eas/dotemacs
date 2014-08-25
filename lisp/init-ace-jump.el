(require 'use-package)

(use-package ace-jump-mode
  :ensure ace-jump-mode
  :commands ace-jump-mode
  :init
  (evil-leader/set-key
    "g" 'ace-jump-mode))

(provide 'init-ace-jump)
