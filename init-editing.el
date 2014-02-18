;;; General editing configuration.

(setq inhibit-startup-screen t
      ;; Show the *scratch* on startup.
      initial-buffer-choice t)

;; I prefer spaces over tabs
(setq-default
 indent-tabs-mode nil
 ;; ... and I prefer 4-space indents
 tab-width 4)

;; Don't wrap lines
(setq-default truncate-lines t)

;; UTF-8 please!
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(prefer-coding-system 'utf-8)

;; Nuke trailing whitespace when writing to a file.
(add-hook 'write-file-hooks 'delete-trailing-whitespace)

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

(when window-system
  (tool-bar-mode -1)                    ; definetely don't want to see toolbar
  (scroll-bar-mode -1)                  ; probably not needed
  (set-face-attribute 'default nil :height 100 :family "Lucida Console"))

(provide 'init-editing)
