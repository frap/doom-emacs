;;; ui/modeline/+default.el -*- lexical-binding: t; -*-

;; This is a slimmed down version of `doom-modeline' that manipulates
;; `mode-line-format' directly. Its purpose is to be truer to the original goal
;; of Doom's modeline: to be more performant and minimalistic alternative to
;; other modeline packages and to be abstraction-light. Too much abstraction is
;; too much magic.
;;
;; Warning: this is still a WIP!

(defun +modeline--set-var-and-refresh-bars-fn (&optional symbol value)
  (when symbol
    (set-default symbol value))
  (when doom-init-time
    (+modeline-refresh-bars-h)))


;;
;;; Variables

(defcustom +modeline-height 31
  "The height of the modeline.

This is enforced by the xpm bitmap bar in `+modeline-bar'. Without it (and in
the terminal), this variable does nothing.

Use `setq!' to adjust this variable live, as it will trigger an refresh of the
bars in the modeline. `setq' will not."
  :type 'integer
  :set #'+modeline--set-var-and-refresh-bars-fn)

(defcustom +modeline-bar-width 3
  "The width of the bar in the modeline.

If nil, the bar will be made transparent and 1 pixel wide, as to be invisible,
but without sacrificing its ability to enforce `+modeline-height'.

Use `setq!' to adjust this variable live, as it will trigger an refresh of the
bars in the modeline. `setq' will not."
  :type 'integer
  :set #'+modeline--set-var-and-refresh-bars-fn)

(defvar +modeline-format-alist ()
  "An alist of modeline formats defined with `def-modeline!'.

Each entry's CAR is the name and CDR is a cons cell whose CAR is the left-hand
side of the modeline, and whose CDR is the right-hand side.")


;;
;;; Faces

(defface +modeline-bar '((t (:inherit highlight)))
  "Face used for left-most bar on the mode-line of an active window.")

(defface +modeline-bar-inactive '((t (:inherit mode-line-inactive)))
  "Face used for left-most bar on the mode-line of an inactive window.")

(defface +modeline-highlight
  '((t (:inherit mode-line-highlight)))
  "Face used for highlighted modeline panels (like search counts).")

(defface +modeline-alternate-highlight
  '((t (:inherit mode-line-highlight)))
  "Alternative face used for highlighted modeline panels (like search counts).")


;;
;;; Helpers

(defvar +modeline--redisplayed-p nil)
(defadvice! modeline-recalculate-height-a (&optional _force &rest _ignored)
  "Ensure that window resizing functions take modeline height into account."
  :before '(fit-window-to-buffer resize-temp-buffer-window)
  (unless +modeline--redisplayed-p
    (setq-local +modeline--redisplayed-p t)
    (redisplay t)))

;;; `active'
(defvar +modeline--active-window (selected-window))

(defun +modeline-active ()
  "Return non-nil if the selected window has an active modeline."
  (eq (selected-window) +modeline--active-window))

(add-hook! 'pre-redisplay-functions
  (defun +modeline-set-selected-window-h (&rest _)
    "Track the active modeline's window in `+modeline--active-window'."
    (let ((win (selected-window)))
      (unless (minibuffer-window-active-p win)
        (setq +modeline--active-window (frame-selected-window))))))

(defun +modeline--make-xpm (color width height)
  "Create an XPM bitmap via COLOR, WIDTH and HEIGHT. Inspired by `powerline''s `pl/+modeline--make-xpm'."
  (propertize
   " " 'display
   (let ((data (make-list height (make-list width 1)))
         (color (or color "None")))
     (ignore-errors
       (create-image
        (concat
         (format "/* XPM */\nstatic char * percent[] = {\n\"%i %i 2 1\",\n\". c %s\",\n\"  c %s\","
                 (length (car data))
                 (length data)
                 color
                 color)
         (apply #'concat
                (cl-loop with idx = 0
                         with len = (length data)
                         for dl in data
                         do (cl-incf idx)
                         collect
                         (concat "\""
                                 (cl-loop for d in dl
                                          if (= d 0) collect (string-to-char " ")
                                          else collect (string-to-char "."))
                                 (if (eq idx len) "\"};" "\",\n")))))
        'xpm t :ascent 'center)))))

