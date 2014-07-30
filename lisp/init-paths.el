;;; set up different path-related variables
;;; load-path, exec-path, PATH, etc.

(defconst my-ido-tmp-file
  (concat dotfiles-dir ".ido.last")
  "Where to store some ido data")

;; tmp directory
(make-directory (setq my-tmp-local-dir (my-join-dirs dotfiles-dir ".tmp")) t)
(setq custom-file "~/.emacs-custom.el")
(load custom-file)

;; TODO: init-recentf?
(setq recentf-exclude `(my-join-dirs dotfiles-dir "elpa"))

(provide 'init-paths)
