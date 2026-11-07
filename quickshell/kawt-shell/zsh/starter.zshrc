# ~/.zshrc: install.sh started it from kawt's starter.zshrc because there was none.
# It's yours now, change anything. oh-my-zsh isn't needed; if you add it (or anything that
# sets a prompt) later, keep the kawt line at the very end.

# history: in ~/.zsh_history, shared by the open terminals, no repeats.
# A command typed with a space in front is not kept (for passwords and such).
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt share_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks

# tab: completes commands, options, branches... as a menu (tab / arrows to move), any case
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
# in the ls colors, which the kawt prompt keeps in the theme (-e: read again every time)
zstyle -e ':completion:*' list-colors 'reply=(${(s.:.)LS_COLORS})'

# keys: emacs-style (ctrl+a / ctrl+e / ctrl+r...), ↑↓ go through the history of what's
# already typed, home / end / delete / ctrl+←→ do what they say
bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search '^[OB' down-line-or-beginning-search
bindkey '^[[H' beginning-of-line '^[OH' beginning-of-line
bindkey '^[[F' end-of-line '^[OF' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5D' backward-word '^[[1;5C' forward-word

# a folder's name alone goes into it; # starts a comment on the command line too
setopt auto_cd interactive_comments