(defun +modeline-format-icon (icon label &optional face help-echo voffset)
  (propertize (concat (all-the-icons-material
                       icon
                       :face face
                       :height 1.1
                       :v-adjust (or voffset -0.225))
                      (propertize label 'face face))
              'help-echo help-echo))

(defun set-modeline! (name &optional default)
  "Set the modeline to NAME.
If DEFAULT is non-nil, apply to all future buffers. Modelines are defined with
`def-modeline!'."
  (if-let (format (assq name +modeline-format-alist))
      (cl-destructuring-bind (lhs . rhs) (cdr format)
        (if default
            (setq-default +modeline-format-left lhs
                          +modeline-format-right rhs)
          (setq +modeline-format-left lhs
                +modeline-format-right rhs)))
    (error "Could not find %S modeline format" name)))

(defun set-modeline-hook! (hooks name)
  "Set the modeline to NAME on HOOKS.
See `def-modeline!' on how modelines are defined."
  (let ((fn (intern (format "+modeline-set-%s-format-h" name))))
    (dolist (hook (doom-enlist hooks))
      (add-hook hook fn))))

(defmacro def-modeline! (name lhs rhs)
  "Define a modeline format by NAME.
LHS and RHS are the formats representing the left and right hand side of the
mode-line, respectively. See the variable `format-mode-line' for details on what
LHS and RHS will accept."
  `(progn
     (setf (alist-get ',name +modeline-format-alist)
           (cons ,lhs ,rhs))
     (defun ,(intern (format "+modeline-set-%s-format-h" name)) (&rest _)
       "TODO"
       (set-modeline! ',name))))

(defmacro def-modeline-var! (name body &optional docstring &rest plist)
  "TODO"
  (unless (stringp docstring)
    (push docstring plist)
    (setq docstring nil))
  `(progn
     (,(if (plist-get plist :local) 'defvar-local 'defvar)
      ,name ,body ,docstring)
     (put ',name 'risky-local-variable t)))


;;
;;; Segments

(def-modeline-var! +modeline-format-left nil
  "The left-hand side of the modeline."
  :local t)

(def-modeline-var! +modeline-format-right nil
  "The right-hand side of the modeline."
  :local t)


;;; `+modeline-bar'
(progn
  (def-modeline-var! +modeline-bar "")
  (def-modeline-var! +modeline-inactive-bar "")

  (add-hook! '(doom-init-ui-hook doom-load-theme-hook) :append
    (defun +modeline-refresh-bars-h ()
      (let ((width (or +modeline-bar-width 1))
            (height (max +modeline-height 0)))
        (setq +modeline-bar
              (+modeline--make-xpm
               (and +modeline-bar-width
                    (face-background '+modeline-bar nil 'inherit))
               width height)
              +modeline-inactive-bar
              (+modeline--make-xpm
               (and +modeline-bar-width
                    (face-background '+modeline-bar-inactive nil 'inherit))
               width height)))))

  (add-hook! 'doom-change-font-size-hook
    (defun +modeline-adjust-height-h ()
      (defvar +modeline--old-height +modeline-height)
      (let ((default-height +modeline--old-height)
            (scale (or (frame-parameter nil 'font-scale) 0)))
        (setq +modeline-height
              (if (> scale 0)
                  (+ default-height (* (or (frame-parameter nil 'font-scale) 1)
                                       doom-font-increment))
                default-height))
        (when doom-init-time
          (+modeline-refresh-bars-h))))))


;;; `+modeline-matches'
(progn
  (use-package! anzu
    :after-call isearch-mode
    :config
    ;; anzu and evil-anzu expose current/total state that can be displayed in the
    ;; mode-line.
    (defadvice! +modeline-fix-anzu-count-a (positions here)
      "Calulate anzu counts via POSITIONS and HERE."
      :override #'anzu--where-is-here
      (cl-loop for (start . end) in positions
               collect t into before
               when (and (>= here start) (<= here end))
               return (length before)
               finally return 0))

    (setq anzu-cons-mode-line-p nil) ; manage modeline segment ourselves
    ;; Ensure anzu state is cleared when searches & iedit are done
    (add-hook 'isearch-mode-end-hook #'anzu--reset-status 'append)
    (add-hook 'iedit-mode-end-hook #'anzu--reset-status)
    (advice-add #'evil-force-normal-state :before #'anzu--reset-status)
    ;; Fix matches segment mirroring across all buffers
    (mapc #'make-variable-buffer-local
          '(anzu--total-matched anzu--current-position anzu--state
                                anzu--cached-count anzu--cached-positions anzu--last-command
                                anzu--last-isearch-string anzu--overflow-p)))

  (use-package! evil-anzu
    :when (featurep! :editor evil)
    :after-call (evil-ex-start-search evil-ex-start-word-search evil-ex-search-activate-highlight))

  (defun +modeline--anzu ()
    "Show the match index and total number thereof.
Requires `anzu', also `evil-anzu' if using `evil-mode' for compatibility with
`evil-search'."
    (when (and (bound-and-true-p anzu--state)
               (not (bound-and-true-p iedit-mode)))
      (propertize
       (let ((here anzu--current-position)
             (total anzu--total-matched))
         (cond ((eq anzu--state 'replace-query)
                (format " %d replace " anzu--cached-count))
               ((eq anzu--state 'replace)
                (format " %d/%d " here total))
               (anzu--overflow-p
                (format " %s+ " total))
               (t
                (format " %s/%d " here total))))
       'face (if (+modeline-active) '+modeline-highlight))))

  (defun +modeline--evil-substitute ()
    "Show number of matches for evil-ex substitutions and highlights in real time."
    (when (and (bound-and-true-p evil-local-mode)
               (or (assq 'evil-ex-substitute evil-ex-active-highlights-alist)
                   (assq 'evil-ex-global-match evil-ex-active-highlights-alist)
                   (assq 'evil-ex-buffer-match evil-ex-active-highlights-alist)))
      (propertize
       (let ((range (if evil-ex-range
                        (cons (car evil-ex-range) (cadr evil-ex-range))
                      (cons (line-beginning-position) (line-end-position))))
             (pattern (car-safe (evil-delimited-arguments evil-ex-argument 2))))
         (if pattern
             (format " %s matches " (how-many pattern (car range) (cdr range)))
           " - "))
       'face (if (+modeline-active) '+modeline-highlight))))

  (defun +modeline--multiple-cursors ()
    "Show the number of multiple cursors."
    (when (bound-and-true-p evil-mc-cursor-list)
      (let ((count (length evil-mc-cursor-list)))
        (when (> count 0)
          (let ((face (cond ((not (+modeline-active)) 'mode-line-inactive)
                            (evil-mc-frozen '+modeline-highlight)
                            ('+modeline-alternate-highlight))))
            (concat (propertize " " 'face face)
                    (all-the-icons-faicon "i-cursor" :face face :v-adjust -0.0575)
                    (propertize " " 'face `(:inherit (variable-pitch ,face)))
                    (propertize (format "%d " count)
                                'face face)))))))

  (defun +modeline--overlay< (a b)
    "Sort overlay A and B."
    (< (overlay-start a) (overlay-start b)))

  (defun +modeline--iedit ()
    "Show the number of iedit regions matches + what match you're on."
    (when (and (bound-and-true-p iedit-mode)
               (bound-and-true-p iedit-occurrences-overlays))
      (propertize
       (let ((this-oc (or (let ((inhibit-message t))
                            (iedit-find-current-occurrence-overlay))
                          (save-excursion
                            (iedit-prev-occurrence)
                            (iedit-find-current-occurrence-overlay))))
             (length (length iedit-occurrences-overlays)))
         (format " %s/%d "
                 (if this-oc
                     (- length
                        (length (memq this-oc (sort (append iedit-occurrences-overlays nil)
                                                    #'+modeline--overlay<)))
                        -1)
                   "-")
                 length))
       'face (if (+modeline-active) '+modeline-highlight))))

  (defun +modeline--macro-recording ()
    "Display current Emacs or evil macro being recorded."
    (when (and (+modeline-active)
               (or defining-kbd-macro
                   executing-kbd-macro))
      (let ((sep (propertize " " 'face '+modeline-highlight)))
        (concat sep
                (propertize (if (bound-and-true-p evil-this-macro)
                                (char-to-string evil-this-macro)
                              "Macro")
                            'face '+modeline-highlight)
                sep
                (all-the-icons-octicon "triangle-right"
                                       :face '+modeline-highlight
                                       :v-adjust -0.05)
                sep))))

  (def-modeline-var! +modeline-matches
    '(:eval
      (let ((meta (concat (+modeline--macro-recording)
                          (+modeline--anzu)
                          (+modeline--evil-substitute)
                          (+modeline--iedit)
                          (+modeline--multiple-cursors))))
        (or (and (not (equal meta "")) meta)
            " %I ")))))


;;; `+modeline-modes'
(def-modeline-var! +modeline-modes ; remove minor modes
  '(""
    (:propertize mode-name
                 face bold
                 mouse-face +modeline-highlight)
    mode-line-process
    "%n"
    " "))


;;; `+modeline-buffer-identification'
(def-modeline-var! +modeline-buffer-identification ; slightly more informative buffer id
  '((:eval
     (propertize
      (let ((buffer-file-name (buffer-file-name (buffer-base-buffer))))
        (or (when buffer-file-name
              (if-let (project (doom-project-root buffer-file-name))
                  (let ((filename (or buffer-file-truename (file-truename buffer-file-name))))
                    (file-relative-name filename (concat project "..")))))
            "%b"))
      'face (cond ((buffer-modified-p)
                   '(error bold mode-line-buffer-id))
                  ((+modeline-active)
                   'mode-line-buffer-id))
      'help-echo buffer-file-name))
    (buffer-read-only (:propertize " RO" face warning))))


;;; `+modeline-position'
(def-modeline-var! +modeline-position '("  %l:%C %p  "))


;;; `+modeline-checker'
(progn
  (def-modeline-var! +modeline-checker nil
    "Displays color-coded error status & icon for the current buffer."
    :local t)

  (add-hook! '(flycheck-status-changed-functions
               flycheck-mode-hook)
    (defun +modeline-checker-update (&optional status)
      "Update flycheck text via STATUS."
      (setq +modeline-checker
            (pcase status
              (`finished
               (if flycheck-current-errors
                   (let-alist (flycheck-count-errors flycheck-current-errors)
                     (let ((error (or .error 0))
                           (warning (or .warning 0))
                           (info (or .info 0)))
                       (+modeline-format-icon "do_not_disturb_alt"
                                              (number-to-string (+ error warning info))
                                              (cond ((> error 0)   'error)
                                                    ((> warning 0) 'warning)
                                                    ('success))
                                              (format "Errors: %d, Warnings: %d, Debug: %d"
                                                      error
                                                      warning
                                                      info))))
                 (+modeline-format-icon "check" "" 'success)))
              (`running     (+modeline-format-icon "access_time" "*" 'font-lock-comment-face "Running..."))
              (`errored     (+modeline-format-icon "sim_card_alert" "!" 'error "Errored!"))
              (`interrupted (+modeline-format-icon "pause" "!" 'font-lock-comment-face "Interrupted"))
              (`suspicious  (+modeline-format-icon "priority_high" "!" 'error "Suspicious")))))))


;;; `+modeline-selection-info'
(progn
  (defsubst +modeline--column (pos)
    "Get the column of the position `POS'."
    (save-excursion (goto-char pos)
                    (current-column)))

  (def-modeline-var! +modeline-selection-info
    '(:eval
      (when (or mark-active
                (and (bound-and-true-p evil-local-mode)
                     (eq evil-state 'visual)))
        (cl-destructuring-bind (beg . end)
            (if (boundp 'evil-local-mode)
                (cons evil-visual-beginning evil-visual-end)
              (cons (region-beginning) (region-end)))
          (propertize
           (let ((lines (count-lines beg (min end (point-max)))))
             (concat " "
                     (cond ((or (bound-and-true-p rectangle-mark-mode)
                                (and (bound-and-true-p evil-visual-selection)
                                     (eq 'block evil-visual-selection)))
                            (let ((cols (abs (- (+modeline--column end)
                                                (+modeline--column beg)))))
                              (format "%dx%dB" lines cols)))
                           ((and (bound-and-true-p evil-visual-selection)
                                 (eq evil-visual-selection 'line))
                            (format "%dL" lines))
                           ((> lines 1)
                            (format "%dC %dL" (- end beg) lines))
                           ((format "%dC" (- end beg))))
                     (when (derived-mode-p 'text-mode)
                       (format " %dW" (count-words beg end)))
                     " "))
           'face (if (+modeline-active) 'success)))))
    "Information about the current selection, such as how many characters and
lines are selected, or the NxM dimensions of a block selection.")

  (defun +modeline-add-selection-segment-h ()
    (add-to-list '+modeline-format-left '+modeline-selection-info 'append))
  (defun +modeline-remove-selection-segment-h ()
    (delq! '+modeline-selection-info +modeline-format-left))

  (if (featurep 'evil)
      (progn
        (add-hook 'evil-visual-state-entry-hook #'+modeline-add-selection-segment-h)
        (add-hook 'evil-visual-state-exit-hook #'+modeline-remove-selection-segment-h))
    (add-hook 'activate-mark-hook #'+modeline-add-selection-segment-h)
    (add-hook 'deactivate-mark-hook #'+modeline-remove-selection-segment-h)))


;;; `+modeline-encoding'
(def-modeline-var! +modeline-encoding
  '(:eval
    (concat (pcase (coding-system-eol-type buffer-file-coding-system)
              (0 " LF ")
              (1 " RLF ")
              (2 " CR "))
            (let ((sys (coding-system-plist buffer-file-coding-system)))
              (if (memq (plist-get sys :category)
                        '(coding-category-undecided coding-category-utf-8))
                  "UTF-8"
                (upcase (symbol-name (plist-get sys :name)))))
            "  ")))


;;
;;; Default modeline

(def-modeline! :main
  '(""
    +modeline-matches
    " "
    +modeline-buffer-identification
    +modeline-position)
  '(""
    mode-line-misc-info
    +modeline-modes
    (vc-mode ("  "
              ,(all-the-icons-octicon "git-branch" :v-adjust 0.0)
              vc-mode " "))
    " "
    +modeline-encoding
    (+modeline-checker ("" +modeline-checker "   "))))

(def-modeline! project
  `(" "
    ,(all-the-icons-octicon
      "file-directory"
      :face 'bold
      :v-adjust -0.05
      :height 1.25)
    (:propertize (" " (:eval (abbreviate-file-name default-directory)))
                 face bold))
  '("" +modeline-modes))

(def-modeline! special
  '("" +modeline-matches
    " " +modeline-buffer-identification)
  '("" +modeline-modes))

;; TODO (def-modeline! pdf ...)
;; TODO (def-modeline! helm ...)


;;
;;; Bootstrap

(size-indication-mode +1) ; filesize in modeline

(setq-default
 mode-line-format
 '(""
   +modeline-bar
   +modeline-format-left
   (:eval
    (propertize
     " "
     'display
     `((space :align-to (- (+ right right-fringe right-margin)
                           ,(string-width
                             (format-mode-line '("" +modeline-format-right))))))))
   +modeline-format-right))
(with-current-buffer "*Messages*"
  (setq mode-line-format (default-value 'mode-line-format)))


;; Other modes
(set-modeline! :main 'default)
(set-modeline-hook! '+doom-dashboard-mode-hook 'project)
(set-modeline-hook! 'pdf-tools-enabled-hook 'pdf)
(set-modeline-hook! '(special-mode-hook
                      image-mode-hook
                      circe-mode-hook)
                    'special)

(add-hook! 'magit-mode-hook
  (defun +modeline-init-project-or-hide-h ()
    (if (eq major-mode 'magit-status-mode)
        (set-modeline! 'project)
      (hide-mode-line-mode +1))))
