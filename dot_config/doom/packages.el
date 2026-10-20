;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; To install a package with Doom you must declare them here and run 'doom sync'
;; on the command line, then restart Emacs for the changes to take effect -- or
;; use 'M-x doom/reload'.


;; To install SOME-PACKAGE from MELPA, ELPA or emacsmirror:
;; (package! some-package)

;; To install a package directly from a remote git repo, you must specify a
;; `:recipe'. You'll find documentation on what `:recipe' accepts here:
;; https://github.com/radian-software/straight.el#the-recipe-format
;; (package! another-package
;;   :recipe (:host github :repo "username/repo"))

;; If the package you are trying to install does not contain a PACKAGENAME.el
;; file, or is located in a subdirectory of the repo, you'll need to specify
;; `:files' in the `:recipe':
;; (package! this-package
;;   :recipe (:host github :repo "username/repo"
;;            :files ("some-file.el" "src/lisp/*.el")))

;; If you'd like to disable a package included with Doom, you can do so here
;; with the `:disable' property:
;; (package! builtin-package :disable t)

;; You can override the recipe of a built in package without having to specify
;; all the properties for `:recipe'. These will inherit the rest of its recipe
;; from Doom or MELPA/ELPA/Emacsmirror:
;; (package! builtin-package :recipe (:nonrecursive t))
;; (package! builtin-package-2 :recipe (:repo "myfork/package"))

;; Specify a `:branch' to install a package from a particular branch or tag.
;; This is required for some packages whose default branch isn't 'master' (which
;; our package manager can't deal with; see radian-software/straight.el#279)
;; (package! builtin-package :recipe (:branch "develop"))

;; Use `:pin' to specify a particular commit to install.
;; (package! builtin-package :pin "1a2b3c4d5e")


;; Doom's packages are pinned to a specific commit and updated from release to
;; release. The `unpin!' macro allows you to unpin single packages...
;; (unpin! pinned-package)
;; ...or multiple packages
;; (unpin! pinned-package another-pinned-package)
;; ...Or *all* packages (NOT RECOMMENDED; will likely break things)
;; (unpin! t)

(package! p4)
;; rg.el: the backend projectile-ripgrep needs (the rg binary alone isn't enough).
;; Results land in an rg buffer: n/p to move, r to refine, e for wgrep edits.
(package! rg)

(package! websocket)

(package! org-cliplink)

;; Agent Shell (ACP-based AI agent interface)
(package! shell-maker
  :recipe (:host github :repo "xenodium/shell-maker"))
(package! acp
  :recipe (:host github :repo "xenodium/acp.el"))
(package! agent-shell
  :recipe (:host github :repo "xenodium/agent-shell"))
;; acp, shell-maker, and agent-shell deliberately carry no :pin — they track
;; upstream main, and `doom sync -u' / `doom upgrade' pulls the latest.

;; Agent Shell companion packages
(package! agent-shell-sidebar
  :recipe (:host github :repo "cmacrae/agent-shell-sidebar"))
(package! agent-shell-manager
  :recipe (:host github :repo "jethrokuan/agent-shell-manager"))
;; Trial 2026-10-16: session overview, attention, links, recall, babel.
;; Notes: ~/forge/vault/devenv/emacs/17-agent-shell-addons-2026-10.org
(package! agent-shell-hq
  :recipe (:host github :repo "SreenivasVRao/agent-shell-hq" :files ("*.el")))
(package! agent-shell-attention
  :recipe (:host github :repo "ultronozm/agent-shell-attention.el"))
(package! agent-shell-links
  :recipe (:host github :repo "ultronozm/agent-shell-links.el"))
(package! agent-recall
  :recipe (:host github :repo "mrx-xo/agent-recall"))
(package! ob-agent-shell
  :recipe (:host github :repo "eddof13/ob-agent-shell"))
;; Installed but not enabled: it needs desktop-save-mode, which competes
;; with Doom's persp-mode sessions. See the notes before turning it on.
(package! agent-shell-desktop
  :recipe (:host github :repo "timfel/agent-shell-desktop.el"))

;; Justfile support
(package! just-mode)
(package! justl)

;; GPG pinentry via Emacs minibuffer (fixes broken pinentry-curses in distrobox)
(package! pinentry)

;; gptel - LLM client for programmatic and interactive use
(package! gptel)

;; ghostel - terminal emulator powered by libghostty-vt (vterm alternative)
(package! ghostel)
;; Bluesky client (ahyatt). Auth: app password via auth-source; the
;; bsky.social entry in ~/.authinfo.gpg comes from 1Password (op_bluesky).
(package! bluesky)

;; pdf-tools comes prebuilt from Nix (flake include `emacs-native'), so
;; epdfinfo is compiled against the image's poppler instead of needing
;; autoconf + poppler-glib headers in the box. Same pattern as vterm.
(package! pdf-tools :built-in 'prefer)

;; org-semantic - semantic + lexical (BM25) search over org notes. Client
;; only; the binary is forge's pinned copy (`just vault-search-install').
;; forge vault/devenv/forge-vault-search.org
(package! org-semantic)
