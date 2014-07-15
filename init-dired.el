;; (use-package dired
;;   :config
;;   (progn
;;     (evil-leader/set-key 'Dired/name
;;       "s" 'my-dired-preview)))

(defun my-dired-preview ()
  (interactive)
  ;; TODO: kill if only one other window
  (delete-other-windows)
  (dired-find-file-other-window)
  (end-of-buffer)
  (previous-multiframe-window))

(defun my-dired-down-and-preview ()
  (interactive)
  (diredp-next-line 1)
  (my-dired-preview))

(setq dired-dwim-target t)


(provide 'init-dired)
