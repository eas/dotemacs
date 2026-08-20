;;; magit-llvm-check-context.el --- Preview LLVM functions for FileCheck diffs -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; `my-magit-llvm-check-context-mode' watches the point in Magit status, diff,
;; and revision ("show") buffers.  On a FileCheck directive it opens a small
;; side window containing the complete LLVM IR function that follows that
;; directive in the appropriate side of the diff.  Thus a removed CHECK is
;; resolved in the old blob, while an added or context CHECK is resolved in
;; the new blob/worktree.

;;; Code:

(require 'magit)
(require 'magit-diff)

(defgroup my-magit-llvm-check-context nil
  "Show LLVM function context for FileCheck lines in Magit."
  :group 'magit)

(defcustom my-magit-llvm-check-context-display-action
  '((display-buffer-in-side-window)
    (side . right)
    (slot . 1)
    (window-width . 0.45))
  "Action used to display the FileCheck function-context buffer."
  :type 'sexp
  :group 'my-magit-llvm-check-context)

(defconst my-magit-llvm-check-context--buffer-name
  "*Magit LLVM CHECK context*")

(defvar my-magit-llvm-check-context--displayed-from nil
  "Magit buffer currently responsible for the context window.")

(defvar-local my-magit-llvm-check-context--last-state nil
  "Point and modification tick for which context was last updated.")

(defvar-local my-magit-llvm-check-context--last-error nil
  "Reason the last context lookup in this Magit buffer failed.")

(defvar-local my-magit-llvm-check-context--run-prefix-cache nil
  "Cached (MODIFICATION-TICK . PREFIXES) for a visited source buffer.")

(defconst my-magit-llvm-check-context--directive-regexp
  "[[:alnum:]_][[:alnum:]_-]*\\(?:-\\(?:LABEL\\|NEXT\\|SAME\\|NOT\\|DAG\\|EMPTY\\|COUNT-[0-9]+\\)\\)?"
  "Regexp matching a FileCheck prefix together with an optional directive.")

(defun my-magit-llvm-check-context--hunk-heading-p ()
  "Return non-nil if point is on a unified-diff hunk heading with a function.

Git appends the function context after the second `@@' in a hunk heading; LLVM
IR test diffs therefore normally contain the complete `define' header there."
  (save-excursion
    (beginning-of-line)
    (looking-at "^@@ .* @@[ \t]+.*\\_<define\\_>")))

(defun my-magit-llvm-check-context--preview-trigger-p ()
  "Return non-nil if point is on a CHECK line or LLVM hunk heading."
  (or (my-magit-llvm-check-context--check-line-p)
      (my-magit-llvm-check-context--hunk-heading-p)))

(defun my-magit-llvm-check-context--directive-prefix (directive)
  "Return the FileCheck prefix part of DIRECTIVE.

For example, `COST-LABEL' and `COST-NEXT' have prefix `COST', while
`CHECK' and a custom bare `FOO' directive are their own prefixes."
  (replace-regexp-in-string
   "-\\(?:LABEL\\|NEXT\\|SAME\\|NOT\\|DAG\\|EMPTY\\|COUNT-[0-9]+\\)\\'"
   "" directive))

(defun my-magit-llvm-check-context--check-prefix-at-point ()
  "Return the FileCheck prefix on the current diff line, or nil."
  (save-excursion
    (beginning-of-line)
    (let ((case-fold-search nil))
      (when (looking-at
             (concat "^[-+ ][ \t]*;[ \t]*\\("
                     my-magit-llvm-check-context--directive-regexp
                     "\\)[ \t]*:"))
        (my-magit-llvm-check-context--directive-prefix (match-string-no-properties 1))))))

(defun my-magit-llvm-check-context--check-line-p ()
  "Return non-nil if the diff line at point looks like a FileCheck directive.

The prefix is verified against the visited source side's RUN lines before a
context is displayed.  Only actual diff body lines are accepted here, so hunk
and file headers cannot trigger a preview."
  (my-magit-llvm-check-context--check-prefix-at-point))

