;;; set up different path-related variables
;;; load-path, exec-path, PATH, etc.

(defconst my-modes-dotfiles-dir
  (my-join-dirs dotfiles-dir "modes")
  "Configurations for built-in modes")
(add-to-list 'load-path my-modes-dotfiles-dir)

(defconst my-packages-dotfiles-dir
  (my-join-dirs dotfiles-dir "packages")
  "Configurations for elpa packages")
(add-to-list 'load-path my-packages-dotfiles-dir)

(defconst my-ido-tmp-file
  (concat dotfiles-dir ".ido.last")
  "Where to store some ido data")

;; tmp directory
(make-directory (setq my-tmp-local-dir (my-join-dirs dotfiles-dir ".tmp")) t)
(setq custom-file "~/.emacs-custom.el")
(load custom-file)

(provide 'init-paths)
