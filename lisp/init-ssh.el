(require 'use-package)
(require 'advice)

(use-package dirtrack)
(use-package ssh
  :ensure
  :commands (ssh)
  ;; TODO: http://enthusiasm.cozy.org/archives/2005/08/emacs-ssh-directory-tracking-via-tramp
  :init
  (defadvice ssh (after ssh-fs-hook activate)
    (message "tracking...")
    (ssh-direcory-tracking-mode))
  :config
  (progn
    (setq-default ssh-directory-tracking-mode t)
    ;; TODO: dirtrack-mode with regex depending on PS1
    ))
(provide 'init-ssh)