(defun my-magit-llvm-check-context--matching-brace (open)
  "Return the position after the closing brace matching OPEN, or nil.

This deliberately does not use `scan-sexps': Magit visits historical `.ll'
blobs in `fundamental-mode', where braces do not have parenthesis syntax."
  (save-excursion
    (goto-char open)
    (let ((depth 0))
      (catch 'end
        (while (not (eobp))
          ;; FileCheck directives are LLVM comments but commonly contain
          ;; literal `{` characters (notably CHECK-SAME: ... `{`).  They are
          ;; not part of the IR syntax and must not affect brace depth.
          (if (looking-at "^[ \t]*;")
              (forward-line 1)
            (let ((char (char-after)))
              (cond
               ((eq char ?{)
                (setq depth (1+ depth)))
               ((eq char ?})
                (setq depth (1- depth))
                (when (zerop depth)
                  ;; We have not moved over this closing brace yet.
                  (throw 'end (1+ (point))))))
              (forward-char))))
        nil))))

(defun my-magit-llvm-check-context--definition-comment-start (start)
  "Return the first comment or blank line immediately preceding START.

This retains human-authored test comments in the preview.  FileCheck comments
there are removed later by `my-magit-llvm-check-context--function-text'."
  (save-excursion
    (goto-char start)
    (let ((context-start start)
          (continue t))
      (while (and continue (> (line-beginning-position) (point-min)))
        (forward-line -1)
        (if (looking-at "^[ \t]*\\(?:;.*\\)?$")
            (setq context-start (line-beginning-position))
          (setq continue nil)))
      context-start)))

(defun my-magit-llvm-check-context--definition-bounds (start)
  "Return (START END NAME) for the LLVM definition starting at START.

START must point at the beginning of a `define' line.  The returned START also
includes immediately preceding comments; END includes the definition's braces."
  (save-excursion
    (goto-char start)
    ;; Find the function name first.  The first brace *after* it is the body
    ;; brace, so an aggregate return type cannot confuse this search.
    (when (re-search-forward
           "\\(@\\(?:[-$._[:alnum:]]+\\|\"[^\"]+\"\\)\\)[ \t\n\r]*("
           nil t)
      (let ((name (match-string-no-properties 1))
            (body-limit
             (save-excursion
               (when (re-search-forward
                      "^[ \t]*define\\(?:[ \t]\\|$\\)" nil t)
                 (match-beginning 0)))))
        (when (re-search-forward "{" body-limit t)
          (let* ((body-open (1- (point)))
                 (end (my-magit-llvm-check-context--matching-brace body-open)))
            (when end
              (list (my-magit-llvm-check-context--definition-comment-start start)
                    end name))))))))

(defun my-magit-llvm-check-context--function-bounds (position)
  "Return (START END NAME) for the LLVM function associated with POSITION.

First prefer the definition enclosing POSITION.  This handles the common LLVM
test layout where FileCheck comments occur after a `define' line, inside its
body.  If POSITION is not in a definition, use the next definition, supporting
check blocks immediately preceding the function they describe."
  (save-excursion
    (goto-char position)
    (let ((previous-definition
           (save-excursion
             (when (re-search-backward "^[ \t]*define\\(?:[ \t]\\|$\\)" nil t)
               (match-beginning 0)))))
      (or (when-let ((bounds
                      (and previous-definition
                           (my-magit-llvm-check-context--definition-bounds
                            previous-definition))))
            (and (<= (car bounds) position)
                 (< position (nth 1 bounds))
                 bounds))
          (when (re-search-forward "^[ \t]*define\\(?:[ \t]\\|$\\)" nil t)
            (my-magit-llvm-check-context--definition-bounds
             (match-beginning 0)))))))

(defun my-magit-llvm-check-context--default-check-prefix-p (prefix)
  "Return non-nil if PREFIX is a conventional CHECK prefix."
  (string-match-p "\\`CHECK[[:alnum:]_]*\\'" prefix))

(defun my-magit-llvm-check-context--run-commands ()
  "Return logical RUN commands in the current LLVM test buffer.

Only the usual semicolon, hash, and C++-style comment spellings are accepted.
Backslash-continued RUN lines are joined, so FileCheck options on a following
physical line are included."
  (save-excursion
    (goto-char (point-min))
    (let (commands command)
      (while (re-search-forward
              "^[ \t]*\\(?:;\\|#\\|//\\)[ \t]*RUN:[ \t]*\\(.*\\)$" nil t)
        (let* ((text (match-string-no-properties 1))
               (trimmed (string-trim-right text))
               (continued (string-suffix-p "\\" trimmed))
               (fragment (if continued
                             (string-trim-right (substring trimmed 0 -1))
                           text)))
          (setq command (concat command " " fragment))
          (unless continued
            (push (string-trim command) commands)
            (setq command nil))))
      ;; Parse a final incomplete command too: it is still useful while a
      ;; worktree RUN line is being edited.
      (when command
        (push (string-trim command) commands))
      (nreverse commands))))

(defun my-magit-llvm-check-context--filecheck-prefixes-in-command (command)
  "Return FileCheck prefixes selected by COMMAND.

Each FileCheck invocation without an explicit prefix option selects the
standard `CHECK' prefix.  Both singular and plural spellings, with either an
equals sign or a separate argument, are supported."
  (let ((start 0)
        prefixes)
    (while (string-match
            "\\(?:^\\|[ \t]\\)\\(?:\\(?:[^ \t]*/\\|%\\)?FileCheck\\)\\(?:\\.exe\\)?\\(?:[ \t]\\|$\\)"
            command start)
      (let* ((arguments-start (match-end 0))
             (next-command
              (string-match "\\(?:[|;]\\|&&\\)" command arguments-start))
             (arguments (substring command arguments-start next-command))
             (option-start 0)
             explicit-prefix)
        (while (string-match
                "\\(?:--\\|-\\)check-prefix\\(?:es\\)?\\(?:=\\|[ \t]+\\)\\([^ \t|;&]+\\)"
                arguments option-start)
          (let ((value (match-string-no-properties 1 arguments))
                (end (match-end 0)))
            (setq explicit-prefix t)
            (setq prefixes
                  (nconc prefixes (split-string value "," t)))
            ;; `split-string' can change match data, so retain END first.
            (setq option-start end)))
        (unless explicit-prefix
          (setq prefixes (nconc prefixes '("CHECK"))))
        (setq start (or next-command (length command)))))
    (delete-dups prefixes)))

