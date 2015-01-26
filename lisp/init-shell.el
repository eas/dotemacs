(require 'comint)
;; TODO: correct auto-loads
(require 'helm)
(require 'helm-buffers) ;; for helm-buffers-fuzzy-matching variable
(require 'helm-misc)    ;; for helm-comint-input-ring-action

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

(evil-define-key 'insert shell-mode-map
  (kbd "C-r") 'helm-comint-input-ring
  (kbd "C-R") 'my-helm-command-from-bash
  (kbd "C-p") 'comint-previous-input
  (kbd "C-n") 'comint-next-input)

(evil-define-key 'normal shell-mode-map
  (kbd "C-r") 'helm-comint-input-ring
  (kbd "C-R") 'my-helm-command-from-bash
  (kbd "C-p") 'comint-previous-input
  (kbd "C-n") 'comint-next-input)


(setq comint-prompt-regexp "^\$ ")
;; Taken from https://github.com/jwiegley/dot-emacs/blob/master/lisp/helm-commands.el
(defun my-helm-c-bash-history-set-candidates (&optional request-prefix)
  (let ((pattern (replace-regexp-in-string
                  " " ".*"
                  (or (and request-prefix
                           (concat request-prefix
                                   " " helm-pattern))
                      helm-pattern)))
        (fun (if helm-buffers-fuzzy-matching
                 #'helm--mapconcat-candidate
               #'identity)))
    (with-current-buffer (find-file-noselect "~/.bash_history" t t)
      (auto-revert-mode -1)
      (goto-char (point-max))
      (loop for pos = (re-search-backward (funcall fun pattern) nil t)
            while pos
            collect (s-trim-right  ;; to get rid of ^M on Windows
                     (replace-regexp-in-string
                      "\\`:.+?;" ""
                      (buffer-substring (line-beginning-position)
                                        (line-end-position))))))))

(defun my-helm-c-bash-history-action (candidate)
  (async-shell-command candidate))

(defvar my-helm-c-source-bash-history
  '((name . "Bash History")
    (candidates . my-helm-c-bash-history-set-candidates)
    (action . (("Execute the command" . helm-comint-input-ring-action)
               ("Execute Command Async" . my-helm-c-bash-history-action)))
    (volatile)
    (requires-pattern . 3)
    (delayed)))


(defun my-helm-command-from-bash ()
  (interactive)
  (helm-other-buffer 'my-helm-c-source-bash-history "*helm bash history*"))

(evil-leader/set-key-for-mode 'shell-mode
  "hr" 'helm-comint-input-ring
  "hR" 'my-helm-command-from-bash)

(provide 'init-shell)
