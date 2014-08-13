(use-package ssh
  :ensure
  :init
  (progn
    (setq-default ssh-directory-tracking-mode t)))
(provide 'init-ssh)
