(setq ssh-program "Y:/apps/putty/plink.exe")
(setq ssh-explicit-args `("-i" "P:/.ssh/putty_key.ppk" "-l" "aeloviko"))
;; ssh-explicit-args also set to -X (via customize) to enable X forwarding to
;; Xming, which I start with:
;; "C:\Program Files (x86)\Xming\Xming.exe" :0 -clipboard -multiwindow
(defun my-fix-plink ()
  (interactive)
  (setq comint-process-echoes t)
  (setq comint-input-sender 'my-comint-simple-send)
  (setq-local comint-input-sender-no-newline t))

(add-hook 'ssh-mode-hook 'my-fix-plink)

(setq tramp-default-method "plink")


;; Cannot run it in hook
(defun my-comint-simple-send (proc string)
  "[Overrided] Default function for sending to PROC input STRING.
This just sends STRING plus a newline.  To override this,
set the hook `comint-input-sender'."
  (let ((send-string
         (if comint-input-sender-no-newline
             string
           ;; Sending as two separate strings does not work
           ;; on Windows, so concat the \n before sending.
           (concat string "\r")))) ; My change here \n -> \r
    (comint-send-string proc send-string))
  (if (and comint-input-sender-no-newline
       (not (string-equal string "")))
      (process-send-eof)))

(defun my-strip-double-newline (str)
  (replace-regexp-in-string "\n\n\\([^\n]\\)"
                            "\n\\1"
                            str))
;; (require 'tramp)
;; (set-default 'tramp-auto-save-directory "C:/Users/aeloviko/AppData/Local/Temp")
;; (set-default 'tramp-default-method ssh-program)
(provide 'init-plink)
