;; (use-package dired
;;   :config
;;   (progn
;;     (evil-leader/set-key 'Dired/name
;;       "s" 'my-dired-preview)))

(defun my-dired-preview ()
  (interactive)
  (delete-other-windows)
  (dired-find-file-other-window)
  (previous-multiframe-window))


(provide 'init-dired)
