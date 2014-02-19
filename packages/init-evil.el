(use-package evil
  :ensure evil
  :init
  (progn
    (use-package evil-leader
      :ensure evil-leader
      :init (global-evil-leader-mode)
      :config
      (progn
        (evil-leader/set-leader ",")
        (evil-leader/set-key-for-mode 'emacs-lisp-mode
           "e" 'eval-last-sexp)
        (evil-leader/set-key
           "f" 'ido-find-file
           "F" 'ido-find-file-other-window
           "b" 'ido-switch-buffer
           "x" 'smex
           "l" 'linum-mode
           "w" 'toggle-truncate-lines
           "d" 'ido-dired
           "t" 'speedbar-get-focus
           "j" 'bookmark-jump
           "c" 'evilnc-comment-or-uncomment-lines
           "o" 'other-window
           "q" 'previous-multiframe-window
           "g" 'ace-jump-mode
           "z" 'suspend-frame)))
    (use-package evil-tabs
      :ensure evil-tabs
      :init
      (progn
        (use-package elscreen
          :ensure elscreen)
        (global-evil-tabs-mode t)
        (define-key evil-insert-state-map (kbd "C-x t") 'elscreen-toggle)
        (define-key evil-normal-state-map (kbd "C-x t") 'elscreen-toggle)))
    (use-package evil-nerd-commenter
      :ensure evil-nerd-commenter)
        ;; enable by default
    (evil-mode 1))
  :config
  (progn
    (define-key evil-ex-map "e " 'find-file)
    (define-key evil-ex-map "b " 'switch-to-buffer)
    ;; I prefere C-j to Esc as it's on home row with Ctrl remapped to CapsLock
    (define-key evil-normal-state-map (kbd "C-j") 'evil-normal-state)
    (define-key evil-insert-state-map (kbd "C-j") 'evil-normal-state)
    (define-key evil-visual-state-map (kbd "C-j") 'evil-normal-state)))

(provide 'init-evil)
