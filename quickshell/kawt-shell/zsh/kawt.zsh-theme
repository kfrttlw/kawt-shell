# kawt: an old-terminal prompt for zsh (with or without oh-my-zsh).
#
#   ┌[user@host]─[~/kawt/kawt-shell]─[main*]─[1]
#   └$ █                                              14:32:05
#
# Loaded by one line at the end of ~/.zshrc (install.sh adds it), so it wins over any
# ZSH_THEME, wherever oh-my-zsh lives. Only the terminal's 16 colors are used, so the prompt
# follows the kawt theme (dark / light, soft / crt).
#   [main*]  git branch, * = uncommitted changes      [1]  the last command failed (exit code)

setopt prompt_subst

# ─[branch*] inside a git repo, nothing outside. Plain git, no oh-my-zsh needed.
kawt_git() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2> /dev/null || git rev-parse --short HEAD 2> /dev/null) || return
    local dirty=""
    [[ -n $(git status --porcelain --ignore-submodules=dirty 2> /dev/null | head -n 1) ]] && dirty="%F{1}*"
    print -rn -- "%F{8}─%f[%F{3}${branch//\%/%%}${dirty}%f]"
}

#   %n user · %m host · %~ directory · %? last exit code · %(!.#.$) # when root
PROMPT='%F{8}┌%f[%F{2}%n%F{8}@%f%m]%F{8}─%f[%F{4}%~%f]$(kawt_git)%(?..%F{8}─%f[%F{1}%?%f])
%F{8}└%f%(!.%F{1}#.%F{2}$)%f '
RPROMPT='%F{8}%*%f'
