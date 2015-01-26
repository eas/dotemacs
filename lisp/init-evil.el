;; TODO: consider using req-package
;; Evil requires it, otherwise regular Emacs undo is used
(require 'init-undo-tree)

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
        (defun my-prev-window ()
          (interactive)
          (other-window -1))
        (evil-leader/set-key
          "f" 'ido-find-file
          "F" 'ido-find-file-other-window
          "b" 'ido-switch-buffer
          "B" 'ido-switch-buffer-other-window
          "x" 'smex
          "X" 'helm-M-x
          "k" 'delete-window
          "tl" 'linum-mode
          "te" 'elscreen-toggle-display-tab
          "tw" 'toggle-truncate-lines
          "d" 'ido-dired
          "ts" 'speedbar-get-focus
          "j" 'bookmark-bmenu-list
          "c" 'evilnc-comment-or-uncomment-lines
          "o" 'other-window
          "O" 'switch-window
          ;; TODO: why did it stop working?
          ;; "q" 'previous-multiframe-window
          "q" 'my-prev-window
          "g" 'ace-jump-mode
          "u" 'revert-buffer
          "z" 'suspend-frame)))
    (use-package evil-tabs
      :ensure evil-tabs
      :init
      (progn
        (use-package elscreen
          :ensure elscreen)
        (global-evil-tabs-mode t)
        (global-set-key (kbd "C-x t") 'elscreen-toggle)
        (evil-leader/set-key "tt" 'elscreen-toggle)))
    (use-package evil-nerd-commenter
      :ensure evil-nerd-commenter)
    ;; enable by default
    (use-package evil-jumper
      :ensure evil-jumper
      :init (require 'evil-jumper))
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
