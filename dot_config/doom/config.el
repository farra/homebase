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

;; GC tuning: GCMH's low threshold (used during timer/process-filter activity)
;; defaults to 800K, causing frequent 100ms+ GC pauses when agent-shell processes
;; and dashboard timers drive most of the allocation outside the command loop.
(after! gcmh
  (setq gcmh-low-cons-threshold (* 16 1024 1024)))  ; 16MB

;; vterm: use zsh (Emacs defaults to bash via shell-file-name)
(after! vterm
  (setq vterm-shell (or (getenv "SHELL") "/usr/bin/zsh")))

;; ghostel: terminal emulator on libghostty-vt — the daily driver as of
;; 2026-09. vterm (:term vterm) stays enabled as a fallback for now.
;; Ghostel tunes its own buffers (undo, font-lock, process read buffering,
;; hl-line); leave ghostel-timer-delay at its default — lowering it slows
;; bulk output. Check `describe-mode' in a ghostel buffer before tuning.
;; Native module is a prebuilt .so fetched from GitHub releases on first use.
;; It lives in straight's build dir, so every rebuild of ghostel deletes it;
;; auto-install is set to `download' so that is silent rather than a prompt.
;; ghostel comes from straight (latest), not Nix: nixpkgs lags upstream by a
;; few releases. If the prebuilt won't load, `M-x ghostel-module-compile'
;; (needs zig). Ghostel bundles + advertises its own terminfo to child
;; processes, so it's independent of the host xterm-ghostty terminfo.
(defun +ghostel/toggle (arg)
  "Toggle a ghostel popup at the project root, one per workspace.
Mirrors `+vterm/toggle'.  With prefix ARG, recreate the terminal."
  (interactive "P")
  (require 'ghostel)  ; so the let below binds the special var, not a local
  (let* ((name (format "*doom:ghostel-popup:%s*"
                       (if (bound-and-true-p persp-mode)
                           (safe-persp-name (get-current-persp))
                         "main")))
         (buf (get-buffer name)))
    (when (and arg (buffer-live-p buf))
      (let (kill-buffer-query-functions)
        (kill-buffer buf))
      (setq buf nil))
    (if-let* ((win (and buf (get-buffer-window buf))))
        ;; A popup made the sole window (e.g. after C-x 1) can't be deleted.
        (if (window-deletable-p win)
            (delete-window win)
          (with-selected-window win (bury-buffer)))
      (let ((default-directory (or (doom-project-root) default-directory))
            (ghostel-buffer-name name))
        (ghostel)))))

(defun +ghostel/here (arg)
  "Open this workspace's ghostel terminal in the current window.
Plain `ghostel' keys its buffer slot on `ghostel-buffer-name', so a single
*ghostel* is shared by every workspace; binding the name per workspace
gives each one its own.  ARG is passed through to `ghostel'.
Requires ghostel first: config.el is lexical, and before ghostel loads
`ghostel-buffer-name' isn't special yet, so the `let' would bind a local
that `ghostel' never sees (and loading ghostel inside it then errors)."
  (interactive "P")
  (require 'ghostel)
  (let ((ghostel-buffer-name
         (format "*ghostel:%s*"
                 (if (bound-and-true-p persp-mode)
                     (safe-persp-name (get-current-persp))
                   "main"))))
    (ghostel arg)))

;; org-semantic: search forge by meaning (or by word, with a prefix in the
;; prompt). The binary and index are forge's (`just vault-search-install',
;; `just vault-index'); agents use the same index through the vault-search skill.
;; forge vault/devenv/forge-vault-search.org
(use-package! org-semantic
  :when (file-executable-p "~/forge/.tools/org-semantic/org-semantic")
  :commands (org-semantic-find org-semantic-find-in-directory
             org-semantic-find-at-point org-semantic-reindex)
  :init
  (setq org-semantic-vault-root "~/forge/"
        org-semantic-executable (expand-file-name "~/forge/.tools/org-semantic/org-semantic"))
  (map! :leader
        :desc "Search notes by meaning" "n V" #'org-semantic-find)
  :hook (org-semantic-results-mode . next-error-follow-minor-mode))

(use-package! ghostel
  :commands (ghostel ghostel-project)
  :init
  (setq ghostel-module-auto-install 'download)
  ;; Doom only attaches "real" buffers to the current workspace
  ;; (`+workspaces-add-current-buffer-h'). :term vterm registers vterm-mode;
  ;; ghostel has no Doom module, so its buffers belonged to no workspace.
  (add-to-list 'doom-real-buffer-modes 'ghostel-mode)
  ;; ghostel takes Doom's terminal keys; vterm moves to o v / o V.
  ;; This runs after :config default, so it overrides the :term vterm bindings.
  (map! :leader
        :desc "Toggle ghostel popup"  "o t" #'+ghostel/toggle
        :desc "Open ghostel here"     "o T" #'ghostel-project
        :desc "Ghostel"               "o g" #'+ghostel/here
        :desc "Toggle vterm popup"    "o v" #'+vterm/toggle
        :desc "Open vterm here"       "o V" #'+vterm/here)
  (set-popup-rule! "^\\*doom:ghostel-popup"
    :size 0.25 :vslot -4 :select t :quit nil :ttl 0)
  :config
  (setq ghostel-shell (or (getenv "SHELL") "/usr/bin/zsh")))

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

;; p4's default prefix is C-x p, which replaces project.el's whole C-x p map
;; (C-x p g project-find-regexp, C-x p f, ...).  Move p4 to C-c 4.
(setq p4-global-key-prefix (kbd "C-c 4"))
(require 'p4)

(map!
 "\C-x\C-m" #'execute-extended-command
 "\C-x\m"   #'execute-extended-command
 )

;; Vibe Typer's "Plain Text" insertion sends C-S-v after setting the clipboard.
;; Unbound, it shift-translates to C-v (scroll), so dictation went nowhere.
;; agent-shell remaps yank to its image-aware agent-shell-yank-dwim.
(map! "C-S-v" #'yank)

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

;; Use Emacs minibuffer for GPG passphrase prompts instead of pinentry-curses
;; (which is broken in vterm/distrobox). Requires pinentry-program in gpg-agent.conf.
(use-package! pinentry
  :config
  (setq epa-pinentry-mode 'loopback)
  (pinentry-start))

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

;; Load Forge elisp modules
(when (file-directory-p "~/forge/src/elisp")
  (add-to-list 'load-path "~/forge/src/elisp")
  (require 'cautomaton-core)
  (require 'cautomaton-ai)
  (require 'cautomaton-capture)
  (require 'cautomaton-backlog)
  (require 'cautomaton-dev-status)
  (require 'cautomaton-activity)
  (require 'cautomaton-worktree))

(after! magit (cautomaton-worktree-init))

;; J&T Project Elisp
(use-package! gongfu-mode
  :when (file-directory-p "~/dev/jmt/gongfu/tools/emacs/")
  :load-path "~/dev/jmt/gongfu/tools/emacs/"
  :mode "\\.gf\\'")

;; C/C++ — mostly Unreal Engine (Retail Mage). Plan and rationale:
;; forge vault/devenv/emacs/14-emacs-explorations-2026-10.org (#unreal-cpp).

;; Never format C/C++ on save. With no .clang-format, apheleia — or clangd's
;; LSP formatting, which embeds clang-format — would rewrite Epic's
;; tab-indented style as LLVM style, in game trees that have no git.
;; Format by hand with Engine/Extras/clang-format/experimental.clang-format.
(add-to-list '+format-on-save-disabled-modes 'c-mode)
(add-to-list '+format-on-save-disabled-modes 'c++-mode)

;; UE headers are C++; don't let ambiguous .h files fall back to c-mode.
(setq +cc-default-header-file-mode 'c++-mode)

(after! lsp-clangd
  ;; Replaces Doom's "-j=<cpus/2>" (12 here): UE indexing is memory-heavy.
  (setq lsp-clients-clangd-args
        (list "-j=6"
              "--background-index"
              "--pch-storage=disk"
              "--header-insertion=never"
              "--header-insertion-decorators=0"
              "--completion-style=detailed"
              ;; Let clangd ask Epic's bundled clang for its system includes.
              (concat "--query-driver="
                      (expand-file-name "~/dev/jmt/retailmage/toolchain/")
                      "*/x86_64-unknown-linux-gnu/bin/clang++"))))

(defun +unreal-cc-h ()
  "Unreal Engine style for C++ buffers under Retail Mage.
Matches Epic's .editorconfig (tabs, width 4, 150 columns) and declares UE
reflection macros and module *_API export macros as cc-mode noise, so they
don't break indentation (tested: ~1 changed line per header vs 7-36)."
  (when (string-match-p "/dev/jmt/retailmage/" (or buffer-file-name ""))
    (setq-local c-basic-offset 4
                tab-width 4
                indent-tabs-mode t
                fill-column 150
                ;; UE trees are far past lsp-mode's file-watch limit.
                lsp-enable-file-watchers nil
                c-noise-macro-with-parens-names
                '("UCLASS" "USTRUCT" "UENUM" "UINTERFACE" "UPROPERTY"
                  "UFUNCTION" "UMETA" "UPARAM" "UDELEGATE")
                c-noise-macro-names
                (save-excursion
                  (goto-char (point-min))
                  (let (macros)
                    (while (re-search-forward "\\_<[A-Z0-9_]+_API\\_>" nil t)
                      (cl-pushnew (match-string-no-properties 0) macros
                                  :test #'equal))
                    macros)))
    (c-make-noise-macro-regexps)))
(add-hook 'c++-mode-hook #'+unreal-cc-h)

;; dape: attach gdb to the Unreal Editor. gdb runs inside the gamedev box, next
;; to the editor, through kit's in-gamedev.sh: the home box can't read the
;; editor's /proc entries, and its libraries resolve there. DAP passes through
;; distrobox's stdio byte-for-byte, and the boxes share a PID namespace, so a
;; PID found here is valid there (both checked 2026-10-06).
(defun +unreal-editor-pid ()
  "Return the PID of the running UnrealEditor, asking if there are several."
  (let ((pids (process-lines-ignore-status "pgrep" "-x" "UnrealEditor")))
    (string-to-number
     (pcase pids
       ('() (user-error "No UnrealEditor process is running"))
       (`(,pid) pid)
       (_ (completing-read "UnrealEditor PID: " pids nil t))))))

(after! dape
  (let ((in-gamedev (expand-file-name "~/dev/jmt/retailmage/kit/scripts/in-gamedev.sh")))
    (when (file-executable-p in-gamedev)
      (add-to-list 'dape-configs
                   `(gdb-unreal-attach
                     modes (c-mode c++-mode)
                     command ,in-gamedev
                     command-args ("gdb" "--interpreter=dap")
                     :request "attach"
                     :pid +unreal-editor-pid)))))

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


(defun cautomaton/weekly-review ()
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

(defun cautomaton/goto-week (year week)
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
;;   C-c / g   - Start Antigravity (Google) specifically
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

  ;; Start Claude sessions in auto mode (claude-agent-acp's "auto": a
  ;; classifier approves routine actions) instead of Manual.
  (setq agent-shell-anthropic-default-session-mode-id "auto")

  ;; Don't block system sleep during agent turns; Aaron manages sleep by
  ;; hand.  It needs the system D-Bus, which a daemon started without the
  ;; zshrc variable (278fcbe) can't reach, so it warned on every turn.
  (setq agent-shell-inhibit-system-sleep nil)

  ;; Set Claude as default agent (commented out to enable agent selection prompt)
  ;; (setq agent-shell-preferred-agent-config
  ;;       (agent-shell-anthropic-make-claude-code-config))

  ;; Inherit environment from Emacs (for PATH, devbox, etc.)
  (setq agent-shell-anthropic-claude-environment
        (agent-shell-make-environment-variables :inherit-env t))

  ;; OpenAI Codex authentication (login-based)
  (setq agent-shell-openai-authentication
        (agent-shell-openai-make-authentication :login t))

  ;; Store transcripts in forge vault, organized by project
  (setq agent-shell-transcript-file-path-function
        (lambda ()
          (let* ((project-name (file-name-nondirectory
                                (directory-file-name (agent-shell-cwd))))
                 (dir (expand-file-name
                       (concat "~/forge/vault/agent-shell/" project-name "/transcripts/")))
                 (filename (format-time-string "%F-%H-%M-%S.md")))
            (make-directory dir t)
            (expand-file-name filename dir))))

  ;; Provider-specific bindings (after agent-shell loads)
  ;; C-c / g drives Antigravity through Google's agy_acp_server, not the
  ;; `agy' CLI itself (which has no ACP mode). `homebase agent install acp'
  ;; puts agy_acp_server.par on PATH in ~/.local/bin.
  (map! "C-c / c" #'agent-shell-anthropic-start-claude-code
        "C-c / x" #'agent-shell-openai-start-codex
        "C-c / g" #'agent-shell-antigravity-start-agent))

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
         'agent-shell-anthropic-claude-acp-command orig-fn args))
(advice-add 'agent-shell-anthropic-make-claude-client :around #'+agent-shell--claude-client-with-devenv)

;; Codex (OpenAI)
(defun +agent-shell--codex-client-with-devenv (orig-fn &rest args)
  "Wrap Codex client creation for nix/devbox."
  (apply #'+agent-shell--with-devenv
         'agent-shell-openai-codex-acp-command orig-fn args))
(advice-add 'agent-shell-openai-make-codex-client :around #'+agent-shell--codex-client-with-devenv)

;; Antigravity (Google)
(defun +agent-shell--antigravity-client-with-devenv (orig-fn &rest args)
  "Wrap Antigravity client creation for nix/devbox."
  (apply #'+agent-shell--with-devenv
         'agent-shell-antigravity-acp-command orig-fn args))
(advice-add 'agent-shell-antigravity-make-client :around #'+agent-shell--antigravity-client-with-devenv)

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

;; ============================================================
;; agent-shell add-ons (trial 2026-10-16)
;; ============================================================
;; Notes: ~/forge/vault/devenv/emacs/17-agent-shell-addons-2026-10.org
;; hq and attention are both on trial, to compare against each other and
;; alongside the worktree dashboard (C-c . w).

;; hq: session sidebar workspace with live preview, and a posframe peek.
(use-package! agent-shell-hq
  :commands (agent-shell-hq-toggle agent-shell-hq-peek agent-shell-hq-label)
  :init
  (map! "C-c / h" #'agent-shell-hq-toggle
        "C-c / p" #'agent-shell-hq-peek))

;; A session's workflows and subagents, read from Claude's session files (ACP
;; doesn't report them).  forge src/elisp/cautomaton-agent-tasks.el.
(when (file-exists-p "~/forge/src/elisp/cautomaton-agent-tasks.el")
  (autoload 'cautomaton/agent-tasks "cautomaton-agent-tasks" nil t)
  (map! "C-c / t" #'cautomaton/agent-tasks))

;; attention: mode-line count of sessions waiting on Aaron, jump to the
;; oldest, a status-sorted dashboard, desktop notifications.
(use-package! agent-shell-attention
  :after agent-shell
  :init
  ;; C-c / a only visits sessions *awaiting* you (an unseen finished turn, or
  ;; a permission prompt); visiting clears "awaiting".  C-c / i goes to idle ones.
  (map! "C-c / a" #'agent-shell-attention-jump
        "C-c / i" #'agent-shell-attention-jump-idle
        "C-c / A" #'agent-shell-attention-dashboard)
  :config
  (setq agent-shell-attention-render-function #'agent-shell-attention-render-active
        agent-shell-attention-notify-function #'agent-shell-attention-notify-default)
  (agent-shell-attention-mode 1))

;; links: bookmarks and [[agent-shell:SESSION?agent=..&dir=..]] Org links
;; that reuse a live session or resume it.  Worklogs can link to sessions.
(use-package! agent-shell-links
  :defer t
  :init
  (after! bookmark (agent-shell-links-bookmark-setup))
  (after! ol
    (org-link-set-parameters "agent-shell"
                             :follow #'agent-shell-links-org-follow
                             :store #'agent-shell-links-org-store)))

;; recall: index, search and resume transcripts.  Ours live in
;; ~/forge/vault/agent-shell/<project>/transcripts/, not the default
;; <project>/.agent-shell/transcripts/.
(use-package! agent-recall
  :commands (agent-recall-search agent-recall-search-live agent-recall-browse
             agent-recall-browse-project agent-recall-resume agent-recall-reindex)
  :init
  (map! "C-c / r" #'agent-recall-search-live
        "C-c / R" #'agent-recall-browse)
  :config
  (setq agent-recall-search-paths '("~/forge/vault/agent-shell")
        agent-recall-transcript-dir-name "transcripts"
        agent-recall-max-depth 2
        agent-recall-search-function 'consult-ripgrep))

;; ob-agent-shell: #+begin_src agent-shell blocks run in the live session.
;; Doom's babel lazy-loader finds ob-agent-shell on first execution, so the
;; language needs no org-babel-do-load-languages entry.
(use-package! ob-agent-shell
  :defer t
  :init
  (after! org
    (add-to-list 'org-src-lang-modes '("agent-shell" . text))))

;; agent-shell-desktop is installed but NOT enabled: it restores sessions
;; through desktop-save-mode, which competes with Doom's persp-mode session
;; restore.  Trial it in a throwaway daemon first.


;; xenodium/emacs-skills helpers (/open, /select, /highlight, /dired) open files
;; with plain `find-file' in the selected window.  Called from an agent, that's
;; the agent's own window (agent-shell, or Claude in ghostel), so the
;; conversation gets replaced.  Run them in another window instead, and give
;; /highlight a face that's readable with doom-one (the plugin hard-codes
;; hi-yellow).  Advice, not edits: plugin updates overwrite its cache, and
;; nadvice keeps the advice through each call's re-`load' of the helper.
(defface +agent-skill-highlight
  '((((background dark)) :background "#4d4529" :extend t)
    (t :background "#fff1b8" :extend t))
  "Face for regions marked by the emacs-skills /highlight command.")

(defun +agent-skill-highlight-set-face (&rest _)
  "Soften the highlight: the theme's yellow blended 25% into the background."
  (when (and (fboundp 'doom-color) (doom-color 'yellow) (doom-color 'bg))
    (set-face-attribute '+agent-skill-highlight nil
                        :background (doom-blend 'yellow 'bg 0.25))))

(add-hook 'doom-load-theme-hook #'+agent-skill-highlight-set-face)

(defun +agent-skill--agent-window-p (w)
  "Non-nil if W shows an agent conversation or a terminal."
  (with-current-buffer (window-buffer w)
    (derived-mode-p 'agent-shell-mode 'ghostel-mode 'vterm-mode)))

(defun +agent-skill--home-window ()
  "The selected window of the GUI frame the user is in.
`emacsclient -e' may run with the daemon's terminal frame selected."
  (let ((w (selected-window)))
    (if (display-graphic-p (window-frame w))
        w
      (let* ((guis (seq-filter #'display-graphic-p (frame-list)))
             (f (or (seq-find (lambda (f) (eq (frame-focus-state f) t)) guis)
                    (car guis))))
        (if f (frame-selected-window f) w)))))

(defun +agent-skill--target-window ()
  "Where emacs-skills files should appear: never an agent's window.
Use the selected window unless it's an agent's; otherwise the widest
window that isn't an agent's, Treemacs, a side window, a popup or
dedicated; otherwise split one off to the right."
  (let ((home (+agent-skill--home-window)))
    (if (not (+agent-skill--agent-window-p home))
        home
      (or (car (sort (seq-remove
                      (lambda (w)
                        (or (+agent-skill--agent-window-p w)
                            (window-dedicated-p w)
                            (window-parameter w 'window-side)
                            (and (fboundp '+popup-window-p) (+popup-window-p w))
                            (with-current-buffer (window-buffer w)
                              (derived-mode-p 'treemacs-mode))))
                      (window-list (window-frame home) 'nomini))
                     (lambda (a b) (> (window-total-width a) (window-total-width b)))))
          (split-window home nil 'right)))))

(defun +agent-skill--restyle-highlights ()
  "Swap the plugin's hi-yellow for our face, and show the first region."
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (bound-and-true-p agent-skill-highlight-mode)
        (dolist (ov agent-skill-highlight--overlays)
          (overlay-put ov 'face '+agent-skill-highlight)))))
  (when (bound-and-true-p agent-skill-highlight--overlays)
    (goto-char (apply #'min (mapcar #'overlay-start agent-skill-highlight--overlays)))
    (recenter 2)))

(defun +agent-skill-in-other-window (fn &rest args)
  "Run emacs-skills helper FN with ARGS in a window that isn't an agent's.
Several files all land in the same window; the last one stays visible."
  (with-selected-window (+agent-skill--target-window)
    (prog1 (apply fn args)
      (+agent-skill--restyle-highlights))))

(defun +agent-skill-select-in-other-window (fn &rest args)
  "Like `+agent-skill-in-other-window', but leave the target window selected.
Emacs doesn't draw the region in unselected windows, so /select must move
focus to be seen."
  (select-window (+agent-skill--target-window))
  (apply fn args))

(dolist (fn '(agent-skill-highlight agent-skill-open agent-skill-dired))
  (advice-add fn :around #'+agent-skill-in-other-window))
(advice-add 'agent-skill-select :around #'+agent-skill-select-in-other-window)

;; Some apps (seen with Vibe Typer, 2026-10-16) hand Emacs their clipboard as
;; X11 compound text, which arrives undecoded: "’" shows up as ESC - F plus a
;; raw byte.  Raw bytes then break json-serialize, so a prompt pasted into
;; agent-shell never reaches the agent and the shell spins forever.  Decode
;; such pastes on yank.  Only strings that hold compound-text escapes and
;; whose only non-ASCII characters are raw bytes are touched.
(defun +yank-decode-compound-text (s)
  "Return S decoded as X11 compound text, if that's what it is."
  (if (and (string-match-p "\e[-$(),.]" s)
           (seq-some (lambda (c) (> c 127)) s)
           (seq-every-p (lambda (c) (or (< c 128) (eq (char-charset c) 'eight-bit))) s))
      (decode-coding-string (encode-coding-string s 'raw-text) 'compound-text)
    s))

(add-hook 'yank-transform-functions #'+yank-decode-compound-text)

;;; === Workspace autosave ===

;; Doom saves the workspace session only on a clean exit, so a daemon crash
;; loses every workspace made since the last restart (2026-10-16: an abort in
;; redisplay left a session file from that morning).  Save every few minutes,
;; but never when only placeholder workspaces exist: that would overwrite a
;; good session with an empty one (persp-mode keeps 3 backups).
(defun +workspace--worth-saving-p ()
  "Non-nil if some workspace has a real name (not main, none or #N)."
  (and (bound-and-true-p persp-mode)
       (cl-some (lambda (name)
                  (not (or (member name (list persp-nil-name +workspaces-main))
                           (string-match-p "\\`#[0-9]+\\'" name))))
                (persp-names-current-frame-fast-ordered))))

(defun +workspace/autosave-session ()
  "Save workspaces to Doom's quickload file, if any are worth saving."
  (when (+workspace--worth-saving-p)
    (let ((inhibit-message t))
      (persp-save-state-to-file))))

(defvar +workspace--autosave-timer nil)
(after! persp-mode
  (when (timerp +workspace--autosave-timer)
    (cancel-timer +workspace--autosave-timer))
  (setq +workspace--autosave-timer
        (run-with-timer 300 300 #'+workspace/autosave-session)))


;;; === emojify: no timers inside redisplay ===

;; `emojify-display-emojis-in-region' runs from jit-lock, inside redisplay,
;; and calls (sit-for 0 t) in its loop "to let with-timeout kick in".  sit-for
;; starts with (input-pending-p t), which runs any timer that's due.  So a timer
;; that edits the buffer being drawn (agent-shell-chat's zero-delay relabel,
;; scheduled on every streaming event) ran mid-redisplay, and redisplay read
;; from stale positions and aborted in bidi_get_type: the 2026-10-16/17 daemon
;; crashes (forge vault/devenv/incidents/2026-10-16-emacs-daemon-abort-bidi-redisplay.org).
;; Without sit-for, emojify still displays emoji; it only loses its 1s timeout.
(defun +emojify-no-sit-for-a (fn &rest args)
  "Call FN with ARGS with `sit-for' disabled, so no timer runs mid-redisplay."
  (cl-letf (((symbol-function 'sit-for) #'ignore))
    (apply fn args)))

(after! emojify
  (advice-add 'emojify-display-emojis-in-region :around #'+emojify-no-sit-for-a))

;;; === Crash watch (temporary) ===

;; Instrumentation for the 2026-10-16 redisplay aborts in agent-shell
;; (forge vault/devenv/incidents/2026-10-16-emacs-daemon-abort-bidi-redisplay.org):
;; breadcrumbs, invalid-character checks and an on-disk ACP traffic log, all in
;; ~/.cache.  Set `+crashwatch-enable' to nil (before this runs, or in a
;; machine-local file) to skip it; M-x cautomaton/crashwatch-stop turns it off
;; in a running daemon.  Remove this block once the bug is pinned.
(defvar +crashwatch-enable t
  "Non-nil to load and start forge's crash watch at startup.")

(defvar +crashwatch-file "~/forge/src/elisp/cautomaton-crashwatch.el"
  "Where the crash watch lives.")

(when (and +crashwatch-enable (file-exists-p +crashwatch-file))
  (load +crashwatch-file nil t)
  ;; One set of logs per daemon, so a second daemon (--fg-daemon=perf) doesn't
  ;; interleave with the main one.
  (let ((suffix (if (stringp (daemonp)) (concat "-" (daemonp)) "")))
    (setq cautomaton/crashwatch-log
          (expand-file-name (format "~/.cache/emacs-crashwatch%s.log" suffix))
          cautomaton/crashwatch-traffic-log
          (expand-file-name (format "~/.cache/emacs-acp-traffic%s.log" suffix))))
  (cautomaton/crashwatch-start))

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

;; Name each agent-shell buffer after its session title ("<title> @ <project>"),
;; so several sessions in one project are told apart by their work, not <N>.
;; claude-agent-acp generates the title once per session (a /rename replaces it)
;; and agent-shell re-fetches it on resume.  Keeps the " @ <project>" suffix that
;; `+agent-shell-manager--extract-workspace' parses.
(defun +agent-shell-title-buffer (&optional buffer)
  "Rename agent-shell BUFFER (default: current) after its session title."
  (with-current-buffer (or buffer (current-buffer))
    (when-let* ((title (map-nested-elt agent-shell--state '(:session :title)))
                (name (format "%s @ %s"
                              (truncate-string-to-width title 48 nil nil "…")
                              (agent-shell--project-name)))
                ((not (string-prefix-p name (buffer-name)))))
      (let ((shell (current-buffer))
            (viewport (get-buffer (concat (buffer-name) " [viewport]"))))
        (shell-maker-set-buffer-name shell name)
        (when (buffer-live-p viewport)
          (with-current-buffer viewport
            (rename-buffer (concat (buffer-name shell) " [viewport]") t)))))))

(defun +agent-shell-title-subscribe ()
  "Rename this agent-shell buffer whenever its session title changes."
  (let ((buffer (current-buffer)))
    (agent-shell-subscribe-to
     :shell-buffer buffer
     :event 'session-title-changed
     :on-event (lambda (_event)
                 (when (buffer-live-p buffer)
                   (+agent-shell-title-buffer buffer))))
    (+agent-shell-title-buffer buffer)))

(add-hook 'agent-shell-mode-hook #'+agent-shell-title-subscribe)

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

;; Mode-change protection for live agent sessions
;; Prevents accidentally invoking M-x vterm-mode (or any other major mode)
;; inside an agent-shell buffer, which destroys the shell-maker state and
;; creates an unkillable zombie buffer.
(defun +agent-shell-prevent-mode-change ()
  "Block major mode changes in agent-shell buffers with live processes."
  (when (and (bound-and-true-p agent-shell-mode)
             (get-buffer-process (current-buffer))
             (process-live-p (get-buffer-process (current-buffer))))
    (user-error "Cannot change major mode in a live agent-shell buffer")))

(add-hook 'change-major-mode-hook #'+agent-shell-prevent-mode-change)

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
    "Reset to canonical layout: treemacs | main | agent-shell, terminal at bottom."
    (interactive)
    (let* ((ws-bufs (+workspace-buffer-list))
           (agent-buf (seq-find (lambda (b)
                                  (with-current-buffer b
                                    (derived-mode-p 'agent-shell-mode)))
                                ws-bufs))
           (term-buf (seq-find (lambda (b)
                                 (with-current-buffer b
                                   (derived-mode-p '(ghostel-mode vterm-mode
                                                     eshell-mode))))
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


;; C-c s v: ripgrep the whole forge vault from anywhere (Doom's C-c s map has
;; buffer, project and directory search, but nothing project-independent).
(defun +search/forge-vault ()
  "Search ~/forge/vault with consult-ripgrep."
  (interactive)
  (consult-ripgrep (expand-file-name "~/forge/vault")))
(map! "C-c s v" #'+search/forge-vault)

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


;; ============================================================
;; markdown-mode: cache inline-code spans
;; ============================================================
;; `markdown-inline-code-at-pos' rescans its whole text block from the start
;; for every bold/italic/link candidate, so dense blocks cost quadratic time:
;; a 36KB block in the gongfu keyword worksheet took 12s per keystroke
;; (2.6M `markdown-match-code' calls).  This is the version prepared for
;; upstream (~/dev/ref/markdown-mode, branch fix/inline-code-span-cache):
;; same results and match data as the original (identical faces on 679
;; files), cached per block until the text changes.  Upstream issues:
;; jrblevin/markdown-mode #391, #691, #799.  Notes:
;; ~/forge/vault/devenv/emacs/16-markdown-mode-pr-inline-code-cache.org.
;; Drops itself once upstream ships `markdown--inline-code-spans'.

(defvar-local +markdown--inline-code-spans-cache nil
  "Cache of inline code spans for `markdown-inline-code-at-pos'.
A cons (TICK . TABLE).  TICK is the `buffer-chars-modified-tick'
the cache is valid for.  TABLE maps a text block's (BEG . END) to
the value of `+markdown--inline-code-spans' for that block.")

(defun +markdown--inline-code-spans (beg end)
  "Return the inline code fragments of the text block from BEG to END.
The value is a cons (SPANS . TAIL).  SPANS is a vector, in buffer
order, of (GROUP-BEG MATCH-END MATCH-DATA) lists, one for each
match of `markdown-match-code'.  TAIL is the match data left once
`markdown-match-code' finds no more fragments, which is what the
uncached scan tests when no fragment ends at or after the point.
The value is cached until the buffer text changes."
  (let ((tick (buffer-chars-modified-tick)))
    (unless (eq (car +markdown--inline-code-spans-cache) tick)
      (setq +markdown--inline-code-spans-cache
            (cons tick (make-hash-table :test #'equal))))
    (let ((table (cdr +markdown--inline-code-spans-cache))
          (key (cons beg end)))
      (or (gethash key table)
          (puthash
           key
           (save-excursion
             (save-match-data
               (goto-char beg)
               (let (spans)
                 (while (markdown-match-code end)
                   (let ((group (if (eq (char-after (match-beginning 0)) ?`)
                                    0 1)))
                     (push (list (match-beginning group) (match-end 0)
                                 (match-data t))
                           spans)))
                 (cons (vconcat (nreverse spans)) (match-data t)))))
           table)))))

(defun +markdown-inline-code-at-pos (pos &optional from)
  "Return non-nil if there is an inline code fragment at POS starting at FROM.
Uses the beginning of the block if FROM is nil.
Return nil otherwise.  Set match data according to
`markdown-match-code' upon success.
This function searches the block for a code fragment that
contains the point using `markdown-match-code'.  We do this
because `thing-at-point-looking-at' does not work reliably with
`markdown-regex-code'.  When FROM is nil, the fragments of each
block are cached until the buffer text changes, so repeated calls
in one block, as during fontification, don't rescan it.

The match data is set as follows:
Group 1 matches the opening backquotes.
Group 2 matches the code fragment itself, without backquotes.
Group 3 matches the closing backquotes."
  (save-excursion
    (goto-char pos)
    (let ((old-point (point))
          (end-of-block (progn (markdown-end-of-text-block) (point)))
          found)
      (if from
          (progn
            (goto-char from)
            (while (and (markdown-match-code end-of-block)
                        (setq found t)
                        (< (match-end 0) old-point))))
        ;; Same result as the scan above, from the cache: stop at the
        ;; first fragment ending at or after OLD-POINT, or else at the
        ;; match data the scan leaves when it runs out of fragments.
        (markdown-beginning-of-text-block)
        (let* ((cached (+markdown--inline-code-spans (point) end-of-block))
               (spans (car cached))
               (lo 0)
               (hi (length spans)))
          (while (< lo hi)
            (let ((mid (/ (+ lo hi) 2)))
              (if (< (nth 1 (aref spans mid)) old-point)
                  (setq lo (1+ mid))
                (setq hi mid))))
          (when (> (length spans) 0)
            (setq found t)
            (set-match-data (if (< lo (length spans))
                                (nth 2 (aref spans lo))
                              (cdr cached))))))
      (let ((match-group (if (eq (char-after (match-beginning 0)) ?`) 0 1)))
        (and found                                        ; matched something
             (<= (match-beginning match-group) old-point) ; match contains old-point
             (> (match-end 0) old-point))))))

(after! markdown-mode
  (unless (fboundp 'markdown--inline-code-spans)
    (advice-add 'markdown-inline-code-at-pos :override #'+markdown-inline-code-at-pos)))
