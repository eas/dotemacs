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
(setq eshell-prompt-function 'my-eshell-prompt)
(setq eshell-highlight-prompt nil)

(provide 'init-eshell)
