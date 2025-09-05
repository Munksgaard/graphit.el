;; https://flonic.gitlab.io/org-blog/blog/emacs-transient-tutorial/index.html
;; https://old.reddit.com/r/emacs/comments/qyfr68/noob_transient_menu_tutorials/
;; https://emacs.stackexchange.com/questions/68534/add-custom-entry-to-magit-dispatch
;; https://github.com/positron-solutions/transient-showcase
;; https://magit.vc/manual/transient/Defining-Transients.html

(transient-define-prefix graphit-create ()
  "Create a new branch stacked on top of the current branch and commit staged changes. If no branch name is
specified, generate a branch name from the commit message. If your working directory contains no changes, an
empty branch will be created. If you have any unstaged changes, you will be asked whether you'd like to stage
them."
  :value '("--no-interactive")
  ["Global options"
   (cwd-option)
   (graphit-interactive-switches)]
  ["Commands"
   ("c" "create branch"         tsc-suffix-print-args)]
  [("q" "Quit"           transient-quit-one)])



(transient-define-argument graphit-interactive-switches ()
  "This is a specialized infix for selecting between interactive and non-interactive.
Be warned that interactive graphite commands are unlikely to work well."
  :description "Interacitivity"
  :class 'transient-switches
  :key "i"
  :argument-format "--%s"
  :argument-regexp "\\(--\\(no-interactive\\|interactive\\)\\)"
  :choices '("no-interactive" "interactive"))

(transient-define-suffix tsc-suffix-print-args (the-prefix-arg)
  "Report the PREFIX-ARG, prefix's scope, and infix values."
  :transient 'transient--do-call
  (interactive "P")
  (let ((args (transient-args (oref transient-current-prefix command)))
        (scope (oref transient-current-prefix scope)))
    (message "prefix-arg: %s \nprefix's scope value: %s \ntransient-args: %s"
             the-prefix-arg scope args)))

(transient-define-infix cwd-option ()
  :description "Working directory in which to perform operations."
  :class 'transient-option
  :shortarg "-cwd"
  :argument "--cwd=")

(transient-define-infix interactive-option ()
  :description "Working directory in which to perform operations."
  :class 'transient-option
  :shortarg "-cwd"
  :argument "--cwd=")

(defun graphit--quit-graphit ()
  "Kill the graphite buffer and exit."
  (interactive)
  (kill-buffer "*graphit*"))

(defun graphit--graphit-buffer-exists-p ()
  "Visibility predicate."
  (not (equal (get-buffer "*graphit*") nil)))

(transient-define-suffix graphit--graphit-clear-buffer (&optional buffer)
  "Delete the *graphit* buffer.  Optional BUFFER name."
  :transient 'transient--do-call
  :if 'tsc--cowsay-buffer-exists-p
  (interactive) ; todo look at "b" interactive code

  (save-excursion
    (let ((buffer (or buffer "*graphit*")))
      (set-buffer buffer)
      (delete-region 1 (+ 1 (buffer-size))))))

(defvar gt-with-editor-envvar "GIT_EDITOR")

(transient-define-suffix gt--create (the-prefix-arg)
  "Run gt create"
  (interactive "P")
  (let* ((args (transient-args (oref transient-current-prefix command)))
        (scope (oref transient-current-prefix scope))
        (buffer "*graphit*"))
    (message "prefix-arg: %s \nprefix's scope value: %s \ntransient-args: %s"
             the-prefix-arg scope args)
    (when (gt--graphit-buffer-exists-p)
      (gt--graphit-clear-buffer))
    (magit-with-editor (apply #'magit-start-process "gt" nil
                              (append '("create" "--no-interactive") args)))))

(transient-define-prefix gt-create ()
  "Create a new branch"
  :show-help (lambda (_)
               (transient-with-help-window
                 (process-file "gt" nil t nil "create" "--help")))
  ["Arguments"
   ("m" "message" "--message=")]
  ["Create a branch"
   ("c" "create branch" gt--create)])

(transient-define-suffix gt--log (the-prefix-arg)
  "Run gt log"
  (interactive "P")
  (message "gt-log"))

(transient-define-prefix gt-log ()
  "Shows the Graphite log"
  :show-help (lambda (_)
               (transient-with-help-window
                 (process-file "gt" nil t nil "log" "--help")))
  ["Log"
   ("l" "log" gt--log)])

;; Define the function to list branches using `gt ls`
(defun gt--list-branches ()
  "Run `gt ls` to list branches and return the output as a list of strings."
  (split-string (shell-command-to-string "gt ls") "\n" t))

;; Define the function to display branches in a buffer and allow selection
(defun gt--checkout-branch (branch)
  "Run `gt checkout BRANCH`."
  (message "Checking out branch: %s" branch)
  (magit-with-editor
   (magit-start-process "gt" nil (list "checkout" branch))))

(defun gt--select-branch ()
  "List branches and allow the user to select one for checkout."
  (let ((buffer "*gt-branches*")
        (branches (gt--list-branches)))
    (with-current-buffer (get-buffer-create buffer)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "Select a branch to checkout:\n\n")
        (dolist (branch branches)
          (insert (format "%s\n" branch)))
        (goto-char (point-min))
        (forward-line 2) ;; Skip the first two lines
        (gt--checkout-mode)))
    (pop-to-buffer buffer)))

;; Define the major mode for branch selection
(defvar gt--checkout-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'gt--checkout-select)
    (define-key map (kbd "q") #'gt--checkout-quit)
    (define-key map (kbd "<up>") #'previous-line)
    (define-key map (kbd "<down>") #'next-line)
    map)
  "Keymap for `gt--checkout-mode'.")

(define-derived-mode gt--checkout-mode special-mode "gt-checkout"
  "Major mode for selecting a branch to checkout."
  (setq buffer-read-only t)
  (setq-local cursor-type nil))

(defun gt--checkout-select ()
  "Select the branch at point and run `gt checkout`."
  (interactive)
  (let ((branch (string-trim (thing-at-point 'line t))))
    (gt--checkout-branch branch)
    (gt--checkout-quit)))

(defun gt--checkout-quit ()
  "Quit the branch selection buffer."
  (interactive)
  (kill-buffer))

;; Define the suffix for `gt checkout`
(transient-define-suffix gt--checkout (the-prefix-arg)
  "Run `gt ls` and allow the user to select a branch to checkout."
  (interactive "P")
  (gt--select-branch))

;; Define the prefix for `gt checkout`
(transient-define-prefix gt-checkout ()
  "Select a branch to checkout"
  :show-help (lambda (_)
               (transient-with-help-window
                 (process-file "gt" nil t nil "checkout" "--help")))
  ["Checkout Branch"
   ("b" "checkout branch" gt--checkout)])

;; Update the dispatch to include `gt-checkout`
(transient-define-prefix gt-dispatch ()
  "Invoke a Graphite command from a list of available commands."
  :show-help (lambda (_)
               (transient-with-help-window
                 (process-file "gt" nil t nil "--help")))
  ["Transient commands"
   ("c" "create" gt-create)
   ("o" "checkout" gt-checkout)])


;; (transient-define-prefix gt-dispatch ()
;;   "Invoke a Graphite command from a list of available commands."
;;   :show-help (lambda (_)
;;                (transient-with-help-window
;;                  (process-file "gt" nil t nil "--help")))
;;   ["Transient commands"
;;    ;; ("i" "init" gt-init)
;;    ("c" "create" gt-create)
;;    ;; ("S" "submit" gt-submit)
;;    ;; ("m" "modify" gt-modify)
;;    ;; ("s" "sync" gt-sync)
;;    ;; ("b" "checkout" gt-checkout)
;;    ("l" "log" gt-log)])

;; (transient-append-suffix 'magit-dispatch (kbd "f") '("G" "Graphite" gt-dispatch))
