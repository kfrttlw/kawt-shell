# kawt: an old-terminal prompt for zsh (with or without oh-my-zsh).
#
#   ┌[user@host]─[~/kawt/kawt-shell]─[main*]─[1]
#   └$ █                                              14:32:05
#
# Loaded by one line at the end of ~/.zshrc (install.sh adds it), so it wins over any
# ZSH_THEME, wherever oh-my-zsh lives. Colors are the kawt theme's own (accent, dim, warn),
# read from ~/.local/state/kawt/theme/colors.sh before every prompt: a theme switch shows at
# the next one. Without that file, or in a terminal without truecolor (the tty), it falls back
# to the 16 terminal colors.
#   [main*]  git branch, * = uncommitted changes      [1]  the last command failed (exit code)

setopt prompt_subst

# zsh shows pasted text inverted (paste:standout) until the next key, which looks like the
# terminal blinking on every paste. Keep the other highlights, drop that one.
zle_highlight=(${zle_highlight:#paste:*} paste:none)

# the theme's colors -> kawt_c[accent|dim|warn], as prompt color codes (%F{...})
typeset -gA kawt_c
kawt_colors() {
    local f=${XDG_STATE_HOME:-$HOME/.local/state}/kawt/theme/colors.sh
    kawt_c=(accent 2 dim 8 warn 1)
    [[ $COLORTERM == (truecolor|24bit) && -r $f ]] || return
    local KAWT_ACCENT KAWT_DIM KAWT_WARN
    source "$f"
    [[ $KAWT_ACCENT == \#* ]] && kawt_c[accent]=$KAWT_ACCENT
    [[ $KAWT_DIM == \#* ]] && kawt_c[dim]=$KAWT_DIM
    [[ $KAWT_WARN == \#* ]] && kawt_c[warn]=$KAWT_WARN
    kawt_ls_colors
}

# ls (and eza, and zsh's completion list) in the theme too: by default folders are the
# terminal's blue, links cyan, programs green, o+w folders blue on a green block. Now:
# folders accent and bold, links accent and italic, programs bold, broken links warn.
# Colors by file extension stay as they were (they use the 16 colors, already themed).
[[ -z $LS_COLORS ]] && (( $+commands[dircolors] )) && eval "$(dircolors -b)"
typeset -g kawt_ls_base=$LS_COLORS
kawt_ls_colors() {
    [[ ${kawt_c[accent]} == \#* && ${kawt_c[warn]} == \#* ]] || return
    local a=${kawt_c[accent]#\#} w=${kawt_c[warn]#\#}
    local acc="38;2;$((16#${a[1,2]}));$((16#${a[3,4]}));$((16#${a[5,6]}))"
    local warn="38;2;$((16#${w[1,2]}));$((16#${w[3,4]}));$((16#${w[5,6]}))"
    # later entries win in LS_COLORS, so these go after the base. Every name in braces:
    # in zsh `$name:x` is a modifier ($acc:l would lowercase it), not a colon
    export LS_COLORS="${kawt_ls_base:+${kawt_ls_base}:}di=1;${acc}:ln=3;${acc}:ex=1:ow=1;${acc}:tw=1;${acc}:st=1;${acc}:or=1;${warn}:mi=${warn}"
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd kawt_colors

# ─[branch*] inside a git repo, nothing outside. Plain git, no oh-my-zsh needed.
kawt_git() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2> /dev/null || git rev-parse --short HEAD 2> /dev/null) || return
    local dirty=""
    [[ -n $(git status --porcelain --ignore-submodules=dirty 2> /dev/null | head -n 1) ]] && dirty="%F{$kawt_c[warn]}*"
    print -rn -- "%F{$kawt_c[dim]}─%f[%F{$kawt_c[accent]}${branch//\%/%%}${dirty}%f]"
}

# Narrowing the window makes the terminal re-wrap what's already printed. Two things keep
# the prompt out of that mess:
#  - the clock on the right only on the current line (old lines don't drag it along)
#  - the directory shortened from the left (…/kawt-shell) so the first line always fits:
#    the width left after user, host, frame and a branch, never less than 10
setopt transient_rprompt
typeset -g kawt_reserve=$(( ${#USERNAME} + ${#${(%):-%m}} + 24 ))

#   %n user · %m host · %~ directory · %? last exit code · %(!.#.$) # when root
#   frame dim · user, branch, $ accent · directory bold · errors warn
PROMPT='%F{$kawt_c[dim]}┌%f[%F{$kawt_c[accent]}%n%F{$kawt_c[dim]}@%f%m]%F{$kawt_c[dim]}─%f[%B%$(( COLUMNS - kawt_reserve > 10 ? COLUMNS - kawt_reserve : 10 ))<…<%~%<<%b]$(kawt_git)%(?..%F{$kawt_c[dim]}─%f[%F{$kawt_c[warn]}%?%f])
%F{$kawt_c[dim]}└%f%(!.%F{$kawt_c[warn]}#.%F{$kawt_c[accent]}$)%f '
RPROMPT='%F{$kawt_c[dim]}%*%f'

# last, so the prompt above is set even if reading the colors ever fails
kawt_colors
