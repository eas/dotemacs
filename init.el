;; General idea how to organize all initialization got from
;; https://github.com/bradleywright/emacs-d/blob/master/init.el


(add-to-list 'load-path (concat user-emacs-directory "lisp"))



;; start a server, unless one is already running
(when (require 'server nil t)
  (unless (server-running-p)
    (server-start)))

(require 'init-utils)
;; Configure all packages to store their data in that dir instead of `.emacs.d'
(make-directory (setq my-tmp-local-dir (my-join-dirs user-emacs-directory ".tmp")) t)

;; TODO: how to name this `init-*' file?

;; TODO: create file
(setq custom-file "~/.emacs-custom.el")
(load custom-file)

(setq recentf-exclude `(my-join-dirs dotfiles-dir "elpa"))


(require 'init-backups)
(require 'init-packaging)

;; It is used to asynchonously load and configure other packages
(require 'init-use-package)

(defconst my-init-files
  '(
    ;; Might be used in `use-package', probably should be
    ;; initialized first.
    init-diminish

    init-libs

    init-colorscheme
    init-editing
    init-evil
    init-undo-tree
    init-ace-jump

    init-highlight-parens
    init-paredit
    ;; init-smartparens
    init-fci
    init-eldoc
    ;; init-auto-complete
    init-company
    init-flycheck

    init-ido
    init-helm
    ;; init-icy
    init-dired
    init-windows-managing
    init-uniquify

    init-eshell
    init-shell
    init-ssh
    init-w3m

    init-ediff
    init-vc

    init-emacs-lisp
    init-org
    init-haskell
    ;; init-ws-butler
)
  "List of init files to be loaded")

(my-require-list my-init-files)

(add-to-list 'load-path (my-join-dirs user-emacs-directory "lisp-local"))
(let ((default-directory (my-join-dirs user-emacs-directory "site-lisp-local")))
  (normal-top-level-add-to-load-path '("."))
  (normal-top-level-add-subdirs-to-load-path))

(require 'init-local)

;; TODO:
(put 'narrow-to-region 'disabled nil)
