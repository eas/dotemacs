;; General idea how to organize all initialization got from
;; https://github.com/bradleywright/emacs-d/blob/master/init.el



;; Add .emacs.d to 'load-path
(defconst dotfiles-dir
  (file-name-directory
   (or (buffer-file-name) load-file-name))
  "Base path for customised Emacs configuration")

(add-to-list 'load-path dotfiles-dir)

;; start a server, unless one is already running
(when (require 'server nil t)
  (unless (server-running-p)
    (server-start)))

(require 'init-utils)
(require 'init-paths)
(require 'init-backups)
(require 'init-editing)
(require 'init-packaging)

;; It is used to asynchonously load and configure other packages
(require 'init-use-package)

(defconst my-init-files
  '(init-evil
    init-icy
    init-ace-jump
    init-paredit
    init-smartparens
    init-uniquify
    init-emacs-lisp
    init-ediff
    init-eshell
    init-shell
    init-ido
    init-org
    init-highlight-parens
    init-colorscheme
    init-winner-mode
    init-dired
    init-helm
    init-fci
    init-haskell
    ;; init-ws-butler
    init-local)
  "List of init files to be loaded")

(my-require-list my-init-files)
(require 'evil-god)
;; These are easier in `god-mode'
(global-set-key (kbd "C-x C-1") 'delete-other-windows)
(global-set-key (kbd "C-x C-2") 'split-window-below)
(global-set-key (kbd "C-x C-3") 'split-window-right)
(global-set-key (kbd "C-x C-0") 'delete-window)

;; TODO:
(setq ssh-directory-tracking-mode t)
(put 'narrow-to-region 'disabled nil)
