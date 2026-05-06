;;; magit-log-collapse.el --- Collapse regions in magit-log buffers -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This package provides functionality to collapse and expand commit ranges in
;; Magit log buffers, similar to how code folding works in editors.
;;
;; Key design decisions:
;; - Uses `display' property instead of `invisible' to avoid cursor movement issues
;; - Preserves git graph structure (|, /, \, *) when collapsing to maintain branch visibility
;; - Stores collapsed state in overlay properties for toggling
;; - Linear sequences detected by checking if commits have exactly 1 parent
;;
;; Main interactive commands:
;; - `my-magit-log-collapse-region' - Manually collapse selected commits
;; - `my-magit-log-collapse-all-linear' - Auto-collapse all linear sequences
;; - `my-magit-log-toggle-collapse-at-point' - Toggle collapsed/expanded state
;; - `my-magit-log-expand-all' - Expand all collapsed regions
;;
;; Implementation notes for AI agents:
;; - The overlay approach is non-destructive; buffer text is never modified
;; - Graph prefix extraction uses regex to match everything before the commit hash
;; - Graph-only lines (no hash) are preserved to maintain branch structure
;; - `magit-section' API is used to identify commit boundaries
;; - Cursor movement works naturally because we use `display', not `invisible'

;;; Code:

(require 'magit)
(require 'magit-log)

(defun my-magit-log-extract-graph-prefix (section)
  "Extract the graph prefix (e.g., '| * ', '* ', '|\\  ') from a commit section.

AI NOTE: This function extracts everything before the commit hash on the first
line of a commit section. The graph prefix includes characters like |, /, \\, *,
and spaces that form the visual branch structure. We need this to preserve the
graph appearance when replacing commits with a summary line."
  (save-excursion
    (goto-char (oref section start))
    (let ((line (buffer-substring-no-properties
                 (line-beginning-position)
                 (line-end-position))))
      ;; Primary match: everything before a 7+ char hex hash
      (if (string-match "^\\([^a-f0-9]*\\)[a-f0-9]\\{7,\\}" line)
          (match-string 1 line)
        ;; Fallback: just grab leading graph characters
        (if (string-match "^\\([ |*/\\\\]*\\)" line)
            (match-string 1 line)
          "")))))

(defun my-magit-log-extract-all-graph-lines (start-pos end-pos)
  "Extract all graph-only lines (no commit hash) from the region.
These are the lines that show branch structure between commits.

AI NOTE: In complex git graphs, there are lines between commits that contain
only graph structure characters (like '|\\  ' or '| |/  '). These lines are
critical for preserving the visual branch structure. We extract them and
include them in the collapsed display so users can still see how branches
relate even when commits are hidden.

Example: When collapsing commits with this structure:
  | * commit A
  | * commit B
  | |/
  * | commit C

We preserve the '| |/' line in the collapsed view."
  (let (graph-lines)
    (save-excursion
      (goto-char start-pos)
      (while (< (point) end-pos)
        (let ((line (buffer-substring-no-properties
                     (line-beginning-position)
                     (line-end-position))))
          ;; A graph-only line has NO commit hash but HAS graph chars
          (when (and (not (string-match "[a-f0-9]\\{7,\\}" line))
                     (string-match "^[ |*/\\\\]+" line)
                     (not (string-blank-p line)))
            (push line graph-lines)))
        (forward-line 1)))
    (nreverse graph-lines)))

(defun my-magit-log-build-collapsed-display (first-section sections)
  "Build the display text for a collapsed region, preserving graph structure.

AI NOTE: This is the core of the graph-preserving collapse feature. The key
insight is that we need TWO pieces of information:
1. The graph prefix from the first commit line (e.g., '| * ')
2. Any graph-only lines between commits in the range

We then build a multi-line replacement text:
- First line: <graph-prefix> + summary message
- Following lines: all the graph-structure lines we found

This way, collapsing '| * A, | * B, |/, * C' becomes '| ... 3 commits, |/'
instead of just '... 3 commits', preserving the branch merge visualization."
  (let* ((count (length sections))
         (first-pos (oref first-section start))
         (last-section (car (last sections)))
         (last-pos (oref last-section end))
         (first-prefix (my-magit-log-extract-graph-prefix first-section))
         (graph-lines (my-magit-log-extract-all-graph-lines first-pos last-pos))
         (summary-line (format "... %d commit%s collapsed (press RET to expand)"
                              count
                              (if (= count 1) "" "s"))))
    (if graph-lines
        ;; Complex case: preserve intermediate graph lines
        (concat first-prefix summary-line "\n"
                (mapconcat 'identity graph-lines "\n")
                "\n")
      ;; Simple case: just the summary line
      (concat first-prefix summary-line "\n"))))

(defun my-magit-log-collapse-region (beg end)
  "Collapse commits between BEG and END, showing 'N commits collapsed'.
The collapsed region can be expanded by pressing RET or TAB on the summary line.

AI NOTE: This is the manual/interactive collapse command. User selects a region
containing commit sections and calls this to collapse them.

Key implementation details:
- Uses `magit-region-sections' to get selected commits (requires active region)
- Creates an overlay spanning from first to last commit section
- Sets overlay's `display' property to our custom summary text
- Stores metadata in overlay properties for later toggling:
  * magit-collapsed: marker that this is our overlay
  * magit-collapsed-state: t=collapsed, nil=expanded
  * magit-collapsed-display: the summary text to show when collapsed
  * magit-collapsed-sections: original section list (for rebuilding if needed)
- Adds a local keymap to the overlay so RET/TAB work on the summary line
- CRITICAL: Use `display' property, NOT `invisible', to avoid cursor jump issues"
  (interactive "r")
  (unless (derived-mode-p 'magit-log-mode)
    (user-error "Not in a magit-log buffer"))
  (let* ((sections (magit-region-sections 'commit))
         (count (length sections)))
    (when (< count 2)
      (user-error "Need at least 2 commits to collapse"))
    (let* ((first-section (car sections))
           (last-section (car (last sections)))
           (start-pos (oref first-section start))
           (end-pos (oref last-section end))
           (ov (make-overlay start-pos end-pos))
           (summary-text (my-magit-log-build-collapsed-display first-section sections)))
      (overlay-put ov 'display
                   (propertize summary-text 'face 'magit-dimmed))
      (overlay-put ov 'evaporate t)
      (overlay-put ov 'magit-collapsed t)
      (overlay-put ov 'magit-collapsed-state t)
      (overlay-put ov 'magit-collapsed-count count)
      (overlay-put ov 'magit-collapsed-display summary-text)
      (overlay-put ov 'magit-collapsed-sections sections)
      (let ((map (make-sparse-keymap)))
        (define-key map (kbd "RET") #'my-magit-log-toggle-collapse-at-point)
        (define-key map (kbd "TAB") #'my-magit-log-toggle-collapse-at-point)
        (overlay-put ov 'keymap map))
      (deactivate-mark)
      (goto-char start-pos)
      (message "Collapsed %d commits" count))))

(defun my-magit-log-toggle-collapse-at-point ()
  "Toggle collapsed/expanded state of the region at point.

AI NOTE: This implements the toggle behavior. The overlay is never deleted,
we just switch between two states:

Collapsed state:
  - overlay's `display' property is set to summary text
  - overlay's `face' property is nil
  - `magit-collapsed-state' is t

Expanded state:
  - overlay's `display' property is nil (shows original buffer text)
  - overlay's `face' property is 'magit-dimmed (to indicate it's collapsible)
  - `magit-collapsed-state' is nil

This approach means the overlay persists and we don't need to re-detect
section boundaries or re-extract graph structure on each toggle."
  (interactive)
  (let ((ovs (overlays-at (point)))
        (found nil))
    (dolist (ov ovs)
      (when (overlay-get ov 'magit-collapsed)
        (let ((collapsed (overlay-get ov 'magit-collapsed-state)))
          (if collapsed
              ;; Currently collapsed, expand it
              (progn
                (overlay-put ov 'display nil)
                (overlay-put ov 'face 'magit-dimmed)
                (overlay-put ov 'magit-collapsed-state nil)
                (message "Expanded commits"))
            ;; Currently expanded, collapse it
            (let ((count (overlay-get ov 'magit-collapsed-count))
                  (summary-text (overlay-get ov 'magit-collapsed-display))
                  (ov-start (overlay-start ov)))
              ;; Move point to overlay start to avoid awkward jumping
              (when (and (>= (point) ov-start)
                         (< (point) (overlay-end ov)))
                (goto-char ov-start))
              (overlay-put ov 'display
                           (propertize summary-text 'face 'magit-dimmed))
              (overlay-put ov 'face nil)
              (overlay-put ov 'magit-collapsed-state t)
              (message "Collapsed %d commits" count))))
        (setq found t)))
    (unless found
      (user-error "No collapsible region at point"))))

(defalias 'my-magit-log-expand-at-point 'my-magit-log-toggle-collapse-at-point
  "Alias for backward compatibility.")

(defun my-magit-log-expand-all ()
  "Expand all collapsed regions in the current buffer."
  (interactive)
  (let ((count 0))
    (dolist (ov (overlays-in (point-min) (point-max)))
      (when (and (overlay-get ov 'magit-collapsed)
                 (overlay-get ov 'magit-collapsed-state))
        ;; Expand if currently collapsed
        (overlay-put ov 'display nil)
        (overlay-put ov 'face 'magit-dimmed)
        (overlay-put ov 'magit-collapsed-state nil)
        (setq count (1+ count))))
    (message "Expanded %d collapsed region%s" count (if (= count 1) "" "s"))))

(defun my-magit-log-get-commit-parents (hash)
  "Get parent hashes of commit HASH."
  (let ((parents-str (magit-git-string "rev-list" "--parents" "-n" "1" hash)))
    (when parents-str
      ;; Format is "hash parent1 parent2 ..." - skip first (the hash itself)
      (cdr (split-string parents-str)))))

(defun my-magit-log-is-linear-commit (hash)
  "Return t if HASH has exactly one parent (linear history).

AI NOTE: A 'linear' commit is one with exactly 1 parent. This means:
- NOT a merge commit (which has 2+ parents)
- NOT a root commit (which has 0 parents)
Consecutive linear commits form a sequence that's safe to collapse."
  (= 1 (length (my-magit-log-get-commit-parents hash))))

(defun my-magit-log-collect-commit-sections ()
  "Collect all commit sections from the current buffer in display order.

AI NOTE: Unlike `magit-region-sections', this function doesn't require an
active region. It walks through the entire buffer line-by-line and collects
all sections of type 'commit. This is needed for auto-collapse functionality
where we want to find ALL commits, not just selected ones."
  (let (commits)
    (save-excursion
      (goto-char (point-min))
      (let ((section (magit-current-section)))
        (while (not (eobp))
          (setq section (magit-current-section))
          (when (and section (eq (oref section type) 'commit))
            (push section commits))
          (forward-line 1))))
    (nreverse commits)))

(defun my-magit-log-find-linear-sequences ()
  "Find all linear sequences of commits in the current log buffer.
Returns a list of sequences, where each sequence is a list of commit sections.

AI NOTE: This is the core auto-detection logic. Algorithm:
1. Get all commit sections in the buffer
2. Walk through them in order, checking if each is linear
3. Build up a current sequence while commits are linear
4. When we hit a non-linear commit (merge/root), finish the current sequence
5. Only keep sequences with 2+ commits (collapsing 1 commit is pointless)

The result is a list of lists: [[seq1-commits], [seq2-commits], ...]"
  (let ((all-sections (my-magit-log-collect-commit-sections))
        sequences
        current-sequence)
    (dolist (section all-sections)
      (let ((hash (oref section value)))
        (if (my-magit-log-is-linear-commit hash)
            (push section current-sequence)
          (when (>= (length current-sequence) 2)
            (push (nreverse current-sequence) sequences))
          (setq current-sequence nil))))
    ;; Don't forget the last sequence if buffer ends with linear commits
    (when (>= (length current-sequence) 2)
      (push (nreverse current-sequence) sequences))
    (nreverse sequences)))

(defun my-magit-log-collapse-all-linear ()
  "Auto-detect and collapse all linear commit sequences.

AI NOTE: This is the 'auto-collapse' command. It finds all sequences of
linear commits (those with exactly 1 parent each) and collapses them
automatically. The implementation is essentially the same as manual collapse,
but applied to each detected sequence.

Important: This creates overlays for each sequence in a single pass. The
overlays don't interfere with each other because they cover non-overlapping
regions of the buffer."
  (interactive)
  (unless (derived-mode-p 'magit-log-mode)
    (user-error "Not in a magit-log buffer"))
  (let ((sequences (my-magit-log-find-linear-sequences))
        (total-collapsed 0))
    (if (null sequences)
        (message "No linear sequences found to collapse")
      (dolist (seq sequences)
        (let* ((count (length seq))
               (first-section (car seq))
               (last-section (car (last seq)))
               (start-pos (oref first-section start))
               (end-pos (oref last-section end))
               (ov (make-overlay start-pos end-pos))
               (summary-text (my-magit-log-build-collapsed-display first-section seq)))
          (overlay-put ov 'display
                       (propertize summary-text 'face 'magit-dimmed))
          (overlay-put ov 'evaporate t)
          (overlay-put ov 'magit-collapsed t)
          (overlay-put ov 'magit-collapsed-state t)
          (overlay-put ov 'magit-collapsed-count count)
          (overlay-put ov 'magit-collapsed-display summary-text)
          (overlay-put ov 'magit-collapsed-sections seq)
          (let ((map (make-sparse-keymap)))
            (define-key map (kbd "RET") #'my-magit-log-toggle-collapse-at-point)
            (define-key map (kbd "TAB") #'my-magit-log-toggle-collapse-at-point)
            (overlay-put ov 'keymap map))
          (setq total-collapsed (1+ total-collapsed))))
      (message "Collapsed %d linear sequence%s"
               total-collapsed
               (if (= total-collapsed 1) "" "s")))))

(defun my-magit-log-has-collapsed-regions-p ()
  "Return non-nil if any collapsed regions exist in the current buffer."
  (let ((has-collapsed nil))
    (dolist (ov (overlays-in (point-min) (point-max)))
      (when (and (overlay-get ov 'magit-collapsed)
                 (overlay-get ov 'magit-collapsed-state))
        (setq has-collapsed t)))
    has-collapsed))

(require 'transient)

(transient-define-suffix my-magit-log-toggle-collapse-all ()
  "Toggle between collapsed and expanded states.
If any regions are collapsed, expand all. Otherwise, collapse all linear sequences."
  :description (lambda ()
                 (if (my-magit-log-has-collapsed-regions-p)
                     "toggle collapse [collapsed]"
                   "toggle collapse [expanded]"))
  :key "z"
  :transient t
  (interactive)
  (unless (derived-mode-p 'magit-log-mode)
    (user-error "Not in a magit-log buffer"))
  (if (my-magit-log-has-collapsed-regions-p)
      (my-magit-log-expand-all)
    (my-magit-log-collapse-all-linear)))

;; Add to magit-log-refresh transient menu in the "Toggle" section
(with-eval-after-load 'magit-log
  (transient-append-suffix 'magit-log-refresh '(2 2 -1)
    '("z" my-magit-log-toggle-collapse-all)))

(provide 'magit-log-collapse)
;;; magit-log-collapse.el ends here
