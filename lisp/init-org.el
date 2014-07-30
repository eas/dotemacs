(org-babel-do-load-languages
 'org-babel-load-languages
 '((python . t)
   (sh . t)
   (emacs-lisp . t)))

(setq org-src-fontify-natively t)
(setq org-log-done 'time)

(provide 'init-org)