(defun my-magit-llvm-check-context--run-check-prefixes ()
  "Return the FileCheck prefixes configured by this buffer's RUN lines.

The result is cached by modification tick.  Consequently this scans a source
buffer at most once per edit, rather than on every point movement in Magit."
  (let ((tick (buffer-chars-modified-tick)))
    (if (and my-magit-llvm-check-context--run-prefix-cache
             (equal (car my-magit-llvm-check-context--run-prefix-cache) tick))
        (cdr my-magit-llvm-check-context--run-prefix-cache)
      (let ((prefixes
             (delete-dups
              (apply #'append
                     (mapcar #'my-magit-llvm-check-context--filecheck-prefixes-in-command
                             (my-magit-llvm-check-context--run-commands))))))
        (setq my-magit-llvm-check-context--run-prefix-cache
              (cons tick prefixes))
        prefixes))))

(defun my-magit-llvm-check-context--function-text (start end check-prefixes)
  "Return source from START through END, without FileCheck comment lines.

Non-FileCheck comments immediately before and inside a function are retained.
Besides conventional CHECK prefixes, remove prefixes selected by actual RUN
lines in CHECK-PREFIXES."
  (replace-regexp-in-string
   (concat "^[ \t]*;[ \t]*\\("
           my-magit-llvm-check-context--directive-regexp
           "\\)[ \t]*:.*\n?")
   (lambda (line)
     (let ((prefix (my-magit-llvm-check-context--directive-prefix
                    (match-string 1 line))))
       (if (or (my-magit-llvm-check-context--default-check-prefix-p prefix)
               (member prefix check-prefixes))
           ""
         line)))
   (buffer-substring-no-properties start end)))

(defun my-magit-llvm-check-context--context-at-point ()
  "Return context data for the FileCheck line at point, or nil.

The returned value is (TEXT NAME FILE MODE SIDE).  SIDE is `old' for a
removed line and `new' otherwise.  Magit's own visit helper is used to map
point to the correct line in the correct revision, which also handles staged
and committed diffs.  Diagnostic text is stored separately in
`my-magit-llvm-check-context--last-error'; it must never be returned as a
context, because a non-empty string is truthy in Lisp."
  (setq my-magit-llvm-check-context--last-error nil)
  (let (context)
    (cond
     ((not (my-magit-llvm-check-context--preview-trigger-p))
      (setq my-magit-llvm-check-context--last-error
            "Point is not on a FileCheck directive or LLVM hunk heading"))
     ((not (magit-file-at-point))
      (setq my-magit-llvm-check-context--last-error
            "Magit could not determine the file for this diff line"))
     (t
      (let ((side (if (magit-diff-on-removed-line-p) 'old 'new))
            (file (magit-file-at-point))
            (active-prefix (my-magit-llvm-check-context--check-prefix-at-point)))
        (condition-case err
            (pcase-let ((`(,source-buffer ,source-position)
                         (magit-diff-visit-file--noselect)))
              (if (not source-position)
                  (setq my-magit-llvm-check-context--last-error
                        "Magit could not map this diff line to its source file")
                (with-current-buffer source-buffer
                  (save-restriction
                    (widen)
                    ;; Magit maps a hunk heading to the first changed line.
                    ;; The associated `define' is usually just above it, so
                    ;; the normal enclosing/next definition lookup applies.
                    ;; The source buffer is already visited for that lookup.
                    ;; RUN-prefix discovery is cached there by modification
                    ;; tick, making repeated post-command updates cheap.
                    (let ((check-prefixes
                           (my-magit-llvm-check-context--run-check-prefixes)))
                      (cond
                       ((and active-prefix
                             (not (member active-prefix check-prefixes)))
                        (setq my-magit-llvm-check-context--last-error
                              (format "`%s' is not selected by a FileCheck RUN line"
                                      active-prefix)))
                       ((if-let ((bounds
                                  (my-magit-llvm-check-context--function-bounds
                                   source-position)))
                            (pcase-let ((`(,start ,end ,name) bounds))
                              (setq context
                                    (list (my-magit-llvm-check-context--function-text
                                           start end check-prefixes)
                                          name file major-mode side))
                              t)
                          nil))
                       (t
                        (setq my-magit-llvm-check-context--last-error
                              "No LLVM `define' form encloses or follows this CHECK"))))))))
          (error
           (setq my-magit-llvm-check-context--last-error
                 (format "Magit could not visit the source: %s"
                         (error-message-string err))))))))
    context))

