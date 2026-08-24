;;; my-llvm-cfg.el --- Render LLVM CFGs in a tmux pane -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Generate an LLVM CFG and show the rendered Graphviz image in a pane to the
;; right of the Emacs tmux pane.  Rendering is deliberately allowed only when
;; that window consists of Emacs and, optionally, an idle bash pane.  This
;; prevents the image viewer from taking over an unrelated pane.

;;; Code:

(defgroup my-llvm-cfg nil
  "Render LLVM control-flow graphs in tmux."
  :group 'tools)

(defcustom my-llvm-cfg-opt "~/llvm-project/build/bin/opt"
  "The `opt' binary used to generate CFG DOT files."
  :type 'file
  :group 'my-llvm-cfg)

(defcustom my-llvm-cfg-dot-program "dot"
  "Graphviz program used to render a DOT file."
  :type 'string
  :group 'my-llvm-cfg)

(defcustom my-llvm-cfg-imgcat-program "imgcat"
  "Program used in the tmux pane to display the rendered image."
  :type 'string
  :group 'my-llvm-cfg)

(defcustom my-llvm-cfg-tmp-directory "~/w/tmp/"
  "Directory in which generated CFG files are kept."
  :type 'directory
  :group 'my-llvm-cfg)

(defcustom my-llvm-cfg-pane-width "30%"
  "Width of the CFG pane passed to `tmux split-window'."
  :type 'string
  :group 'my-llvm-cfg)

(defconst my-llvm-cfg--bash-prompt-regexp
  (rx "[ " (* (not (any "\n"))) " " (= 2 digit) ":" (= 2 digit) ":"
      (= 2 digit) " ]" "\n" "$" (* (any " \t")) string-end)
  "Regexp matching the prompt installed by `my_ps' in ~/.profile.")

(defvar my-llvm-cfg--job nil
  "Process currently generating or rendering a CFG.")

(defun my-llvm-cfg--tmux-output (&rest arguments)
  "Run tmux with ARGUMENTS and return its standard output.
Signal an error when tmux fails, retaining its output in the diagnostic."
  (with-temp-buffer
    (let ((status (apply #'call-process "tmux" nil t nil arguments)))
      (unless (eq status 0)
        (error "tmux %s failed: %s"
               (mapconcat #'identity arguments " ")
               (string-trim (buffer-string))))
      (buffer-string))))

(defun my-llvm-cfg--idle-bash-pane-p (pane)
  "Return non-nil when PANE is at this configuration's idle bash prompt."
  (and (string=
        "bash"
        (string-trim
         (my-llvm-cfg--tmux-output
          "display-message" "-p" "-t" pane "#{pane_current_command}")))
       (string-match-p my-llvm-cfg--bash-prompt-regexp
                       (string-trim-right
                        (my-llvm-cfg--tmux-output
                         "capture-pane" "-p" "-t" pane)))))

(defun my-llvm-cfg--render-layout ()
  "Validate the current tmux window and return its CFG-pane layout.

The result is a plist containing `:current-pane', `:target-pane', and
`:zoomed'.  TARGET-PANE is nil when a new CFG pane must be created.  A
pre-existing target must be the one other pane in a two-pane window and must
be sitting at the user's idle bash prompt."
  (let ((current-pane (getenv "TMUX_PANE")))
    (unless current-pane
      (user-error "TMUX_PANE is not set; Emacs must be running inside tmux"))
    (let ((panes (split-string
                  (string-trim-right
                   (my-llvm-cfg--tmux-output
                    "list-panes" "-t" current-pane "-F" "#{pane_id}"))
                  "\n" t)))
      (unless (member current-pane panes)
        (error "tmux did not find Emacs pane %s in its window" current-pane))
      (pcase (length panes)
        (1
         (list :current-pane current-pane :target-pane nil
               :zoomed (string=
                        "1"
                        (string-trim
                         (my-llvm-cfg--tmux-output
                          "display-message" "-p" "-t" current-pane
                          "#{window_zoomed_flag}")))))
        (2
         (let (other-pane)
           (dolist (pane panes)
             (unless (equal pane current-pane)
               (setq other-pane pane)))
           (unless (my-llvm-cfg--idle-bash-pane-p other-pane)
             (user-error
              "The other tmux pane is not an idle bash prompt; refusing to replace it"))
           (list :current-pane current-pane :target-pane other-pane
                 :zoomed (string=
                          "1"
                          (string-trim
                           (my-llvm-cfg--tmux-output
                            "display-message" "-p" "-t" current-pane
                            "#{window_zoomed_flag}"))))))
        (_
         (user-error
          "The current tmux window has %d panes; expected Emacs and at most one idle bash pane"
          (length panes)))))))

(defun my-llvm-cfg--unzoom (layout)
  "Unzoom Emacs's tmux pane when LAYOUT reports it is zoomed."
  (when (plist-get layout :zoomed)
    (let ((pane (plist-get layout :current-pane)))
      (unless (eq 0 (call-process "tmux" nil nil nil
                                  "resize-pane" "-Z" "-t" pane))
        (error "Could not unzoom tmux pane %s" pane)))))

(defun my-llvm-cfg--discard-created-pane (pane)
  "Kill newly-created tmux PANE after an image-display setup failure."
  (when pane
    (call-process "tmux" nil nil nil "kill-pane" "-t" pane)))

(defun my-llvm-cfg--output-message (buffer format-string &rest args)
  "Report a failed CFG job, including output from BUFFER.
FORMAT-STRING and ARGS are passed to `message'."
  (let ((output (when (buffer-live-p buffer)
                  (with-current-buffer buffer
                    (string-trim (buffer-string))))))
    (message "%s%s"
             (apply #'format format-string args)
             (if (string-empty-p output) "" (concat "\n" output)))))

(defun my-llvm-cfg--display-image (image-file current-pane target-pane)
  "Display IMAGE-FILE in TARGET-PANE, creating it beside CURRENT-PANE if nil.
A supplied TARGET-PANE is reused, never killed: it was an already existing
idle bash pane when rendering started.  The target must be selected while
`imgcat' runs because the terminal graphics protocol relies on the active
pane.  Focus is restored afterwards."
  (let (created-pane)
    (unless target-pane
      (with-temp-buffer
        (let ((status
               (call-process "tmux" nil t nil
                             "split-window" "-h"
                             "-l" my-llvm-cfg-pane-width
                             "-P" "-F" "#{pane_id}"
                             "-t" current-pane)))
          (unless (eq status 0)
            (error "tmux split-window failed: %s"
                   (string-trim (buffer-string))))
          (setq target-pane (string-trim (buffer-string))
                created-pane target-pane))))
    ;; A newly-created pane is already selected.  Select a reused pane
    ;; explicitly before sending the graphics command.
    (unless (eq 0 (call-process "tmux" nil nil nil
                                "select-pane" "-t" target-pane))
      (when created-pane
        (my-llvm-cfg--discard-created-pane created-pane))
      (error "Could not select CFG tmux pane"))
    ;; Restore the original pane after `imgcat' exits so focus does not remain
    ;; in the CFG pane.
    (let ((command (format "%s %s; tmux select-pane -t %s"
                           my-llvm-cfg-imgcat-program
                           (shell-quote-argument image-file)
                           (shell-quote-argument current-pane))))
      (unless (eq 0 (call-process "tmux" nil nil nil
                                  "send-keys" "-t" target-pane command "C-m"))
        (when created-pane
          (my-llvm-cfg--discard-created-pane created-pane))
        (error "Could not send image command to tmux pane")))))

(defun my-llvm-cfg--dot-file (directory)
  "Return the DOT file generated in DIRECTORY, or nil.
A unique directory is used for every run, so selecting the first DOT file is
unambiguous even when `opt' chooses a function-dependent filename."
  (car (directory-files directory t "\\.dot\\'")))

(defun my-llvm-cfg--dot-sentinel
    (process _event directory output function current-pane target-pane)
  "Handle completion of the Graphviz PROCESS for FUNCTION."
  (when (memq (process-status process) '(exit signal))
    (setq my-llvm-cfg--job nil)
    (if (and (eq (process-status process) 'exit)
             (zerop (process-exit-status process)))
        (condition-case err
            (progn
              (my-llvm-cfg--display-image
               (expand-file-name "cfg.png" directory) current-pane target-pane)
              (message "Displaying CFG for %s" function))
          (error
           (my-llvm-cfg--output-message
            output "Could not open CFG pane: %s"
            (error-message-string err))))
      (my-llvm-cfg--output-message
       output "dot failed (status %s)"
       (process-exit-status process)))))

(defun my-llvm-cfg--opt-sentinel
    (process _event directory output function current-pane target-pane)
  "Handle completion of the `opt' PROCESS for FUNCTION."
  (when (memq (process-status process) '(exit signal))
    (setq my-llvm-cfg--job nil)
    (if (and (eq (process-status process) 'exit)
             (zerop (process-exit-status process)))
        (let ((dot-file (my-llvm-cfg--dot-file directory))
              (png-file (expand-file-name "cfg.png" directory)))
          (if (not dot-file)
              (my-llvm-cfg--output-message output "opt produced no DOT file")
            (setq my-llvm-cfg--job
                  (make-process
                   :name "my-llvm-cfg-dot"
                   :command (list my-llvm-cfg-dot-program
                                  "-Tpng" dot-file "-o" png-file)
                   :buffer output
                   :stderr output
                   :noquery t
                   :sentinel
                   (lambda (dot-process dot-event)
                     (my-llvm-cfg--dot-sentinel
                      dot-process dot-event directory output function
                      current-pane target-pane))))))
      (my-llvm-cfg--output-message
       output "opt failed (status %s)"
       (process-exit-status process)))))

(defun my-llvm-cfg--start-render
    (source-text function pass current-pane target-pane)
  "Generate and display PASS's CFG for FUNCTION from SOURCE-TEXT."
  (let* ((root (file-name-as-directory
                (expand-file-name my-llvm-cfg-tmp-directory)))
         (directory (progn
                      (make-directory root t)
                      ;; The directory argument is part of the template;
                      ;; the third argument to `make-temp-file' is a suffix,
                      ;; not a parent directory.
                      (make-temp-file (expand-file-name "llvm-cfg-" root) t)))
         (prefix (expand-file-name "cfg" directory))
         (output (generate-new-buffer "*my-llvm-cfg output*"))
         (opt (expand-file-name my-llvm-cfg-opt)))
    (unless (file-executable-p opt)
      (user-error "LLVM opt is not executable: %s" opt))
    (setq my-llvm-cfg--job
          (make-process
           :name "my-llvm-cfg-opt"
           :command (list opt
                          "-cfg-func-name" function
                          (concat "-cfg-dot-filename-prefix=" prefix)
                          "-p" pass
                          "-"
                          "-disable-output")
           :buffer output
           :stderr output
           :noquery t
           :sentinel
           (lambda (process event)
             (my-llvm-cfg--opt-sentinel
              process event directory output function current-pane target-pane))))
    ;; `opt -' reads the selected source from standard input.
    (process-send-string my-llvm-cfg--job source-text)
    (process-send-eof my-llvm-cfg--job)))

(defun my-llvm-cfg--source-text (region-or-buffer-or-file)
  "Return source text selected by REGION-OR-BUFFER-OR-FILE.
A region is a cons cell (START . END) in the current buffer; a buffer supplies
its accessible contents; and a string names a readable file."
  (cond
   ((and (consp region-or-buffer-or-file)
         (integer-or-marker-p (car region-or-buffer-or-file))
         (integer-or-marker-p (cdr region-or-buffer-or-file)))
    (let ((start (car region-or-buffer-or-file))
          (end (cdr region-or-buffer-or-file)))
      (unless (and (<= (point-min) start end) (<= end (point-max)))
        (user-error "CFG region is outside the accessible part of the current buffer"))
      (buffer-substring-no-properties start end)))
   ((bufferp region-or-buffer-or-file)
    (with-current-buffer region-or-buffer-or-file
      (buffer-substring-no-properties (point-min) (point-max))))
   ((stringp region-or-buffer-or-file)
    (unless (file-readable-p region-or-buffer-or-file)
      (user-error "Cannot read LLVM input file: %s" region-or-buffer-or-file))
    (with-temp-buffer
      (insert-file-contents region-or-buffer-or-file)
      (buffer-string)))
   (t
    (user-error
     "CFG input must be a region, buffer, or readable file name: %S"
     region-or-buffer-or-file))))

(defun my-llvm-cfg-render-cfg (region-or-buffer-or-file func &optional cfg-only)
  "Render FUNC's CFG from REGION-OR-BUFFER-OR-FILE in a tmux pane.

REGION-OR-BUFFER-OR-FILE is a region `(START . END)' in the current buffer, a
buffer, or a readable file name.  With CFG-ONLY non-nil use `dot-cfg-only';
otherwise use `dot-cfg'.  Interactively, use the active region or current
buffer, the LLVM function at point, and use `dot-cfg-only' with a prefix
argument.

The current tmux window must have exactly the Emacs pane, or that pane plus
one pane which is idle at the bash prompt configured by `my_ps'.  A zoomed
Emacs pane is unzoomed before the image pane is reused or created."
  (interactive
   (list (if (use-region-p)
             (cons (region-beginning) (region-end))
           (current-buffer))
         (my-get-cur-llvm-func)
         current-prefix-arg))
  (when (process-live-p my-llvm-cfg--job)
    (user-error "A CFG is already being generated"))
  (unless (and (stringp func) (not (string-empty-p func)))
    (user-error "CFG function name must be a nonempty string"))
  (let ((layout (my-llvm-cfg--render-layout))
        (source-text (my-llvm-cfg--source-text region-or-buffer-or-file)))
    (my-llvm-cfg--unzoom layout)
    (my-llvm-cfg--start-render
     source-text func (if cfg-only "dot-cfg-only" "dot-cfg")
     (plist-get layout :current-pane)
     (plist-get layout :target-pane))))

(provide 'my-llvm-cfg)
;;; my-llvm-cfg.el ends here
