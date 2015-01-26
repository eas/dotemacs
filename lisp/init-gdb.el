;; (setq gdb-create-source-file-list nil
;;       gdb-non-stop-setting nil)

(defun my-gdb-key-bindings ()
  (interactive)
  (global-set-key (kbd "<f10>") 'gud-next)
  (global-set-key (kbd "S-<f10>") 'gud-nexti)
  (global-set-key (kbd "<f11>") 'gud-step)
  (global-set-key (kbd "S-<f11>") 'gud-stepi)
  (global-set-key (kbd "<f5>") 'gud-cont)
  (define-key evil-normal-state-map (kbd "SPC") 'evil-repeat))

(add-hook 'gud-mode-hook 'my-gdb-key-bindings)

(provide 'init-gdb)