(defun my-magit-llvm-check-context--preview-mode (file)
  "Enable the major mode associated with FILE in `auto-mode-alist'.

Use the user's actual `.ll' association rather than guessing between
`llvm-mode' and `llvm-ts-mode'.  This also respects any local replacement
mode.  FILE is cleared after mode setup because the preview is not visiting
that file."
  (setq-local buffer-file-name file)
  (unwind-protect
      (set-auto-mode t)
    (setq-local buffer-file-name nil)))

(defun my-magit-llvm-check-context--render (context)
  "Render CONTEXT, as returned by `my-magit-llvm-check-context--context-at-point'."
  (pcase-let ((`(,text ,name ,file ,_source-mode ,side) context)
              (buffer (get-buffer-create my-magit-llvm-check-context--buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (my-magit-llvm-check-context--preview-mode file)
        ;; `insert' cannot accept a nil TEXT.  Keep the guard here even though
        ;; the normal lookup path always constructs TEXT from a buffer.
        (insert (or text ""))
        (goto-char (point-min))
        (when (fboundp 'font-lock-ensure)
          (font-lock-ensure))
        (setq-local header-line-format
                    (format " FileCheck context: %s (%s side) — %s"
                            (or file "unknown file") side name))
        (setq buffer-read-only t)))
    (let ((window (display-buffer buffer
                                  my-magit-llvm-check-context-display-action)))
      (set-window-point window (with-current-buffer buffer (point-min))))
  (setq my-magit-llvm-check-context--displayed-from (current-buffer))))

(defun my-magit-llvm-check-context--hide ()
  "Hide any displayed FileCheck function-context window."
  (when-let ((window
              (get-buffer-window my-magit-llvm-check-context--buffer-name)))
    (delete-window window))
  (setq my-magit-llvm-check-context--displayed-from nil))

(defun my-magit-llvm-check-context-update (&optional force)
  "Update the FileCheck function-context window for point.

This is suitable for `post-command-hook' and is also the interactive command
for manually refreshing the preview.  Interactively, report why no preview
was found instead of silently doing nothing.  With FORCE, ignore the cached
point state."
  (interactive "P")
  (let ((state (cons (point) (buffer-chars-modified-tick)))
        (interactivep (called-interactively-p 'interactive)))
    (when (or force interactivep
              (not (equal state my-magit-llvm-check-context--last-state)))
      (setq my-magit-llvm-check-context--last-state state)
      (if-let ((context (my-magit-llvm-check-context--context-at-point)))
          (progn
            (my-magit-llvm-check-context--render context)
            (when interactivep
              (message "Showing LLVM context for %s" (nth 1 context))))
        (my-magit-llvm-check-context--hide)
        (when interactivep
          ;; `user-error' is not reliable here with some UI frontends, which
          ;; expect its arguments in a different shape.  A normal message is
          ;; also preferable: not finding a nearby definition is expected for
          ;; non-LLVM files and should not interrupt the command loop.
          (message "%s" (or my-magit-llvm-check-context--last-error
                            "No FileCheck context found")))))))

;;;###autoload
(define-minor-mode my-magit-llvm-check-context-mode
  "Automatically preview the LLVM function for a FileCheck diff line.

Enable this in Magit status, diff, and revision buffers.  The preview tracks
point while it is on a `; CHECK...:' line and disappears elsewhere."
  :lighter nil
  (if my-magit-llvm-check-context-mode
      (progn
        (add-hook 'post-command-hook #'my-magit-llvm-check-context-update nil t)
        (my-magit-llvm-check-context-update))
    (remove-hook 'post-command-hook #'my-magit-llvm-check-context-update t)
    (my-magit-llvm-check-context--hide)))

(provide 'magit-llvm-check-context)
;;; magit-llvm-check-context.el ends here
