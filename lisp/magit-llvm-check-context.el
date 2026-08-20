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
(require 'smerge-mode)

(defgroup my-magit-llvm-check-context nil
  "Show LLVM function context for FileCheck lines in Magit."
  :group 'magit)

(defcustom my-magit-llvm-check-context-display-action
  #'my-magit-llvm-check-context-display-action-dwim
  "Action used to display the FileCheck function-context buffer.

This may be a `display-buffer' action alist or a function returning one.  The
default function follows `dired-preview': it places the preview on the right
when the selected window is sufficiently wide, and below it otherwise.

A custom function is called with no arguments while the Magit window is
selected.  See `display-buffer' for the action-alist format."
  :type '(choice
          (alist :key-type
                 (choice :tag "Condition" regexp
                         (function :tag "Matcher function"))
                 :value-type sexp)
          (function :tag "Adaptive side or bottom"
                    my-magit-llvm-check-context-display-action-dwim)
          (function :tag "Custom display action function"))
  :risky t
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

(defvar-local my-magit-llvm-check-context--conflict-cache nil
  "Cached (MODIFICATION-TICK . CONFLICTS) for a visited source buffer.

Each entry in CONFLICTS starts with the bounds returned by
`smerge-match-conflict' and ends with the upper, base, and lower state labels.")

(defconst my-magit-llvm-check-context--directive-regexp
  "[[:alnum:]_][[:alnum:]_-]*\\(?:-\\(?:LABEL\\|NEXT\\|SAME\\|NOT\\|DAG\\|EMPTY\\|COUNT-[0-9]+\\)\\)?"
  "Regexp matching a FileCheck prefix together with an optional directive.")

(defun my-magit-llvm-check-context--preview-window-size (dimension)
  "Return a suitable preview-window size for DIMENSION.

This uses the same half-window policy as `dired-preview', while keeping a
right-hand preview wide enough for normally formatted source lines."
  (pcase dimension
    (:width (if-let* ((width (floor (window-total-width) 2))
                      ((>= width fill-column)))
                width
              fill-column))
    (:height (floor (window-height) 2))))

(defun my-magit-llvm-check-context--preview-window-side ()
  "Choose the side and size for an adaptive context preview.

Prefer the right side only when the selected window is wide enough according
to `split-width-threshold' and is not portrait-shaped; otherwise use the
bottom.  This is the placement policy used by `dired-preview'."
  (if-let* (split-width-threshold
            (width (window-body-width))
            ((>= width (window-body-height)))
            ((>= width split-width-threshold)))
      `(:side right :dimension window-width
              :size ,(my-magit-llvm-check-context--preview-window-size :width))
    `(:side bottom :dimension window-height
            :size ,(my-magit-llvm-check-context--preview-window-size :height))))

(defun my-magit-llvm-check-context-display-action-dwim ()
  "Return an adaptive `display-buffer' action alist for the context preview.

Use a right side window in a sufficiently wide Magit window and a bottom side
window otherwise.  This mirrors `dired-preview-display-action-alist-dwim'."
  (let ((properties (my-magit-llvm-check-context--preview-window-side)))
    `((display-buffer-in-side-window)
      (side . ,(plist-get properties :side))
      (,(plist-get properties :dimension) . ,(plist-get properties :size)))))

(defun my-magit-llvm-check-context--display-action ()
  "Return the configured `display-buffer' action for the context preview."
  (if (functionp my-magit-llvm-check-context-display-action)
      (funcall my-magit-llvm-check-context-display-action)
    my-magit-llvm-check-context-display-action))

(defun my-magit-llvm-check-context--hunk-heading-p ()
  "Return non-nil if point is on a unified-diff hunk heading with a function.

Git appends the function context after the second `@@' in a hunk heading; LLVM
IR test diffs therefore normally contain the complete `define' header there."
  (save-excursion
    (beginning-of-line)
    (looking-at "^@@ .* @@[ \t]+.*\\_<define\\_>")))

(defun my-magit-llvm-check-context--preview-trigger-p ()
  "Return non-nil if point is on a CHECK line, conflict marker, or LLVM hunk.

Conflict-marker lines remain associated with the surrounding function, so the
preview does not disappear while point moves between the alternatives of an
unresolved merge."
  (or (my-magit-llvm-check-context--check-line-p)
      (my-magit-llvm-check-context--conflict-marker-line-p)
      (my-magit-llvm-check-context--hunk-heading-p)))

(defun my-magit-llvm-check-context--directive-prefix (directive)
  "Return the FileCheck prefix part of DIRECTIVE.

For example, `COST-LABEL' and `COST-NEXT' have prefix `COST', while
`CHECK' and a custom bare `FOO' directive are their own prefixes."
  (replace-regexp-in-string
   "-\\(?:LABEL\\|NEXT\\|SAME\\|NOT\\|DAG\\|EMPTY\\|COUNT-[0-9]+\\)\\'"
   "" directive))

(defun my-magit-llvm-check-context--check-prefix-at-point ()
  "Return the FileCheck prefix on the current diff line, or nil.

Combined merge diffs have one leading diff marker per parent.  Consequently a
line which is changed relative to one parent starts, for example, with ` -' or
` +', rather than the single marker used by ordinary diffs."
  (save-excursion
    (beginning-of-line)
    (let ((case-fold-search nil))
      (when (looking-at
             (concat "^\\(?:[-+ ]\\)+[ \t]*;[ \t]*\\("
                     my-magit-llvm-check-context--directive-regexp
                     "\\)[ \t]*:"))
        (my-magit-llvm-check-context--directive-prefix (match-string-no-properties 1))))))

(defun my-magit-llvm-check-context--check-line-p ()
  "Return non-nil if the diff line at point looks like a FileCheck directive.

The prefix is verified against the visited source side's RUN lines before a
context is displayed.  Ordinary and combined-diff body lines are accepted;
the latter have multiple leading diff markers.  Hunk and file headers cannot
trigger a preview because they do not contain a FileCheck comment."
  (my-magit-llvm-check-context--check-prefix-at-point))

(defun my-magit-llvm-check-context--conflict-marker-state-at-point ()
  "Return the state label represented by the conflict marker at point.

For a diff3 conflict this returns the text following the relevant marker, e.g.
`HEAD' for `<<<<<<< HEAD', the merge-base SHA for `||||||| SHA', and the
other-side SHA or branch for `>>>>>>> SHA'.  The separator belongs to the
lower state, so its label is read from the following `>>>>>>>' marker.  This
keeps all three conflict states distinct rather than reducing them to old/new."
  (save-excursion
    (beginning-of-line)
    (cond
     ((looking-at "^[-+ ]*<<<<<<<[ \t]*\\(.*\\)$")
      (let ((state (string-trim (match-string-no-properties 1))))
        (if (string-empty-p state) "current" state)))
     ((looking-at "^[-+ ]*[|]\\{7\\}[ \t]*\\(.*\\)$")
      (let ((state (string-trim (match-string-no-properties 1))))
        (if (string-empty-p state) "base" state)))
     ((looking-at "^[-+ ]*>>>>>>>[ \t]*\\(.*\\)$")
      (let ((state (string-trim (match-string-no-properties 1))))
        (if (string-empty-p state) "incoming" state)))
     ((looking-at "^[-+ ]*=======")
      ;; `=======' starts the lower side.  Display the label from its closing
      ;; marker, which also makes it unambiguous in a three-way conflict.
      (when (re-search-forward "^[-+ ]*>>>>>>>[ \t]*\\(.*\\)$" nil t)
        (let ((state (string-trim (match-string-no-properties 1))))
          (if (string-empty-p state) "incoming" state)))))))

(defun my-magit-llvm-check-context--conflict-marker-line-p ()
  "Return non-nil if point is on a conflict-marker line in a diff.

Both ordinary and combined diffs prefix source text with one or more spaces,
pluses, and minuses, hence the marker is matched after that prefix."
  (my-magit-llvm-check-context--conflict-marker-state-at-point))

(defun my-magit-llvm-check-context--conflict-from-match ()
  "Return the current Smerge match as bounds plus its three state labels."
  (let ((start (match-beginning 0))
        (end (match-end 0))
        (upper-start (match-beginning 1))
        (upper-end (match-end 1))
        (base-start (match-beginning 2))
        (base-end (match-end 2))
        (lower-start (match-beginning 3))
        (lower-end (match-end 3)))
    (list start end upper-start upper-end base-start base-end lower-start lower-end
          (save-excursion
            (goto-char start)
            (my-magit-llvm-check-context--conflict-marker-state-at-point))
          (and base-start
               (save-excursion
                 (goto-char base-start)
                 (forward-line -1)
                 (my-magit-llvm-check-context--conflict-marker-state-at-point)))
          (save-excursion
            (goto-char lower-end)
            (my-magit-llvm-check-context--conflict-marker-state-at-point)))))

(defun my-magit-llvm-check-context--conflicts ()
  "Return cached Smerge conflict data for the current source buffer.

Smerge's `smerge-match-conflict' searches backward and forward through a
buffer.  Doing that from `post-command-hook' made ordinary point motion very
slow.  Scan at most once per buffer modification instead, including caching
an empty result for files without conflicts."
  (let ((tick (buffer-chars-modified-tick)))
    (if (and my-magit-llvm-check-context--conflict-cache
             (equal (car my-magit-llvm-check-context--conflict-cache) tick))
        (cdr my-magit-llvm-check-context--conflict-cache)
      (let (conflicts)
        (save-excursion
          (goto-char (point-min))
          (while (smerge-find-conflict)
            (push (my-magit-llvm-check-context--conflict-from-match) conflicts)))
        (setq conflicts (nreverse conflicts)
              my-magit-llvm-check-context--conflict-cache (cons tick conflicts))
        conflicts))))

(defun my-magit-llvm-check-context--conflict-state-at-position (position)
  "Return the cached conflict state containing POSITION, or nil.

The state is the text from the conflict's marker: the upper `<<<<<<<' state,
the diff3 base `|||||||' state, or the lower `>>>>>>>' state.  Marker lines
belong to their adjacent section: `<<<<<<<' to upper, `|||||||' to base, and
both `=======' and `>>>>>>>' to lower."
  (when-let ((conflict
              (seq-find (lambda (entry)
                          (and (<= (nth 0 entry) position)
                               (< position (nth 1 entry))))
                        (my-magit-llvm-check-context--conflicts))))
    (let ((start (nth 0 conflict))
          (upper-end (nth 3 conflict))
          (base-start (nth 4 conflict))
          (base-end (nth 5 conflict))
          (end (nth 1 conflict)))
      (cond
       ((and (<= start position) (< position upper-end)) (nth 8 conflict))
       ((and base-start (<= upper-end position) (< position base-end))
        (nth 9 conflict))
       ((and (<= (or base-end upper-end) position) (< position end))
        (nth 10 conflict))))))

(defun my-magit-llvm-check-context--conflict-at-point ()
  "Return cached conflict bounds for a conflict beginning at point, or nil.

The first eight values are (START END UPPER-START UPPER-END BASE-START
BASE-END LOWER-START LOWER-END).  Malformed or nested conflicts are omitted
from the cache and are left for the normal source parser."
  (when (looking-at "^<<<<<<< ")
    (seq-find (lambda (conflict) (= (car conflict) (point)))
              (my-magit-llvm-check-context--conflicts))))

(defun my-magit-llvm-check-context--conflict-selected-bounds (conflict position)
  "Return the variant in CONFLICT containing POSITION.

When POSITION is outside CONFLICT, use its upper variant.  That fallback is
needed for a CHECK block preceding a function whose body contains a conflict."
  (let* ((upper (cons (nth 2 conflict) (nth 3 conflict)))
         (base (cons (nth 4 conflict) (nth 5 conflict)))
         (lower (cons (nth 6 conflict) (nth 7 conflict)))
         (variants (list upper base lower)))
    (or (seq-find (lambda (bounds)
                    (and (car bounds) (cdr bounds)
                         (<= (car bounds) position) (< position (cdr bounds))))
                  variants)
        ;; A marker has no variant bounds of its own.  Pick the adjacent
        ;; variant matching its old/new meaning.  Outside the conflict, retain
        ;; the upper-side fallback for a CHECK block preceding the function.
        (cond
         ((and (<= (nth 0 conflict) position) (< position (car upper))) upper)
         ((and (car base) (<= (cdr upper) position) (< position (car base))) base)
         ((and (<= (or (cdr base) (cdr upper)) position) (< position (car lower))) lower)
         ((and (<= (cdr lower) position) (< position (nth 1 conflict))) lower)
         (t upper)))))

(defun my-magit-llvm-check-context--matching-brace (open &optional conflict-position)
  "Return the position after the closing brace matching OPEN, or nil.

This deliberately does not use `scan-sexps': Magit visits historical `.ll'
blobs in `fundamental-mode', where braces do not have parenthesis syntax.  If
CONFLICT-POSITION is in an unresolved conflict, scan only its selected variant;
otherwise braces in the alternate version could make the function unbalanced."
  (save-excursion
    (goto-char open)
    (let ((depth 0)
          selected-end
          conflict-end)
      (catch 'end
        (while (not (eobp))
          (cond
           ;; Skip from the end of the chosen side to the end marker, avoiding
           ;; braces and FileCheck lines in the alternate sides.
           ((and selected-end (>= (point) selected-end))
            (goto-char conflict-end)
            (setq selected-end nil
                  conflict-end nil))
           ((and conflict-position (looking-at "^<<<<<<< "))
            (if-let ((conflict (my-magit-llvm-check-context--conflict-at-point)))
                (pcase-let ((`(,variant-start . ,variant-end)
                             (my-magit-llvm-check-context--conflict-selected-bounds
                              conflict conflict-position)))
                  (goto-char variant-start)
                  (setq selected-end variant-end
                        conflict-end (nth 1 conflict)))
              (forward-line 1)))
           ;; FileCheck directives are LLVM comments but commonly contain
           ;; literal `{` characters (notably CHECK-SAME: ... `{`).  They are
           ;; not part of the IR syntax and must not affect brace depth.
           ((looking-at "^[ \t]*;")
            (forward-line 1))
           (t
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
        nil)))))

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

