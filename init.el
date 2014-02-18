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
    init-paredit
    init-smartparens
    init-uniquify
    init-emacs-lisp
    init-ediff
    init-eshell
    init-ido
    init-highlight-parens
    init-colorscheme)
  "List of init files to be loaded")

(my-require-list my-init-files)
