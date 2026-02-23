;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!

;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

(setq doom-font (font-spec :family "FiraCode Nerd Font Mono" :size 18 :weight 'medium))
(setq doom-symbol-font (font-spec :family "Symbols Nerd Font Mono" :size 18))

;; Keep monospace font in zen mode (disable mixed-pitch)
(setq +zen-mixed-pitch-modes nil)

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; vterm: use zsh (Emacs defaults to bash via shell-file-name)
(after! vterm
  (setq vterm-shell (or (getenv "SHELL") "/usr/bin/zsh")))

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(when (file-directory-p "~/forge/")
  (setq org-directory "~/forge/")
  (setq +org-capture-todo-file "inbox/inbox.org")
  (setq +org-capture-notes-file "inbox/notes.org")
  (setq +org-capture-journal-file "journal/journal.org"))



;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

(require 'p4)

(map!
 "\C-x\C-m" #'execute-extended-command
 "\C-x\m"   #'execute-extended-command
 )

;; Always confirm before closing frame or quitting Emacs
(defun +save-buffers-kill-terminal-with-confirm ()
  "Like `save-buffers-kill-terminal' but always confirm first."
  (interactive)
  (when (y-or-n-p "Close this frame? ")
    (save-buffers-kill-terminal)))

(global-set-key (kbd "C-x C-c") #'+save-buffers-kill-terminal-with-confirm)

;; Copy buffer file path to kill ring (mirrors treemacs y a / y r)
(defun +copy-buffer-file-path-absolute ()
  "Copy current buffer's absolute file path to kill ring."
  (interactive)
  (if-let ((path buffer-file-name))
      (progn
        (kill-new path)
        (message "Copied: %s" path))
    (message "Buffer has no file")))

(defun +copy-buffer-file-path-relative ()
  "Copy current buffer's file path relative to project root."
  (interactive)
  (if-let ((path buffer-file-name))
      (let* ((root (or (projectile-project-root) default-directory))
             (rel (file-relative-name path root)))
        (kill-new rel)
        (message "Copied: %s" rel))
    (message "Buffer has no file")))

(map! "C-c y a" #'+copy-buffer-file-path-absolute
      "C-c y r" #'+copy-buffer-file-path-relative)

(setq auth-sources '("~/.authinfo.gpg"))

;; Justfile support: syntax highlighting + interactive recipe runner
(use-package! just-mode
  :mode ("justfile\\'" "\\.just\\'"))

(use-package! justl
  :defer t
  :config
  (map! :map justl-mode-map
        "e" #'justl-exec-recipe))

(defun +just/run ()
  "Run a just recipe in the current project."
  (interactive)
  (if-let ((root (or (projectile-project-root) default-directory)))
      (let ((default-directory root))
        (justl))
    (user-error "Not in a project")))

(map! "C-c j" #'+just/run)

;; Temp load local copies of agent-shell/acp for testing

(when (file-directory-p "/home/jaaron/dev/ref/acp.el")
  (add-to-list 'load-path "/home/jaaron/dev/ref/acp.el"))
(when (file-directory-p "/home/jaaron/dev/ref/agent-shell")
  (add-to-list 'load-path "/home/jaaron/dev/ref/agent-shell"))

;; Load Forge elisp modules
(when (file-directory-p "~/forge/src/elisp")
  (add-to-list 'load-path "~/forge/src/elisp")
  (require 'cautomaton-core)
  (require 'cautomaton-ai)
  (require 'cautomaton-capture)
  (require 'forge-backlog)
  (require 'forge-dev-status)
  (require 'forge-activity)
  (require 'cautomaton-worktree))

(after! magit (cautomaton-worktree-init))

;; J&T Project Elisp
(use-package! gongfu-mode
  :when (file-directory-p "~/dev/jmt/gongfu/tools/emacs/")
  :load-path "~/dev/jmt/gongfu/tools/emacs/"
  :mode "\\.gf\\'")

(after! ox-latex
  (when (file-exists-p "~/forge/src/templates/latex/install.el")
    (load! "~/forge/src/templates/latex/install.el")))


(after! org
  ;; Consolidated org-capture templates for Forge system
  (when (file-directory-p "~/forge/")
    (setq org-capture-templates
          (append org-capture-templates
                  '(("d" "Daily Journal" entry
                     (file+olp+datetree "~/forge/journal/journal.org")
                     (file "~/forge/src/templates/daily-template.org")
                     :empty-lines-before 1
                     :jump-to-captured t)
                    ("b" "Bookmark URL"
                     plain (file+headline "~/forge/inbox/bookmarks.org" "Bookmarks")
                     "%(org-cliplink-capture-with-topic)"
                     :empty-lines 1)
                    ("w" "Weekly Plan" entry
                     (file+headline "~/forge/journal/weekly.org" "Weeks")
                     (file "~/forge/src/templates/weekly-template.org")
                     :empty-lines-before 1
                     :jump-to-captured t)
                    ("a" "AI Daily Assistant" plain
                     (function cautomaton-copy-to-clipboard-target)
                     (file "~/forge/src/templates/ai-daily-prompt.org")
                     :immediate-finish t
                     :jump-to-captured nil))))))


(defun org-cliplink-capture ()
  "Capture a URL with its title and timestamp."
  (let* ((url (read-string "URL: "))
         (title (org-cliplink-retrieve-title-synchronously url))
         (time (format-time-string "[%Y-%m-%d %a %H:%M]")))
    (format "- %s [[%s][%s]]\n" time url title)))

(defun org-cliplink-capture-with-topic ()
  "Prompt for a URL and topic/tag, return formatted org list item with title."
  (let* ((url (read-string "URL: "))
         (topic (read-string "Topic/Tag (one word, optional): "))
         (title (org-cliplink-retrieve-title-synchronously url))
         (time (format-time-string "[%Y-%m-%d %a %H:%M]"))
         (tag (if (string-empty-p topic) "" (format " :%s:" topic))))
    (format "- %s [[%s][%s]]%s\n" time url title tag)))


(defun forge/weekly-review ()
  "Process for weekly review - opens relevant files and creates agenda view."
  (interactive)
  ;; Open current weekly plan
  (find-file "~/forge/journal/weekly.org")
  ;; Find this week's entry using proper ISO format
  (let ((week-id (format-time-string "%Y-W%V")))
    (goto-char (point-min))
    (re-search-forward week-id nil t))
  ;; Generate agenda view for the week
  (org-agenda nil "w")
  ;; Open inbox for processing
  (find-file-other-window "~/forge/inbox")
  (message "Ready for weekly review: Week %s plan, Inbox, and Agenda loaded"
           (format-time-string "%Y-W%V")))

(defun forge/goto-week (year week)
  "Navigate to a specific ISO week in the weekly.org file."
  (interactive
   (let* ((current-year (string-to-number (format-time-string "%Y")))
          (year (read-number "Year: " current-year))
          (max-week (if (= year current-year)
                        (string-to-number (format-time-string "%V"))
                      52))
          (week (read-number "Week: " max-week)))
     (list year week)))
  (find-file "~/forge/journal/weekly.org")
  (goto-char (point-min))
  (if (re-search-forward (format "\\* %d-W%02d" year week) nil t)
      (org-show-entry)
    (message "Week %d-W%02d not found." year week)))


;; ============================================================
;; Agent Shell - ACP-based AI Agent Interface
;; https://github.com/xenodium/agent-shell
;; Configured: 2025-12-18
;; ============================================================

;; ============================================================
;; Agent Shell Keybindings (C-c / prefix)
;; ============================================================
;;
;; All agent-related commands use C-c / as prefix:
;;
;;   C-c /     - Start/switch to default agent (Claude)
;;   C-c / /   - Same as above (double-tap)
;;   C-c / n   - Force new agent shell
;;   C-c / s   - Toggle sidebar
;;   C-c / m   - Toggle manager (shows all agents)
;;   C-c / ?   - Help menu (transient)
;;
;; Provider-specific:
;;   C-c / c   - Start Claude specifically
;;   C-c / x   - Start Codex specifically
;;   C-c / g   - Start Gemini specifically
;;
;; Note: C-c / conflicts with org-sparse-tree in org-mode.
;; Use M-x org-sparse-tree if needed.
;; ============================================================

(use-package! agent-shell
  :defer t
  :commands (agent-shell agent-shell-new-shell)
  :init
  ;; Main agent keybindings under C-c / prefix
  (map! "C-c /" #'agent-shell
        "C-c / /" #'agent-shell
        "C-c / n" #'agent-shell-new-shell
        "C-c / ?" #'agent-shell-help-menu)
  :config
  ;; Authentication: use login-based (opens browser on first use)
  (setq agent-shell-anthropic-authentication
        (agent-shell-anthropic-make-authentication :login t))

  ;; Set Claude as default agent (commented out to enable agent selection prompt)
  ;; (setq agent-shell-preferred-agent-config
  ;;       (agent-shell-anthropic-make-claude-code-config))

  ;; Inherit environment from Emacs (for PATH, devbox, etc.)
  (setq agent-shell-anthropic-claude-environment
        (agent-shell-make-environment-variables :inherit-env t))

  ;; OpenAI Codex authentication (login-based)
  (setq agent-shell-openai-authentication
        (agent-shell-openai-make-authentication :login t))

  ;; Provider-specific bindings (after agent-shell loads)
  (map! "C-c / c" #'agent-shell-anthropic-start-claude-code
        "C-c / x" #'agent-shell-openai-start-codex
        "C-c / g" #'agent-shell-google-start-gemini))

;; Dev environment integration for agent-shell
;; Automatically use nix/devbox environment if project has flake.nix or devbox.json
;; Priority: flake.nix > devbox.json (flake.nix is the newer preferred approach)
;;
;; Note: devbox run doesn't work because child processes (claude, bash)
;; don't inherit the devbox environment. We use devbox shellenv instead.
;;
;; We advise each provider's `make-*-client` function (not `agent-shell`)
;; because that's where the command variable is actually read. The client-maker
;; is called lazily, after any `let` bindings on `agent-shell` would have exited.

(defun +agent-shell--nix-wrap-command (orig-command project-root)
  "Wrap ORIG-COMMAND to run inside nix develop shell for PROJECT-ROOT."
  (let ((cmd (if (listp orig-command) (car orig-command) orig-command))
        (params (if (listp orig-command) (cdr orig-command) nil)))
    (list "bash" "-c"
          (format "cd %s && nix develop --command %s %s"
                  (shell-quote-argument project-root)
                  cmd
                  (mapconcat #'shell-quote-argument params " ")))))

(defun +agent-shell--devbox-wrap-command (orig-command project-root)
  "Wrap ORIG-COMMAND to run inside devbox shell for PROJECT-ROOT."
  (let ((cmd (if (listp orig-command) (car orig-command) orig-command))
        (params (if (listp orig-command) (cdr orig-command) nil)))
    (list "bash" "-c"
          (format "cd %s && eval \"$(devbox shellenv)\" && exec %s %s"
                  (shell-quote-argument project-root)
                  cmd
                  (mapconcat #'shell-quote-argument params " ")))))

(defun +agent-shell--with-devenv (command-var orig-fn &rest args)
  "Run ORIG-FN with COMMAND-VAR wrapped for nix/devbox if project has flake.nix or devbox.json.
Skips wrapping if already inside a nix shell (e.g., via direnv)."
  (let* ((project-root (or (projectile-project-root) default-directory))
         (flake-nix (expand-file-name "flake.nix" project-root))
         (devbox-json (expand-file-name "devbox.json" project-root))
         ;; IN_NIX_SHELL is set by nix develop/nix-shell
         (in-nix-shell (getenv "IN_NIX_SHELL"))
         ;; DEVBOX_PACKAGES_DIR is set by devbox shell/shellenv
         (in-devbox-shell (getenv "DEVBOX_PACKAGES_DIR")))
    (cond
     ;; Already in nix shell (via direnv or manual) - no wrapping needed
     ((and in-nix-shell (file-exists-p flake-nix))
      (apply orig-fn args))
     ;; Already in devbox shell - no wrapping needed
     ((and in-devbox-shell (file-exists-p devbox-json))
      (apply orig-fn args))
     ;; flake.nix takes precedence
     ((file-exists-p flake-nix)
      (let ((wrapped (+agent-shell--nix-wrap-command
                      (symbol-value command-var) project-root)))
        (cl-progv (list command-var) (list wrapped)
          (apply orig-fn args))))
     ;; Fall back to devbox.json
     ((file-exists-p devbox-json)
      (let ((wrapped (+agent-shell--devbox-wrap-command
                      (symbol-value command-var) project-root)))
        (cl-progv (list command-var) (list wrapped)
          (apply orig-fn args))))
     ;; No dev environment, run as-is
     (t (apply orig-fn args)))))

;; Claude (Anthropic)
(defun +agent-shell--claude-client-with-devenv (orig-fn &rest args)
  "Wrap Claude client creation for nix/devbox."
  (apply #'+agent-shell--with-devenv
         'agent-shell-anthropic-claude-command orig-fn args))
(advice-add 'agent-shell-anthropic-make-claude-client :around #'+agent-shell--claude-client-with-devenv)

;; Codex (OpenAI)
(defun +agent-shell--codex-client-with-devenv (orig-fn &rest args)
  "Wrap Codex client creation for nix/devbox."
  (apply #'+agent-shell--with-devenv
         'agent-shell-openai-codex-command orig-fn args))
(advice-add 'agent-shell-openai-make-codex-client :around #'+agent-shell--codex-client-with-devenv)

;; Gemini (Google)
(defun +agent-shell--gemini-client-with-devenv (orig-fn &rest args)
  "Wrap Gemini client creation for nix/devbox."
  (apply #'+agent-shell--with-devenv
         'agent-shell-google-gemini-command orig-fn args))
(advice-add 'agent-shell-google-make-gemini-client :around #'+agent-shell--gemini-client-with-devenv)

;; Agent Shell Sidebar - treemacs-style persistent side panel
;; Survives C-x 1 (delete-other-windows) like treemacs does
(use-package! agent-shell-sidebar
  :after agent-shell
  :commands (agent-shell-sidebar-toggle
             agent-shell-sidebar-toggle-focus
             agent-shell-sidebar-change-provider
             agent-shell-sidebar-reset)
  :init
  (map! "C-c / s" #'agent-shell-sidebar-toggle
        "C-c / f" #'agent-shell-sidebar-toggle-focus)
  :config
  ;; Use Claude as default sidebar agent
  (setq agent-shell-sidebar-default-config
        (agent-shell-anthropic-make-claude-code-config))
  ;; Position on right side (default)
  (setq agent-shell-sidebar-position 'right)
  ;; Width settings
  (setq agent-shell-sidebar-width "35%")
  (setq agent-shell-sidebar-minimum-width 80))

;; Agent Shell Manager - tabulated view of all sessions
(use-package! agent-shell-manager
  :after agent-shell
  :commands (agent-shell-manager-toggle)
  :init
  (map! "C-c / m" #'agent-shell-manager-toggle)
  :config
  ;; Display at bottom (default)
  (setq agent-shell-manager-side 'bottom))

;;; === Agent Multitasking ===

;; Make agent-shell-manager visible across ALL workspaces
(after! persp-mode
  (add-to-list 'persp-common-buffer-filter-functions
               (lambda (buf)
                 (string-match-p "\\*Agent-Shell Buffers\\*"
                                 (buffer-name buf)))))

;; Add agent-shell buffers to current perspective so they show in C-x b
(defun +agent-shell--add-to-perspective ()
  "Add current agent-shell buffer to current perspective."
  (when (bound-and-true-p persp-mode)
    (persp-add-buffer (current-buffer))))

(add-hook 'agent-shell-mode-hook #'+agent-shell--add-to-perspective)

;; Fix agent-shell-manager-goto to switch workspaces when needed
(defun +agent-shell-manager--extract-workspace (buffer)
  "Extract workspace name from agent-shell BUFFER name.
Buffer names are like 'Claude Code Agent @ ProjectName' or 'Claude Code Agent @ ProjectName<2>'."
  (let ((name (buffer-name buffer)))
    (when (string-match " @ \\([^<]+\\)\\(?:<[0-9]+>\\)?$" name)
      (match-string 1 name))))

(defun +agent-shell-manager-goto-with-workspace-switch ()
  "Go to agent-shell buffer, switching workspace if needed."
  (interactive)
  (when-let* ((buffer (tabulated-list-get-id)))
    (if (buffer-live-p buffer)
        (let ((buffer-window (get-buffer-window buffer nil)) ; nil = current frame only
              (workspace (+agent-shell-manager--extract-workspace buffer)))
          (cond
           ;; Buffer visible in current workspace - just switch to it
           (buffer-window
            (select-window buffer-window))
           ;; Buffer not visible - try switching workspace first
           (workspace
            (when (member workspace (persp-names))
              (+workspace/switch-to workspace))
            ;; Now display the buffer
            (if-let ((win (get-buffer-window buffer nil)))
                (select-window win)
              (pop-to-buffer buffer)))
           ;; No workspace info - fallback to default display
           (t
            (pop-to-buffer buffer))))
      (user-error "Buffer no longer exists"))))

(after! agent-shell-manager
  (define-key agent-shell-manager-mode-map (kbd "RET")
              #'+agent-shell-manager-goto-with-workspace-switch))

;; Kill protection for live agent sessions
(defun +agent-shell-confirm-kill ()
  "Confirm before killing buffer with live agent process."
  (if (and (bound-and-true-p agent-shell-mode)
           (get-buffer-process (current-buffer))
           (process-live-p (get-buffer-process (current-buffer))))
      (yes-or-no-p "Agent session running. Kill buffer? ")
    t))

(add-hook 'kill-buffer-query-functions #'+agent-shell-confirm-kill)

;; Silent revert when agents are editing files
;; When an agent-shell process modifies a file that has an open buffer,
;; Emacs prompts to revert. This blocks the agent until answered.
;; If a live agent-shell is running in the same project, skip the prompt.
(defun +agent-shell--in-project-p (file)
  "Return non-nil if a live agent-shell is running in FILE's project."
  (when (and file (fboundp 'agent-shell-buffers))
    (let ((dir (file-name-directory (expand-file-name file))))
      (seq-some
       (lambda (buf)
         (and (buffer-live-p buf)
              (get-buffer-process buf)
              (process-live-p (get-buffer-process buf))
              (let ((agent-dir (expand-file-name
                                (buffer-local-value 'default-directory buf))))
                (or (string-prefix-p agent-dir dir)
                    (string-prefix-p dir agent-dir)))))
       (agent-shell-buffers)))))

(defun +agent-shell--suppress-supersession (orig-fn filename &rest args)
  "Skip the supersession prompt when an agent is active in the same project.
Advises `ask-user-about-supersession-threat'."
  (if (+agent-shell--in-project-p filename)
      ;; Return nil to silently proceed (don't signal)
      nil
    (apply orig-fn filename args)))

(advice-add 'ask-user-about-supersession-threat
            :around #'+agent-shell--suppress-supersession)

;; Keybindings
;; NOTE: Leader-based bindings (SPC a) conflict with existing bindings
;; in non-evil Doom. Using C-c bindings instead:
;;   C-c .   → agent-shell
;;   C-c , m → agent-shell-manager-toggle
;; (map! :leader
;;       (:prefix ("a" . "agents")
;;        :desc "Agent shell" "a" #'agent-shell
;;        :desc "Manager" "m" #'agent-shell-manager-toggle
;;        :desc "Interrupt" "i" #'agent-shell-interrupt))


;; ============================================================
;; Project Switch: Open README + Treemacs
;; When switching projects via C-c p p, open README if present
;; and show Treemacs for the project.
;; ============================================================

(after! persp-mode
  (defun +workspace/switch-to-forge ()
    "Switch to forge workspace, creating it if necessary."
    (interactive)
    (if (member "forge" (+workspace-list-names))
        (+workspace-switch "forge")
      ;; Create by opening the project
      (projectile-switch-project-by-name "~/forge/")))

  (defun +workspace/reset-layout ()
    "Reset to canonical layout: treemacs | main | agent-shell, vterm at bottom."
    (interactive)
    (let* ((ws-bufs (+workspace-buffer-list))
           (agent-buf (seq-find (lambda (b)
                                  (with-current-buffer b
                                    (derived-mode-p 'agent-shell-mode)))
                                ws-bufs))
           (term-buf (seq-find (lambda (b)
                                 (with-current-buffer b
                                   (or (derived-mode-p 'vterm-mode)
                                       (derived-mode-p 'eshell-mode))))
                               ws-bufs))
           ;; Prefer README/backlog as "home base", else first file buffer
           (home-buf (seq-find (lambda (b)
                                 (when-let ((name (buffer-file-name b)))
                                   (string-match-p "\\(README\\.md\\|backlog\\.org\\)$" name)))
                               ws-bufs))
           (fallback-buf (seq-find (lambda (b)
                                     (and (buffer-file-name b)
                                          (not (eq b agent-buf))
                                          (not (eq b term-buf))))
                                   ws-bufs))
           (main-buf (or home-buf fallback-buf)))
      ;; Start fresh
      (delete-other-windows)

      ;; Main buffer in center (or scratch if none)
      (if main-buf
          (switch-to-buffer main-buf)
        (switch-to-buffer (doom-fallback-buffer)))

      ;; Treemacs on left
      (treemacs-add-and-display-current-project-exclusively)
      (other-window 1)

      ;; Agent shell on right (if exists in workspace)
      (when agent-buf
        (split-window-right)
        (other-window 1)
        (switch-to-buffer agent-buf)
        (other-window -1))

      ;; Terminal at bottom (if exists in workspace)
      (when term-buf
        (split-window-below -15)
        (other-window 1)
        (switch-to-buffer term-buf)
        (other-window -1))

      (message "Layout reset")))

  (map! "C-c w f" #'+workspace/switch-to-forge
        "C-c w R" #'+workspace/reset-layout)

  (defun +workspace/open-readme-and-treemacs (dir)
    "Open README if present in DIR, otherwise prompt for file. Then show Treemacs."
    (let* ((root (or dir (projectile-project-root)))
           (readmes '("README.md" "README.org" "README.rst" "README"))
           (readme (seq-find (lambda (f)
                               (file-exists-p (expand-file-name f root)))
                             readmes))
           (win (selected-window)))
      ;; Open README or fall back to file picker
      (if readme
          (find-file (expand-file-name readme root))
        (doom-project-find-file dir))
      ;; Show Treemacs for this project, keep focus on file
      (treemacs-add-and-display-current-project-exclusively)
      (when (window-live-p win)
        (select-window win))))

  (setq +workspaces-switch-project-function #'+workspace/open-readme-and-treemacs))


;; ============================================================
;; gptel - LLM Client for Programmatic Use
;; Used by solo-rpg and other custom LLM workflows
;; ============================================================

(use-package! gptel
  :defer t
  :config
  ;; Configure Ollama as default backend (local models)
  (setq gptel-model 'qwen3:8b
        gptel-backend (gptel-make-ollama "Ollama"
                        :host "localhost:11434"
                        :stream t
                        :models '(qwen3:8b qwen3:4b)))

  ;; Don't stream by default for programmatic use
  (setq gptel-stream nil))
