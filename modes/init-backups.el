(setq
 my-tmp-backups-dir (my-join-dirs my-tmp-local-dir "backups")
 my-tmp-autosaves-dir (my-join-dirs my-tmp-local-dir "autosaves"))

(make-directory my-tmp-backups-dir t)
(make-directory my-tmp-autosaves-dir t)

(setq
 backup-by-copying t  ; Don't clobber symlinks
 backup-directory-alist `((".*" . ,my-tmp-backups-dir))
 auto-save-file-name-transforms `((".*" ,my-tmp-autosaves-dir t))
 delete-old-versions t
 kept-new-versions 6
 kept-old-versions 2
 version-control t)   ; Use versioned backups

(provide 'init-backups)
