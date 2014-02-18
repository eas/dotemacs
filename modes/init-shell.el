;; http://stackoverflow.com/questions/7987494/emacs-shell-mode-display-is-too-wide-after-splitting-window
(defun my-comint-fix-window-size ()
  "Change process window size."
  (interactive)
  (when (derived-mode-p 'comint-mode)
    (let ((process (get-buffer-process (current-buffer))))
      (unless (eq nil process)
        (set-process-window-size process (window-height) (window-width))))))

(defun my-shell-mode-hook ()
  ;; add this hook as buffer local, so it runs once per window.
  (add-hook 'window-configuration-change-hook 'my-comint-fix-window-size nil t))

(add-hook 'shell-mode-hook 'my-shell-mode-hook)
(provide 'init-shell)
