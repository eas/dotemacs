(use-package ggtags
  :ensure
  :commands (ggtags-find-tag-dwim)
  :init
  (progn
    (define-key evil-motion-state-map "\C-]" 'ggtags-find-tag-dwim)))

(provide 'init-ggtags)
