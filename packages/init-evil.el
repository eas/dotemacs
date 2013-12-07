(use-package evil
  :init
  (progn
    (use-package evil-leader
      :init (global-evil-leader-mode)
      :config
      (progn
        (evil-leader/set-leader ",")
        (evil-leader/set-key-for-mode 'emacs-lisp-mode
           "e" 'eval-last-sexp)
        (evil-leader/set-key
           "f" 'find-file
           "b" 'switch-to-buffer
           "x" 'execute-extended-command
           "l" 'linum-mode
           "w" 'toggle-truncate-lines
           "d" 'dired
           "t" 'speedbar-get-focus
           "j" 'bookmark-jump
           "c" 'evilnc-comment-or-uncomment-lines
           "o" 'other-window
           "q" 'previous-multiframe-window
           "z" 'suspend-frame)))
    (use-package evil-tabs
      :init (global-evil-tabs-mode t))
    (use-package evil-nerd-commenter)
        ;; enable by default
    (evil-mode 1))
  :config
  (progn
    (define-key evil-ex-map "e " 'find-file)
    (define-key evil-ex-map "b " 'switch-to-buffer)))

(provide 'init-evil)