(defun my-magit-llvm-check-context--definition-bounds (start &optional conflict-position)
  "Return (START END NAME) for the LLVM definition starting at START.

START must point at the beginning of a `define' line.  The returned START also
includes immediately preceding comments; END includes the definition's braces.
CONFLICT-POSITION selects the relevant side of any unresolved conflict."
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
                 (end (my-magit-llvm-check-context--matching-brace
                       body-open conflict-position)))
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
                            previous-definition position))))
            (and (<= (car bounds) position)
                 (< position (nth 1 bounds))
                 bounds))
          (when (re-search-forward "^[ \t]*define\\(?:[ \t]\\|$\\)" nil t)
            (my-magit-llvm-check-context--definition-bounds
             (match-beginning 0) position))))))

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

(defun my-magit-llvm-check-context--conflict-free-text (start end position)
  "Return text from START through END with conflicts reduced to one variant.

Select the variant containing POSITION; conflicts elsewhere use the upper
variant.  This removes the `<<<<<<<', `|||||||', `=======', and `>>>>>>>'
markers as well as braces and comments belonging to the other variants."
  (save-excursion
    (goto-char start)
    (let (parts)
      (while (< (point) end)
        (if (looking-at "^<<<<<<< ")
            (if-let ((conflict (my-magit-llvm-check-context--conflict-at-point)))
                (pcase-let ((`(,variant-start . ,variant-end)
                             (my-magit-llvm-check-context--conflict-selected-bounds
                              conflict position)))
                  (push (buffer-substring-no-properties variant-start variant-end) parts)
                  (goto-char (nth 1 conflict)))
              ;; Preserve malformed conflicts verbatim rather than losing
              ;; source while the user is editing a marker.
              (let ((next (min end (line-beginning-position 2))))
                (push (buffer-substring-no-properties (point) next) parts)
                (goto-char next)))
          (let ((next (min end (line-beginning-position 2))))
            (push (buffer-substring-no-properties (point) next) parts)
            (goto-char next))))
      (apply #'concat (nreverse parts)))))

(defun my-magit-llvm-check-context--function-text (start end check-prefixes position)
  "Return source from START through END, without FileCheck comment lines.

Non-FileCheck comments immediately before and inside a function are retained.
Besides conventional CHECK prefixes, remove prefixes selected by actual RUN
lines in CHECK-PREFIXES.  Unresolved merge conflicts are reduced to the side
containing POSITION before the preview is rendered."
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
   (my-magit-llvm-check-context--conflict-free-text start end position)))

(defun my-magit-llvm-check-context--context-at-point ()
  "Return context data for the FileCheck line at point, or nil.

The returned value is (TEXT NAME FILE MODE STATE).  STATE is `old' for a
removed line and `new' otherwise; on a conflict marker, it is that marker's
state label (such as `HEAD' or a merge-base SHA).  Magit's own visit helper
is used to map
point to the correct line in the correct revision, which also handles staged
and committed diffs.  In a combined merge diff Magit maps every line to the
merge result, which is the appropriate common source for its parent-relative
colors.  Diagnostic text is stored separately in
`my-magit-llvm-check-context--last-error'; it must never be returned as a
context, because a non-empty string is truthy in Lisp."
  (setq my-magit-llvm-check-context--last-error nil)
  (let (context)
    (cond
     ((not (my-magit-llvm-check-context--preview-trigger-p))
      (setq my-magit-llvm-check-context--last-error
            "Point is not on a FileCheck directive, conflict marker, or LLVM hunk heading"))
     ((not (magit-file-at-point))
      (setq my-magit-llvm-check-context--last-error
            "Magit could not determine the file for this diff line"))
     (t
      (let ((side (or (my-magit-llvm-check-context--conflict-marker-state-at-point)
                      (if (magit-diff-on-removed-line-p) 'old 'new)))
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
                           (my-magit-llvm-check-context--run-check-prefixes))
                          ;; All lines in a conflict variant share its marker
                          ;; label, not just the marker line itself.
                          (side (or (my-magit-llvm-check-context--conflict-state-at-position
                                     source-position)
                                    side)))
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
                                           start end check-prefixes source-position)
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

(defun my-magit-llvm-check-context--context-windows (&optional frame)
  "Return context windows on FRAME, or all frames when FRAME is `t'.

Return nil when the context buffer has not been created yet.  In particular,
this is called while enabling the mode in a fresh Magit buffer, before a
preview has ever been rendered."
  (when-let ((buffer (get-buffer my-magit-llvm-check-context--buffer-name)))
    (get-buffer-window-list buffer nil frame)))

(defun my-magit-llvm-check-context--delete-extra-windows (windows keep)
  "Delete every live context window in WINDOWS except KEEP."
  (dolist (window windows)
    (unless (eq window keep)
      (when (window-live-p window)
        (delete-window window)))))

(defun my-magit-llvm-check-context--render (context)
  "Render CONTEXT, as returned by `my-magit-llvm-check-context--context-at-point'.

Reuse the existing context window before evaluating the adaptive display
policy.  Once a side window has narrowed the Magit window, reevaluating that
policy would otherwise choose the bottom and create a second context window."
  (pcase-let ((`(,text ,name ,file ,_source-mode ,state) context)
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
                    (format " FileCheck context: %s (%s revision) — %s"
                            (or file "unknown file") state name))
        (setq buffer-read-only t)))
    (let* ((existing (my-magit-llvm-check-context--context-windows
                      (selected-frame)))
           (window (or (car existing)
                       (display-buffer buffer
                                       (my-magit-llvm-check-context--display-action)))))
      ;; Clean up duplicate windows created by earlier versions of the adaptive
      ;; policy, and maintain the invariant that a frame has one preview.
      (my-magit-llvm-check-context--delete-extra-windows existing window)
      (set-window-point window (with-current-buffer buffer (point-min))))
  (setq my-magit-llvm-check-context--displayed-from (current-buffer))))

(defun my-magit-llvm-check-context--hide ()
  "Hide every displayed FileCheck function-context window."
  (my-magit-llvm-check-context--delete-extra-windows
   (my-magit-llvm-check-context--context-windows t) nil)
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
