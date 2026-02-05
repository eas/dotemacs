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

(use-package general
  :config
  (general-evil-setup)
  (general-auto-unbind-keys)
  (general-create-definer my-leader
    :states '(motion insert emacs)
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

    "o" 'other-window
    "q" '((lambda () (interactive) (other-window -1))
	      :wk "prev-window")
    "p" '(:keymap project-prefix-map :wk "project")
    "x" 'execute-extended-command
    "u" 'revert-buffer

    "B" '(:ignore t :wk "bookmarks")
    "Bs" 'bookmark-set
    "Bj" 'bookmark-jump

    "v" '((lambda ()
            (interactive)
            (pop-to-buffer "*pipe*")
            (erase-buffer)
            (insert-file-contents "~/pipe")
            (llvm-mode)) :wk "view pipe")

    "V" '((lambda ()
            (interactive)
            (switch-to-buffer "*pipe*")
            (erase-buffer)
            (insert-file-contents "~/pipe")
            (llvm-mode))
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
(use-package zenburn-theme
  ;; :config
  ;; (load-theme 'zenburn t)
  )

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

(use-package jinx
  :hook (emacs-startup . global-jinx-mode))

(use-package treesit-auto
  :config
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
   "C-c ." 'embark-act))
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

(use-package llvm-ts-mode)
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
    (insert (completing-read "From comint history: " (ring-elements comint-input-ring))))
  (defun my-search-bash-history ()
    (interactive)
    (insert (completing-read "From bash history: "
                             (seq-reverse
                              (seq-filter
                               (lambda (line) (not (string-match "^#" line)))
                               (split-string
                                (with-temp-buffer
                                  (insert-file-contents "~/.bash_eternal_history")
                                  (buffer-substring-no-properties
                                   (point-min)
                                   (point-max)))
                                "\n" t))))))
  (my-leader
    'comint-mode-map
    "hr" 'my-search-comint-history
    "sh" 'my-search-comint-history
    "hR" 'my-search-bash-history
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

(setq compile-command "ionice -c3 nice ninja -C build")
(put 'narrow-to-region 'disabled nil)

;; TODO:
(use-package eglot-supplements
  :vc (:url "https://codeberg.org/harald/eglot-supplements"))

(use-package eglot-selran) ;; selection ranges
(use-package eglot-cthier) ;; call and type hierarchies
(use-package eglot-marocc) ;; mark occurrences
;;(use-package eglot-semtok) ;; font-lock per semantic tokens (experimental)

;; LLVM development setup
(defmacro my-in-project-root (body)
  `(let ((default-directory (project-root (project-current t))))
     ,body))

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
    "la" '((lambda ()
             (interactive)
             (my-in-project-root
              (shell-command
               (concat "llvm/utils/update_analyze_test_checks.py --opt-binary=build/bin/opt " buffer-file-name)))
             (revert-buffer :NOCONFIRM t))
           :wk "update analyze test")
    "lt" '((lambda ()
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
    "lu" '((lambda ()
             (interactive)
             (my-in-project-root (compile "ionice -c3 nice ninja -C build VectorizeTests")))
           :wk "build VectorizeTests unittests")
    "le" '((lambda (func)
             (interactive "sFunction: ")
             (let ((buf (generate-new-buffer (concat func ".ll"))))
               (my-in-project-root
                (shell-command
                 (format "build/bin/llvm-extract --func %s -S %s" func buffer-file-name)
                 buf))
               (switch-to-buffer buf)
               (llvm-mode)))
           :wk "extract function"))
