;; -*- lexical-binding: t; -*-

(setq inhibit-startup-screent t
      mac-command-modifier 'control
      enable-recursive-minibuffers t)
(menu-bar-mode -1)
(scroll-bar-mode -1)
(tool-bar-mode -1)

(global-hl-line-mode t)
(tab-bar-history-mode t)
(electric-pair-mode t)
(line-number-mode t)
(column-number-mode t)

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file 'noerror)

(set-charset-priority 'unicode) ;; utf8 everywhere
(setq locale-coding-system 'utf-8
      coding-system-for-read 'utf-8
      coding-system-for-write 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(set-selection-coding-system 'utf-8)
(prefer-coding-system 'utf-8)
(setq default-process-coding-system '(utf-8-unix . utf-8-unix))

(setq ediff-split-window-function 'split-window-horizontally)

(global-set-key [remap list-buffers] 'ibuffer)

(filesets-init)

(require 'package)
(add-to-list 'package-archives '("MELPA" . "http://melpa.org/packages/"))
(package-initialize)

(require 'use-package)
(require 'use-package-ensure)
(setq use-package-always-ensure t)

(require 'uniquify)
(setq uniquify-buffer-name-style 'forward)

(require 'dired-x)

(use-package evil
  :init
  (setq evil-disable-insert-state-bindings t
	evil-undo-system 'undo-redo)
  (evil-mode))

;; Bells and whistles?
(use-package evil-goggles
  :init
  (evil-goggles-mode))

(use-package which-key
  :init
  (which-key-mode t))

(defun my-update-pipe-buffer ()
  "Update *pipe* buffer with contents of ~/pipe."
  (let ((buf (get-buffer-create "*pipe*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert-file-contents "~/pipe")
        (llvm-mode)
        (setq-local revert-buffer-function
                    (lambda (&optional ignore-auto noconfirm preserve-modes)
                      (interactive)
                      (my-update-pipe-buffer)))))
    buf))

(use-package general
  :config
  (general-evil-setup)
  (general-auto-unbind-keys)
  (general-create-definer my-leader
    :states '(motion insert emacs)
    :keymaps 'override
    :prefix "SPC"
    :global-prefix "C-c")
  (general-define-key
   :states '(motion visual insert)
   "C-j" 'evil-force-normal-state
   "C-g" 'evil-force-normal-state)
  (my-leader
    "t" '(:ignore t :wk "toggle")
    "tt" 'toggle-truncate-lines
    "tl" 'display-line-numbers-mode
    "tj" 'jinx-mode

    "o" 'other-window
    "q" '((lambda () (interactive) (other-window -1))
	      :wk "prev-window")
    "p" '(:keymap project-prefix-map :wk "project")
    "x" 'execute-extended-command
    "u" 'revert-buffer

    "B" '(:ignore t :wk "bookmarks")
    "Bs" 'bookmark-set
    "Bj" 'bookmark-jump
    "BB" 'bookmark-bmenu-list

    "v" '((lambda ()
            (interactive)
            (pop-to-buffer (my-update-pipe-buffer)))
          :wk "view pipe")

    "V" '((lambda ()
            (interactive)
            (switch-to-buffer (my-update-pipe-buffer)))
          :wk "view pipe (same window)")

    "k"  'delete-window
    "f" 'dired-x-find-file
    "F" 'dired-x-find-file-other-window))

(use-package evil-nerd-commenter
  :general
  (my-leader
    "c" 'evilnc-comment-or-uncomment-lines))

(use-package nlinum
  :general
  (my-leader
    "tL" 'nlinum-mode))

(use-package magit
  :general
  ("C-c m" 'magit))

;; Add custom lisp directory to load-path
(add-to-list 'load-path (concat user-emacs-directory "lisp"))

;; Magit log collapsing - fold/unfold linear commit ranges - useful to study
;; merge structures.
;; Press 'z' in magit-log refresh menu (L in log buffer)
;; Shows current state: [collapsed] or [expanded]
;; TAB on collapsed lines toggles individual regions, RET shows commit info
(use-package magit-log-collapse
  :ensure nil
  :after magit)

(use-package zenburn-theme
  ;; :config
  ;; (load-theme 'zenburn t)
  )

;; Load whiteboard theme (built-in light theme)
(load-theme 'whiteboard t)

(use-package ws-butler
  :hook (prog-mode . ws-butler-mode))

(use-package vertico
  :config
  (vertico-mode)
  (vertico-multiform-mode))

(use-package vertico-posframe
  :init
  (setq vertico-posframe-parameters   '((left-fringe  . 12)    ;; Fringes
                                        (right-fringe . 12)
                                        (undecorated  . nil))) ;; Rounded frame
  :config
  (vertico-posframe-mode 1))

(use-package savehist
  :init
  (savehist-mode))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles partial-completion))))
  (completion-pcm-leading-wildcard t))

(use-package marginalia
  :general
  (general-def minibuffer-local-map "M-a" 'marginalia-cycle)
  :config
  (marginalia-mode))

(use-package nerd-icons-completion
  :after marginalia
  :config
  (nerd-icons-completion-mode)
  (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup))

;; TODO:
(use-package nerd-icons)
(use-package emojify
  :config
  (when (member "Apple Color Emoji" (font-family-list))
    (set-fontset-font
     t 'symbol (font-spec :family "Apple Color Emoji") nil 'prepend)))
(use-package all-the-icons
  :if (display-graphic-p))

(use-package corfu
  :custom
  (corfu-cycle t)
  (corfu-popupinfo-delay '(0.5 . 0.2))
  ;; :general
  ;; (:keymap corfu-map
  ;; 	   "C-n" 'corfu-next
  ;; 	   "C-p" 'corfu-previous)
  :init
  (global-corfu-mode)
  (corfu-popupinfo-mode))

(use-package jinx)

(use-package treesit-auto
  :config
  ;; Filter out languages with version mismatches before activating
  (setq treesit-auto-recipe-list
        (seq-filter
         (lambda (recipe)
           (eq t (treesit-language-available-p (treesit-auto-recipe-lang recipe) t)))
         treesit-auto-recipe-list))
  (global-treesit-auto-mode)
  (setq treesit-auto-install 'prompt))

(use-package olivetti
  :config
  (define-globalized-minor-mode global-olivetti-mode
    olivetti-mode
    (lambda () (olivetti-mode t))))

(use-package ripgrep)

(use-package consult
  :general
  (my-leader
    "b" 'consult-buffer
    "s" '(:ignore t :wk "consult")
    "sr" 'consult-ripgrep
    "sg" 'consult-git-grep
    "sf" 'consult-find
    "sF" 'consult-locate
    "sl" 'consult-line
    "sL" 'consult-line-multi
    "sy" 'consult-yank-from-kill-ring))

(use-package embark
  :general
  (my-leader
    "." 'embark-act)
  (general-define-key
   :key-map minibuffer-mode-map
   "C-c ." 'embark-act
   "C-." 'embark-act)
  (general-define-key
   :key-map vertico-map
   "C-c ." 'embark-act
   "C-." 'embark-act))
(use-package embark-consult)

(use-package helpful
  :general
  ("C-h f" 'helpful-callable)
  ("C-h v" 'helpful-variable)
  ("C-h k" 'helpful-key)
  ("C-h t" 'helpful-at-point))

;; TODO:
(use-package cape
  :general
  ;; ("M-c" '(:ignore t :wk "cape"))
  ;; ("M-p f" 'cape-file)
  ;; ("M-p h" 'cape-history)
  )

;; Only load llvm-ts-mode if the grammar is compatible
(when (eq t (treesit-language-available-p 'llvm t))
  (use-package llvm-ts-mode))
;; https://github.com/benwilliamgraham/tree-sitter-llvm

;; https://www.patrickdelliott.com/emacs.d/

(setq backup-directory-alist `(("." . (concat user-emacs-directory ".backup")))
      backup-by-copying t
      delete-old-versions t
      kept-new-versions 6
      kept-old-versions 2
      version-control t
      inhibit-startup-message t
      recentf-max-saved-items nil
      ;; Always add a trailing newline - it's POSIX.
      require-final-newline t)
(setq-default fill-column 80
              indent-tabs-mode nil
              tab-width 4
              sentence-end-double-space nil)

(use-package rst)

(use-package color-identifiers-mode
  :init
  (add-hook 'emacs-lisp-mode-hook #'color-identifiers-mode))

(use-package fill-column-indicator
  :commands (fci-mode)
  :init
  (define-globalized-minor-mode global-fci-mode
    fci-mode
    (lambda () (fci-mode 1)))
  :config
  (setq fci-rule-color "darkblue"))

(use-package highlight-thing
  :config
  (defface highlight-thing
    '((t (:inherit 'company-preview-search)))
    "Face that is used to highlight things."
    :group 'highlight-thing))

(use-package command-log-mode :defer t)

(use-package realgud
  :config
  ;; TODO: upstream
  (defun realgud:cmd-eval (arg)
    "Eval an expression."
    (interactive
     (list
      (let ((default-value (thing-at-point 'symbol t)))
        (read-string (format "Evaluate expresison [%s]: " default-value)
                     nil 'minibuffer-history default-value))))
    (realgud:cmd-run-command arg "eval"))
  ;; Extension for LLVM's dump methods
  (defun realgud:cmd-dump (arg)
    "Dump an expression."
    (interactive (list
                  (let ((default-value (thing-at-point 'symbol t)))
                    (read-string (format "Dump expresison [%s]: " default-value)
                                 nil 'minibuffer-history default-value))))
    (realgud:cmd-run-command arg "dump"))
  (defun realgud:cmd-dump-region(start end)
    "Dump current region."
    (interactive "r")
    (let ((text (buffer-substring-no-properties start end)))
      (realgud:cmd-run-command text "dump")))
  (defun realgud:cmd-dump-dwim()
    "Dump the current region if active; otherwise, prompt."
    (interactive)
    (call-interactively (if (region-active-p)
                            #'realgud:cmd-dump-region
                          #'realgud:cmd-dump)))
  (defun realgud:cmd-reverse-next (&optional count)
    (interactive "p")
    (realgud:cmd-run-command count "reverse-next"))
  (defun realgud:cmd-reverse-step (&optional count)
    (interactive "p")
    (realgud:cmd-run-command count "reverse-step"))
  (defun realgud:cmd-reverse-continue (&optional arg)
    (interactive "p")
    (realgud:cmd-run-command arg "reverse-continue"))

  (puthash "dump" "dump %s" realgud-cmd:default-hash)
  (puthash "reverse-next" "reverse-next %p" realgud-cmd:default-hash)
  (puthash "reverse-step" "reverse-step %p" realgud-cmd:default-hash)
  (puthash "reverse-continue" "reverse-continue" realgud-cmd:default-hash)

  (bind-key "E" 'realgud:cmd-dump-dwim realgud:shortkey-mode-map)

  ;; ;; TODO: Does it work?
  ;; (rtags-enable-standard-keybindings realgud:shortkey-mode-map)

  (evil-define-key 'normal realgud:shortkey-mode-map
    "E" 'realgud:cmd-dump-dwim
    "e" 'realgud:cmd-eval-dwim
    "d" 'realgud:cmd-newer-frame
    "u" 'realgud:cmd-older-frame
    "J" 'realgud:cmd-next
    "K" 'realgud:cmd-reverse-next
    "H" 'realgud:cmd-reverse-step
    "L" 'realgud:cmd-step
    "c" 'realgud:cmd-continue
    "r" 'realgud:cmd-reverse-continue
    "R" 'realgud:cmd-restart
    "F" 'realgud:cmd-finish)
  (evil-define-key 'visual realgud:shortkey-mode-map
    "E" 'realgud:cmd-dump-dwim
    "e" 'realgud:cmd-eval-dwim))

(use-package realgud-lldb)

;; Shell setup
(use-package comint
  :ensure nil
  :commands (comint-mode)
  :config
  (defun my-comint-send-input-no-move ()
    (interactive)
    (save-excursion
      (comint-send-input)))
  (defun my-comint-get-old-input ()
    (let (bof)
      (if (and (not comint-use-prompt-regexp)
               ;; Make sure we're in an input rather than output field.
               (null (get-char-property (setq bof (field-beginning)) 'field)))
          (field-string-no-properties bof)
        (comint-bol)
        (replace-regexp-in-string
         ;; Handle output of "sh -x"
         "^\+ " ""
         (buffer-substring-no-properties (point)
                                         (line-end-position))))))
  (general-def
    :states 'normal
    :key-map comint-mode-map
    "M" 'my-comint-send-input-no-move
    "RET" 'comint-send-input)
  (general-def
    :states '(normal insert)
    :key-map comint-mode-map
    "C-p" 'comint-previous-input
    "C-n" 'comint-next-input)

  ; Needs specific PS1:
  (setq comint-prompt-regexp "^\$ "
        comint-get-old-input #'my-comint-get-old-input)
  (defun my-search-comint-history ()
    (interactive)
    (insert (completing-read "From comint history: "
                            (my-presorted-completion-table
                             (seq-filter (lambda (s) (not (string-empty-p s)))
                                        (ring-elements comint-input-ring))))))
  (defun my-search-bash-history ()
    (interactive)
    (insert (completing-read "From bash history: "
                             (my-presorted-completion-table
                              (seq-reverse
                               (seq-filter
                                (lambda (line) (not (string-match "^#" line)))
                                (split-string
                                 (with-temp-buffer
                                   (insert-file-contents "~/.bash_eternal_history")
                                   (buffer-substring-no-properties
                                    (point-min)
                                    (point-max)))
                                 "\n" t)))))))
  (my-leader
    'comint-mode-map
    "sh" 'my-search-comint-history
    "sH" 'my-search-bash-history))

(defun my-comint-fix-window-size ()
  "Change process window size."
  (interactive)
  (when (derived-mode-p 'comint-mode)
    (let ((process (get-buffer-process (current-buffer))))
      (unless (eq nil process)
        (set-process-window-size process (window-height) (window-width))))))

;; (use-package comint-intercept
;;   :commands (comint-intercept-mode)
;;   :init (add-hook 'shell-mode-hook 'comint-intercept-mode))

(defun my-shell-mode-hook ()
  ;; add this hook as buffer local, so it runs once per window.
  (add-hook 'window-configuration-change-hook 'my-comint-fix-window-size nil t))

(add-hook 'shell-mode-hook 'my-shell-mode-hook)

(defmacro my-with-face (str &rest properties)
  `(propertize ,str 'face (list ,@properties)))

(use-package eshell
  :commands (eshell)
  :config
  ;; TODO: fix it!
  ;; (setq eshell-directory-name (concat my-tmp-local-dir "eshell/"))
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
  (setq eshell-highlight-prompt nil))


(use-package clang-format
  :init
  ;; https://github.com/hotpxl/colonise/blob/master/emacs#L348
  (evil-define-operator my-evil-indent-clang-format (beg end)
    "Indent using clang-format."
    :move-point nil
    :type line
    (clang-format-region beg (1- end)))
  (general-def
    :states '(normal visual)
    :keymaps '(c-ts-base-mode-map c-mode-base-map)
    "=" 'my-evil-indent-clang-format)
  (general-def
    :states '(input emacs)
    :keymaps '(c-ts-base-mode-map c-mode-base-map)
    "<tab>" 'clang-format-region)
  ;; (evil-define-key 'normal c-mode-base-map "=" 'my-evil-indent-clang-format)
  ;; (evil-define-key 'visual c-mode-base-map "=" 'my-evil-indent-clang-format)
  ;; :bind
  ;; (:map c-mode-base-map
  ;;       ("<tab>" . clang-format-region))
  )

(defun my-underscore-as-part-of-word ()
  (interactive)
  (modify-syntax-entry ?_ "w"))
(add-hook 'prog-mode-hook #'my-underscore-as-part-of-word)

(defun my-dash-as-part-of-word()
  (interactive)
  (modify-syntax-entry ?- "w"))
(add-hook 'emacs-lisp-mode-hook #'my-dash-as-part-of-word)

(use-package markdown-ts-mode)

;; TODO: Integrate with evil
(use-package dired-preview)

(setq compile-command "ionice -c3 nice ninja -C build")
(put 'narrow-to-region 'disabled nil)

;; TODO:
(use-package eglot-supplements
  :vc (:url "https://codeberg.org/harald/eglot-supplements")
  :init
  (require 'eglot-selran)
  (require 'eglot-cthier)
  (require 'eglot-marocc))

;; (use-package eglot-selran) ;; selection ranges
;; (use-package eglot-cthier) ;; call and type hierarchies
;; (use-package eglot-marocc) ;; mark occurrences
;;(use-package eglot-semtok) ;; font-lock per semantic tokens (experimental)

;; LLVM development setup
(defun my-list-matching-lines (regexp &optional buffer)
  "Return a list of lines matching REGEXP in BUFFER (or the current buffer if not given)."
  (with-current-buffer (or buffer (current-buffer))
    (let ((matching-lines nil)
          (case-fold-search t) ; Set to nil for case-sensitive search
          (inhibit-read-only t)) ; Temporarily make buffer writable for search operations
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward (concat "^.*" regexp ".*$") nil t)
          ;; Add the line to the list
          (push (match-string 0) matching-lines)
          ;; Move past the current match to search for the next one
          (goto-char (match-end 0))))
      ;; Reverse the list so lines are in their original buffer order
      (nreverse matching-lines))))

(defun my-get-RUN-lines (&optional buffer)
  "Return a list of lines matching REGEXP in BUFFER (or the current buffer if not given)."
  (with-current-buffer (or buffer (current-buffer))
    (let ((matching-lines nil)
          (case-fold-search t) ; Set to nil for case-sensitive search
          (inhibit-read-only t) ; Temporarily make buffer writable for search operations
          (append-last nil))
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward (concat "^.*RUN:\\S*\\(.*[^\\\\]\\)\\(\\\\?\\)$") nil t)
          ;; Add the line to the list
          (if append-last
              (setcar matching-lines (concat (car matching-lines) " " (match-string 1)))
            (push (match-string 1) matching-lines))
          (setq append-last (equal (match-string 2) "\\"))
          ;; Move past the current match to search for the next one
          (goto-char (match-end 0))))
      ;; Reverse the list so lines are in their original buffer order
      (nreverse matching-lines))))

(defmacro my-in-project-root (body)
  `(let ((default-directory (project-root (project-current t))))
     ,body))

(defun my-get-cur-llvm-func ()
  (save-excursion
    (re-search-backward "^define")
    (buffer-substring (search-forward "@") (- (search-forward "(") 1))))

(defun my-presorted-completion-table (completions)
  (lambda (string pred action)
    (if (eq action 'metadata)
        `(metadata (display-sort-function . ,#'identity))
      (complete-with-action action completions string pred))))

(setq my-opt-commands
      '("opt -S -p loop-vectorize -vplan-print-after-all"
        "opt -S -p loop-vectorize -force-vector-width=4 -vplan-print-after-all"
        "opt -S -p loop-vectorize -mtriple=riscv64 -mattr=+v -vplan-print-after-all"
        "opt -S -p loop-vectorize -mtriple=x86_64 -mattr=+avx512f -vplan-print-after-all"
        "opt -S -p loop-vectorize -mtriple=riscv64 -mattr=+v -vplan-print-after=replaceSymbolicStrides -vplan-print-before=replaceSymbolicStrides"))

(defvar my-read-command-history nil)
(defun my-read-command ()
  (let ((commands (append
                   my-opt-commands
                   (mapcar (lambda (line)
                             (substring
                              line
                              (string-search "opt " line)
                              (string-search "|" line)))
                           (my-get-RUN-lines)))))
    (concat "build/bin/"
            (replace-regexp-in-string
             "<? *%s " " "
             (completing-read "Command: " (my-presorted-completion-table commands) nil nil nil 'my-read-command-history)))))

(defun my-command-on-func (file func command tgt-buf &optional project)
  (interactive (let* ((func (my-get-cur-llvm-func))
                      (command (my-read-command))
                      (project (when current-prefix-arg
                                 (project-prompt-project-dir))))
                 (list buffer-file-name func command "*llvm*" project)))
  (let ((default-directory (or project (project-root (project-current t)))))
   (shell-command
    ;; Pass through opt first to apply -mtriple/-mattr.
    ;; TODO: Somehow pass `--rglob '.*'' when applicable...
    (format "build/bin/opt %s %s %s | build/bin/llvm-extract --func %s | %s "
            (if (string-match "-mtriple=[^ ]*" command)
                (match-string 0 command) "")
            (if (string-match "-mattr=[^ ]*" command)
                (match-string 0 command) "")
            file
            func
            command)
    tgt-buf))
  (pop-to-buffer tgt-buf)
  (llvm-mode)
  (setq-local revert-buffer-function
              (lambda (&optional ignore-auto noconfirm preserve-modes)
                (interactive)
                (message "My custom revert")
                (with-current-buffer tgt-buf (erase-buffer))
                (my-command-on-func file func command tgt-buf))))

(defun my-command-on-file (file command tgt-buf &optional project)
  (interactive (list buffer-file-name
                     (my-read-command)
                     "*llvm*"
                     (when current-prefix-arg
                       (project-prompt-project-dir))))
  (let ((default-directory (or project (project-root (project-current t)))))
   (shell-command (concat command " " file) tgt-buf))
  (pop-to-buffer tgt-buf)
  (llvm-mode)
  (setq-local revert-buffer-function
              (lambda (&optional ignore-auto noconfirm preserve-modes)
                (interactive)
                (message "My custom revert")
                (with-current-buffer tgt-buf (erase-buffer))
                (my-command-on-file file command tgt-buf))))

(defvar my-compare-opts-history nil)
(defun my-compare (file func command-common opts-left opts-right tgt-buf-left tgt-buf-right)
  (interactive (let* ((func (my-get-cur-llvm-func))
                      (command-common (my-read-command))
                      (opts-left (read-string "Extra opts left: " nil 'my-compare-opts-history))
                      (opts-right (read-string (concat "Extra opts right (left was <" opts-left ">) " ": ") opts-left 'my-compare-opts-history)))
                 (list buffer-file-name func command-common opts-left opts-right (concat "*llvm|" opts-left "*") (concat "*llvm|" opts-right "*"))))
  (my-command-on-func file func (concat command-common " " opts-left) tgt-buf-left)
  (my-command-on-func file func (concat command-common " " opts-right) tgt-buf-right)
  (ediff-buffers tgt-buf-left tgt-buf-right))

(defun my-compare-on-file (file command-common opts-left opts-right tgt-buf-left tgt-buf-right)
  (interactive (let* ((command-common (my-read-command))
                      (opts-left (read-string "Extra opts left: " nil 'my-compare-opts-history))
                      (opts-right (read-string (concat "Extra opts right (left was <" opts-left ">) " ": ") opts-left 'my-compare-opts-history)))
                 (list buffer-file-name command-common opts-left opts-right (concat "*llvm|" opts-left "*") (concat "*llvm|" opts-right "*"))))
  (my-command-on-file file (concat command-common " " opts-left) tgt-buf-left)
  (my-command-on-file file (concat command-common " " opts-right) tgt-buf-right)
  (ediff-buffers tgt-buf-left tgt-buf-right))

(defun my-compare-projects (file func command project-left project-right tgt-buf-left tgt-buf-right)
  (interactive (let* ((func (my-get-cur-llvm-func))
                       (command (my-read-command))
                       (project-left (project-prompt-project-dir))
                       (project-right (project-prompt-project-dir)))
                  (list buffer-file-name func command project-left project-right
                        (concat "*llvm|" project-left "*")
                        (concat "*llvm|" project-right "*"))))
  (my-command-on-func file func command tgt-buf-left project-left)
  (my-command-on-func file func command tgt-buf-right project-right)
  (ediff-buffers tgt-buf-left tgt-buf-right))

(my-leader
    "l" '(:ignore t :wk "llvm")
    "ll" '((lambda ()
             (interactive)
             (my-in-project-root (compile (concat "build/bin/llvm-lit -v " buffer-file-name))))
           :wk "run llvm-lit")
    "lL" '((lambda ()
             (interactive)
             (my-in-project-root (compile (concat "build/bin/llvm-lit -a " buffer-file-name))))
           :wk "run llvm-lit -a")
    "lv" '((lambda ()
             (interactive)
             (my-in-project-root (compile (concat "build/bin/opt --disable-output -p verify " buffer-file-name))))
           :wk "verify ir")
    "lt" '((lambda ()
             (interactive)
             (my-in-project-root
              (shell-command
               (concat "llvm/utils/update_any_test_checks.py --path=build/bin " buffer-file-name)))
             (revert-buffer :NOCONFIRM t))
           :wk "update any test")
    "lT" '(:ignore t :wk "update-test-specific")
    "lTa" '((lambda ()
              (interactive)
              (my-in-project-root
               (shell-command
                (concat "llvm/utils/update_analyze_test_checks.py --opt-binary=build/bin/opt " buffer-file-name)))
              (revert-buffer :NOCONFIRM t))
            :wk "update analyze test")
    "lTt" '((lambda ()
              (interactive)
              (my-in-project-root
               (shell-command
                (concat "llvm/utils/update_test_checks.py --opt-binary=build/bin/opt " buffer-file-name)))
              (revert-buffer :NOCONFIRM t))
            :wk "update ir test")
    "lo" '((lambda ()
             (interactive)
             (my-in-project-root (compile "ionice -c3 nice ninja -C build opt")))
           :wk "build opt")
    "lO" '((lambda ()
             (interactive)
             (my-in-project-root (compile "ionice -c3 nice ninja -C build.debug opt")))
           :wk "build debug opt")
    "lU" '((lambda ()
             (interactive)
             (my-in-project-root (compile "ionice -c3 nice ninja -C build VectorizeTests && build/unittests/Transforms/Vectorize/VectorizeTests")))
           :wk "build VectorizeTests unittests")
    "lu" '((lambda ()
             (interactive)
             (my-in-project-root (compile "ionice -c3 nice ninja -C build check-llvm-transforms-loopvectorize check-llvm-analysis-loopaccessanalysis")))
           :wk "LoopVectorize check-llvm")
    "lf" '((lambda ()
             (interactive)
             (my-in-project-root (compile "ionice -c3 nice ninja -C build check-llvm")))
           :wk "Full check-llvm")
    "le" '((lambda (func)
             (interactive (list (read-string "Function: " (my-get-cur-llvm-func))))
             (let ((buf (generate-new-buffer (concat func ".ll"))))
               (my-in-project-root
                (shell-command
                 (format "build/bin/llvm-extract --func %s -S %s" func buffer-file-name)
                 buf))
               (switch-to-buffer buf)
               (llvm-mode)))
           :wk "extract function")
    "lc" '(my-command-on-func :wk "command on current func")
    "lC" '(my-command-on-file :wk "command on file")
    "ld" '(my-compare :wk "compare two commands on current func")
    "lD" '(my-compare-projects :wk "compare two projects on current func"))

(defun my-get-lines-between-patterns (start-regexp end-regexp)
  "Get the text between START-REGEXP and END-REGEXP as a string."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward start-regexp nil t)
      (let ((start-pos (point))) ; Capture position after the start match
        (when (re-search-forward end-regexp nil t)
          (let ((end-pos (match-beginning 0))) ; Capture position before the end match
            (buffer-substring-no-properties start-pos end-pos)))))))

(defun my-fails-to-dired ()
  (interactive)
  (let* ((fails-str (string-trim (my-get-lines-between-patterns "Failed Tests (.*):" "^$")))
         (fails-lines (string-split fails-str "\n"))
         (fails (mapcar (lambda (line)
                          (string-replace "LLVM :: " "" (string-trim line)))
                        fails-lines))
         (buf (read-string "Buffer: " "*Fails*"))
         (default-directory (concat default-directory "/llvm/test")))
    (dired (cons buf fails))))

(defun my-dired-update-checks ()
  (interactive)
  (let* ((project-dir (project-root (project-current)))
         (cmd (format "python3 %s/llvm/utils/update_any_test_checks.py --path %s/build/bin"
                       project-dir project-dir)))
    (dired-do-shell-command cmd nil (dired-get-marked-files))))


;; TODO:

(custom-theme-set-faces
 'user
 '(magit-section-highlight ((t (:inherit hl-line-face)))))

; s/\(VPlanTransforms::[^(]*\)(/RUN_VPLAN_PASS_NO_VERIFY(\1, /

(defun my-copy-rr-command ()
  (interactive)
  (kill-new (concat "rr record -n " (project-root (project-current t))
                    (string-replace "build/" "build.debug/" (my-read-command))
                    " " buffer-file-name)))

;; Load local/private configuration if it exists
(let ((local-init (expand-file-name "local/init.el" user-emacs-directory)))
  (when (file-exists-p local-init)
    (load local-init)))
