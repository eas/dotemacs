;;; Initialized package.el first
(require 'package)

(add-to-list 'package-archives '("gnu" . "http://elpa.gnu.org/packages/"))
(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))

(add-to-list 'load-path (concat user-emacs-directory "lisp"))
(add-to-list 'load-path (concat user-emacs-directory "lisp-local"))
;; I might want to have some additional package archives
(require 'local-packaging nil t)

(package-initialize)
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

;; TODO: Configure all packages to store their data in that dir instead of `.emacs.d'
(make-directory (setq my-tmp-local-dir (concat user-emacs-directory ".tmp/")) t)

;; TODO: create file
(setq custom-file "~/.emacs-custom.el")

;; TODO: Do I need to setup recentf befor loading all my configs?
;; TODO: (setq recentf-exclude `(my-join-dirs dotfiles-dir "elpa"))
(setq recentf-max-menu-items 50)
(setq recentf-max-saved-items nil)

(require 'use-package)


;;; Backups

(setq
 my-tmp-backups-dir (concat my-tmp-local-dir "backups/")
 my-tmp-autosaves-dir (concat my-tmp-local-dir "autosaves/"))

(make-directory my-tmp-backups-dir t)
(make-directory my-tmp-autosaves-dir t)

(setq
 backup-by-copying t  ; Don't clobber symlinks
 backup-directory-alist `((".*" . ,my-tmp-backups-dir))
 auto-save-file-name-transforms `((".*" ,my-tmp-autosaves-dir t))
 auto-save-list-file-prefix (concat my-tmp-autosaves-dir ".saves-")
 delete-old-versions t
 kept-new-versions 6
 kept-old-versions 2
 version-control t)   ; Use versioned backups


;;; Libraries first so that the rest of init.el may rely on them.

(use-package diminish
  :ensure)
(use-package s
  :ensure)
(use-package f
  :ensure)
(use-package dash
  :ensure
  :config (dash-enable-font-lock))
(use-package dash-functional
  :ensure)


;;; General editing setup

;; colorscheme
(use-package zenburn-theme
  :ensure
  :init
  (load-theme 'zenburn t)
  :config
  (when (facep 'hl-line)
    (set-face-background 'hl-line "#808080")))
(setq inhibit-startup-screen t
      ;; Show the *scratch* on startup.
      initial-buffer-choice nil)

;; I prefer spaces over tabs
(setq-default
 indent-tabs-mode nil
 ;; ... and I prefer 4-space indents
 tab-width 4
 sentence-end-double-space nil)

;; Don't wrap lines
(setq-default truncate-lines t)

;; UTF-8 please!
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)
(prefer-coding-system 'utf-8)

;; Nuke trailing whitespace when writing to a file.
(add-hook 'before-save-hook 'delete-trailing-whitespace)

(defun my-save-buffer-without-dtw ()
  (interactive)
  (let ((b (current-buffer)))   ; memorize the buffer
    ;; new temp buffer to bind the global value of before-save-hook
    (with-temp-buffer
      (let ((before-save-hook (remove #'delete-trailing-whitespace
                                      before-save-hook)))
        ;; go back to the current buffer, before-save-hook is now buffer-local
        (with-current-buffer b
          (let ((before-save-hook (remove #'delete-trailing-whitespace
                                          before-save-hook)))
            (save-buffer)))))))

;; Always add a trailing newline - it's POSIX.
(setq require-final-newline t)

;; Smart scrolling.
(setq scroll-step 1
      scroll-conservatively 100000
      scroll-margin 5
      scroll-preserve-screen-position t)

;; Not sure if it is really needed. Told to be laggy.
(setq w32-get-true-file-attributes nil)

(line-number-mode t)                    ; have line numbers and
(column-number-mode t)                  ; column numbers in the mode line
(global-hl-line-mode t)                 ; highlight current line
(menu-bar-mode -1)                      ; no menu (questionable)

(defun my-font-candidate (&rest fonts)
  "Return the first available font."
  (--first (find-font (font-spec :name it)) fonts))

(when window-system
  (tool-bar-mode -1)                    ; definetely don't want to see toolbar
  (scroll-bar-mode -1)                  ; probably not needed
  ;; TODO:
  (set-face-attribute 'default nil :height 100 :family (my-font-candidate "DejaVu Sans Mono"
                                                                          "Lucida Console")))

;; Oterwise I cannot do smth like ciW (from evil-mode)
(setq save-interprogram-paste-before-kill t)


;;; Evil setup, should be relatively at the beginning because configuration
;;; setup below will bind keys assuming evil is used.

;; Evil requires it, otherwise regular Emacs undo is used
(use-package undo-tree
  :ensure)
(use-package evil
  :ensure
  :init
  (progn
    (evil-mode 1)
    ;; Make insert-state more like emacs
    (setcdr evil-insert-state-map nil)
    (define-key evil-insert-state-map [escape] #'evil-normal-state)
    ;; TODO: I also want C-p and C-n probably

    ;; I prefere C-j to Esc as it's on home row with Ctrl remapped to CapsLock
    (define-key evil-normal-state-map (kbd "C-j") #'evil-normal-state)
    (define-key evil-insert-state-map (kbd "C-j") #'evil-normal-state)
    (define-key evil-visual-state-map (kbd "C-j") #'evil-normal-state)))
(use-package evil-leader
      :ensure evil-leader
      :init
      (progn
        (global-evil-leader-mode t)
        (evil-leader/set-leader ",")
        (evil-leader/set-key-for-mode 'emacs-lisp-mode
          "e" #'eval-last-sexp)
        (defun my-prev-window ()
          (interactive)
          (other-window -1))
        (evil-leader/set-key
          "k" #'delete-window
          "tw" #'toggle-truncate-lines
          "d" #'ido-dired
          "o" #'other-window
          "j" #'bookmark-bmenu-list
          "tl" #'linum-mode
          ;; TODO: why did it stop working?
          ;; "q" 'previous-multiframe-window
          "q" #'my-prev-window
          "u" #'revert-buffer
          "z" #'suspend-frame)))
(use-package elscreen
  :ensure
  :init
  (progn
    (global-set-key (kbd "C-x t") #'elscreen-toggle)
    (evil-leader/set-key
      "tt" #'elscreen-toggle
      "te" #'elscreen-toggle-display-tab)))
(use-package evil-tabs
  :ensure
  :init
  (global-evil-tabs-mode))
(use-package evil-jumper
  :ensure)
(use-package evil-nerd-commenter
  :ensure
  :init
  (evil-leader/set-key "c" #'evilnc-comment-or-uncomment-lines)
  :commands (evilnc-comment-or-uncomment-lines))


;;; Other navigation/selection packages

(use-package ace-jump-mode
  :ensure
  :init
  (evil-leader/set-key "g" #'ace-jump-mode)
  :commands (ace-jump-mode))

(use-package ibuffer
  :ensure
  :init
  (progn
    (global-set-key (kbd "C-x C-b") #'ibuffer)
    (evil-leader/set-key
      "B" #'ibuffer))
  :commands (ibuffer))

(use-package ido
  :ensure
  :init
  (progn
    ;; I'm too lazy to find which default bindings I need
    ;; to get some lazy loading for ido.
    (ido-mode t)
    (evil-leader/set-key
      "f" #'ido-find-file
      "F" #'ido-find-file-other-window
      "b" #'ido-switch-buffer))
  :config
  (progn
    (ido-mode t)
    (setq ido-save-directory-list-file (concat my-tmp-local-dir "ido.last"))
    (setq ido-enable-flex-matching t)
    (setq ido-use-filename-at-point 'guess)
    (setq ido-show-dot-for-dired t)))
(use-package ido-vertical-mode
  :ensure
  :init (ido-vertical-mode t))
(use-package smex
  :ensure
  :bind (("M-x" . smex)
         ("M-X" . smex-major-mode-commands))
  :init
  (evil-leader/set-key
    "x" #'smex)
  :config
  (progn
    (setq smex-save-file (concat my-tmp-local-dir "smex-items"))
    (smex-initialize)))

(use-package helm
  :ensure helm
  :init
  (evil-leader/set-key
    "hl" #'helm-locate
    "he" #'helm-elscreen
    "hf" #'helm-find-files
    "hF" #'helm-complete-file-name-at-point
    "hh" #'helm-mini
    "hi" #'helm-semantic-or-imenu
    "hg" #'helm-do-grep
    "ha" #'helm-apropos
    "hy" #'helm-show-kill-ring)
  :commands
  (helm-locate
   helm-elscreen
   helm-find-files
   helm-complete-file-name-at-point
   helm-mini
   helm-semantic-or-imenu
   helm-do-grep
   helm-apropos
   helm-show-kill-ring
   helm
   helm-comp-read
   helm-other-buffer))
(use-package helm-descbinds
  :ensure helm-descbinds
  :init
  (helm-descbinds-mode))
(use-package helm-swoop
  :ensure helm-swoop
  :init
  (evil-leader/set-key
    "ho" #'helm-swoop
    "hs" #'helm-swoop)
  :commands (helm-swoop))


;;; Highlighting packages

(use-package highlight-parentheses
  :ensure highlight-parentheses
  :init
  (progn
    (define-globalized-minor-mode global-highlight-parentheses-mode
      highlight-parentheses-mode
      (lambda ()
        (highlight-parentheses-mode t)))
    (global-highlight-parentheses-mode t)))

(use-package color-identifiers-mode
  :ensure
  :init
  (add-hook 'emacs-lisp-mode-hook #'color-identifiers-mode))

(use-package fill-column-indicator
  :ensure fill-column-indicator
  :commands (fci-mode)
  :config
  (progn
    (setq fci-rule-color "darkblue")
    (setq-default fill-column 80)
    (define-globalized-minor-mode global-fci-mode
      fci-mode
      (lambda () (fci-mode 1)))))

(use-package indent-guide
  :ensure
  :init
  (add-hook 'emacs-lisp-mode-hook #'indent-guide-mode)
  :commands (indent-guide-mode
             indent-guide-global-mode)
  :config
  (setq indent-guide-recursive t))


;;; Dired/shell/etc
(use-package dired
  :init
  (evil-leader/set-key
    "d" #'dired)
  :commands (dired dired-other-window)
  :config
  (progn
    (setq dired-dwim-target t
          dired-listing-switches "-la --group-directories-first")
    ;; Not sure why `evil-mode' keybindings don't work otherwise.
    (add-hook 'dired-mode-hook #'evil-mode)))
(use-package dired+
  :ensure)

(use-package bookmark
  :init
  (setq bookmark-default-file (concat my-tmp-local-dir "bookmarks")))

(defmacro my-with-face (str &rest properties)
  `(propertize ,str 'face (list ,@properties)))

(use-package eshell
  :ensure
  :commands (eshell)
  :config
  (progn
    (setq eshell-directory-name (concat my-tmp-local-dir "eshell/"))
    (defun my-eshell-prompt ()
      (let ((header-bg "#fff"))
        (concat
         (my-with-face (concat (eshell/pwd) " "))
         (my-with-face (format-time-string "(%Y-%m-%d %H:%M) " (current-time))
                       :foreground "#888")
         (my-with-face
          (or (ignore-errors
                (format "(%s)" (vc-responsible-backend default-directory))) "")
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
    ;; (add-to-list 'eshell-visual-commands "git")
    (setq eshell-highlight-prompt nil)))

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

;; TODO
(require 'init-shell)

(use-package ssh
  :ensure
  :commands (ssh)
  :config
  (setq-default ssh-directory-tracking-mode t))

;; TRAMP:
(setq tramp-default-method "ssh"
      tramp-persistency-file-name (concat my-tmp-local-dir "tramp"))

(use-package ediff
  :ensure
  :commands (ediff ediff-buffers)
  :config
  (setq
   ;; make two side-by-side windows
   ediff-split-window-function #'split-window-horizontally

   ;; ignore whitespace diffs (questionable)
   ;; ediff-diff-options          "-w"

   ;; Do everything in one frame always
   ediff-window-setup-function #'ediff-setup-windows-plain))

(use-package uniquify
  :config
  (progn
    ;; this shows foo/bar and baz/bar when two files are named bar
    (setq uniquify-buffer-name-style 'forward)
    ;; strip common buffer suffixes
    (setq uniquify-strip-common-suffix t)
    ;; re-uniquify buffer names after killing one
    (setq uniquify-after-kill-buffer-p t)))

;;; Windows management
(use-package winner
  :ensure winner
  :init (winner-mode t))

(use-package switch-window
  :ensure
  :init
  (evil-leader/set-key
    "O" #'switch-window)
  :commands (switch-window))

(use-package popwin
  :ensure)



;;; Programming utils

;; Should enabled on per-mode basis, not here
(use-package eldoc
  :ensure)

(use-package paredit
  :ensure
  :commands (paredit-mode)
  :init
  (progn
    ;; Enable `paredit-mode' in the minibuffer, during `eval-expression'.
    (defun conditionally-enable-paredit-mode ()
      (if (eq this-command #'eval-expression)
          (paredit-mode 1)))

    (add-hook 'minibuffer-setup-hook #'conditionally-enable-paredit-mode)))


(use-package company
  :ensure company
  :init (global-company-mode)
  :config
  (progn
    (bind-key "C-n" #'company-select-next company-active-map)
    (bind-key "C-p" #'company-select-previous company-active-map)))

(use-package flycheck
  :ensure
  :init (global-flycheck-mode t)
  :config
  (progn
    (setq-default flycheck-disabled-checkers '(emacs-lisp-checkdoc))))

(use-package flycheck-cask
  :ensure
  :init (add-hook 'flycheck-mode-hook #'flycheck-cask-setup)
  :commands (flycheck-cask-setup))

(use-package magit
  :ensure)
(use-package git-gutter
  :ensure)
(use-package git-timemachine
  :ensure)
(use-package dsvn
  :ensure)

;; GDB
(defun my-gdb-key-bindings ()
  (interactive)
  (global-set-key (kbd "<f10>") #'gud-next)
  (global-set-key (kbd "S-<f10>") #'gud-nexti)
  (global-set-key (kbd "<f11>") #'gud-step)
  (global-set-key (kbd "S-<f11>") #'gud-stepi)
  (global-set-key (kbd "<f5>") #'gud-cont)
  (define-key evil-normal-state-map (kbd "SPC") #'evil-repeat))

(add-hook 'gud-mode-hook #'my-gdb-key-bindings)

(use-package ggtags
  :ensure
  :commands (ggtags-find-tag-dwim)
  :init
  (progn
    (define-key evil-motion-state-map "\C-]" #'ggtags-find-tag-dwim)))


;;; Programming Languages/Major modes

;; Emacs Lisp

;; paredit mode autopairs sexps and provides tools to manipulate sexps
(add-hook 'emacs-lisp-mode-hook 'enable-paredit-mode)
;; eldoc mode provides documentation in the minibuffer automatically
(add-hook 'emacs-lisp-mode-hook 'turn-on-eldoc-mode)

;; Haskell

(use-package haskell-mode
  :ensure haskell-mode
  :commands (haskell-mode)
  :config
  (progn
    (add-hook 'haskell-mode-hook 'turn-on-haskell-decl-scan)
    (add-hook 'haskell-mode-hook 'turn-on-haskell-doc-mode)
    (add-hook 'haskell-mode-hook 'turn-on-haskell-indentation)
    (add-hook 'haskell-mode-hook 'interactive-haskell-mode)
    (set 'haskell-font-lock-symbols nil)))

(use-package flycheck-haskell
  :ensure)

;; Org

(use-package org-mode
  :commands (org-mode)
  :config
  (progn
    (org-babel-do-load-languages
     'org-babel-load-languages
     '((python . t)
       (sh . t)
       (emacs-lisp . t)))

    (setq org-src-fontify-natively t)
    (setq org-log-done 'time)))

(use-package org-present
  :ensure
  :commands (org-present))


;;; Other

(put 'narrow-to-region 'disabled nil)



;;; Local setup

(add-to-list 'load-path (concat user-emacs-directory "lisp-local"))
(let ((default-directory (concat user-emacs-directory "site-lisp-local")))
  (normal-top-level-add-to-load-path '("."))
  (normal-top-level-add-subdirs-to-load-path))

(require 'init-local)
