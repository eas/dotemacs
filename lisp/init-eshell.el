(use-package eshell
  :ensure eshell
  :config
  (progn
    (defun my-eshell-prompt ()
      (let ((header-bg "#fff"))
        (concat
         (my-with-face (concat (eshell/pwd) " "))
         (my-with-face (format-time-string "(%Y-%m-%d %H:%M) " (current-time)) :foreground "#888")
         (my-with-face
          (or (ignore-errors (format "(%s)" (vc-responsible-backend default-directory))) "")
          :background header-bg)
         (my-with-face "\n")
         (my-with-face user-login-name :foreground "blue")
         "@"
         (my-with-face "localhost" :foreground "green")
         (if (= (user-uid) 0)
             (my-with-face " #" :foreground "red")
           " $")
         " ")))

    ;; TODO: only *eshel* buffer
    (defun my-eshell-in-dir (&optional prompt)
      "Change the directory of an existing eshell to the directory of the file in
      the current buffer or launch a new eshell if one isn't running.  If the
      current buffer does not have a file (e.g., a *scratch* buffer) launch or raise
      eshell, as appropriate.  Given a prefix arg, prompt for the destination
      directory."
      (interactive "P")
      (let* ((name (buffer-file-name))
             (dir (cond (prompt (read-directory-name "Directory: " nil nil t))
                        (name (file-name-directory name))
                        (t nil)))
             (buffers (delq nil (mapcar (lambda (buf)
                                          (with-current-buffer buf
                                            (when (eq 'eshell-mode major-mode)
                                              (buffer-name))))
                                        (buffer-list))))
             (buffer (cond ((eq 1 (length buffers)) (first buffers))
                           ((< 1 (length buffers)) (ido-completing-read
                                                    "Eshell buffer: " buffers nil t
                                                    nil nil (first buffers)))
                           (t (eshell)))))
        (with-current-buffer buffer
          (when dir
            (eshell/cd (list dir))
            (eshell-send-input))
          (end-of-buffer)
          (pop-to-buffer buffer))))

    (setq eshell-prompt-function 'my-eshell-prompt)
    ;; (add-to-list 'eshell-visual-commands "git")
    (setq eshell-highlight-prompt nil)))

(provide 'init-eshell)
