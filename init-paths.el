;;; set up different path-related variables
;;; load-path, exec-path, PATH, etc.

(defconst modes-dotfiles-dir
  (eas-join-dirs dotfiles-dir "modes")
  "Configurations for built-in modes")
(add-to-list 'load-path modes-dotfiles-dir)
(defconst packages-dotfiles-dir
  (eas-join-dirs dotfiles-dir "packages")
  "Configurations for elpa packages")
(add-to-list 'load-path packages-dotfiles-dir)

;; tmp directory
(make-directory (setq tmp-local-dir (eas-join-dirs dotfiles-dir ".tmp")) t)

(provide 'init-paths)
