# kawt: an old-terminal prompt for zsh (with or without oh-my-zsh).
#
#    ~/kawt/kawt-shell  main*  127           the folder inverted, like a bios's chosen line
#   > █                                              14:32:05
#
# Loaded by one line at the end of ~/.zshrc (install.sh adds it), so it wins over any
# ZSH_THEME, wherever oh-my-zsh lives. Colors are the kawt theme's own (accent, dim, warn),
# read from ~/.local/state/kawt/theme/colors.sh before every prompt: a theme switch shows at
# the next one. Without that file, or in a terminal without truecolor (the tty), it falls back
# to the 16 terminal colors.
#    main*   git branch on grey, * = uncommitted changes
#    127     on red: the last command failed (its exit code)
#    user@host  only over ssh: on your own machine the host is always the same (and it stays
#   out of screenshots)
#   >  where you type, red like the cursor in kawt's menus (# as root)
#
# Plus two helpers when they're installed (install.sh does that on Arch), in the theme's colors:
#   zsh-autosuggestions      while typing, the rest of a command from history in dim; → takes it
#   zsh-syntax-highlighting  the command in accent if it exists, in warn if not (a typo)
# Loaded by oh-my-zsh or the like already: only recolored. KAWT_ZSH_PLUGINS=0 before the kawt
# line in ~/.zshrc: left alone (neither loaded nor recolored).

setopt prompt_subst

# zsh shows pasted text inverted (paste:standout) until the next key, which looks like the
# terminal blinking on every paste. Keep the other highlights, drop that one.
zle_highlight=(${zle_highlight:#paste:*} paste:none)

# the theme's colors -> kawt_c[accent|dim|warn|fg|bg|border], as prompt color codes (%F{...})
# (onwarn: the text on the red of a failed command)
typeset -gA kawt_c
kawt_colors() {
    local f=${XDG_STATE_HOME:-$HOME/.local/state}/kawt/theme/colors.sh
    kawt_c=(accent 1 dim 8 warn 1 fg 7 bg 0 border 8 onwarn 15)
    if [[ $COLORTERM == (truecolor|24bit) && -r $f ]]; then
        local KAWT_ACCENT KAWT_DIM KAWT_WARN KAWT_FG KAWT_BG KAWT_BORDER
        source "$f"
        local k v
        for k in accent dim warn fg bg border; do
            v=KAWT_${(U)k}
            [[ ${(P)v} == \#* ]] && kawt_c[$k]=${(P)v}
        done
        kawt_c[onwarn]='#f4f2ec'
        kawt_ls_colors
    fi
    kawt_plugin_colors
}

# ls (and eza, and zsh's completion list) in the theme too: by default folders are the
# terminal's blue, links cyan, programs green, o+w folders blue on a green block. Now:
# folders accent and bold, links accent and italic, programs bold, broken links warn.
# Colors by file extension stay as they were (they use the 16 colors, already themed).
[[ -z $LS_COLORS ]] && (( $+commands[dircolors] )) && eval "$(dircolors -b)"
typeset -g kawt_ls_base=$LS_COLORS
kawt_ls_colors() {
    [[ ${kawt_c[accent]} == \#* && ${kawt_c[warn]} == \#* ]] || return 0
    local a=${kawt_c[accent]#\#} w=${kawt_c[warn]#\#}
    local acc="38;2;$((16#${a[1,2]}));$((16#${a[3,4]}));$((16#${a[5,6]}))"
    local warn="38;2;$((16#${w[1,2]}));$((16#${w[3,4]}));$((16#${w[5,6]}))"
    # later entries win in LS_COLORS, so these go after the base. Every name in braces:
    # in zsh `$name:x` is a modifier ($acc:l would lowercase it), not a colon
    export LS_COLORS="${kawt_ls_base:+${kawt_ls_base}:}di=1;${acc}:ln=3;${acc}:ex=1:ow=1;${acc}:tw=1;${acc}:st=1;${acc}:or=1;${warn}:mi=${warn}"
}
# the helpers' colors (their own defaults: gray, green, red): both read them on every redraw
kawt_plugin_colors() {
    [[ ${KAWT_ZSH_PLUGINS:-1} == 0 ]] && return
    (( $+functions[_zsh_autosuggest_start] )) && ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=$kawt_c[dim]"
    [[ ${(t)ZSH_HIGHLIGHT_STYLES} == association* ]] || return 0
    local k
    # a command that runs (arg0 covers them in 0.8, older versions read each kind)
    for k in arg0 command builtin alias function hashed-command reserved-word global-alias; do
        ZSH_HIGHLIGHT_STYLES[$k]="fg=$kawt_c[accent]"
    done
    for k in precommand suffix-alias autodirectory; do
        ZSH_HIGHLIGHT_STYLES[$k]="fg=$kawt_c[accent],underline"
    done
    ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=$kawt_c[warn],bold"
    ZSH_HIGHLIGHT_STYLES[comment]="fg=$kawt_c[dim]"
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd kawt_colors

#  branch*  on grey inside a git repo, nothing outside. Plain git, no oh-my-zsh needed.
kawt_git() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2> /dev/null || git rev-parse --short HEAD 2> /dev/null) || return
    local dirty=""
    [[ -n $(git status --porcelain --ignore-submodules=dirty 2> /dev/null | head -n 1) ]] && dirty="%F{$kawt_c[accent]}*"
    print -rn -- "%K{$kawt_c[border]}%F{$kawt_c[fg]} ${branch//\%/%%}${dirty} %f%k"
}

# Narrowing the window makes the terminal re-wrap what's already printed. Two things keep
# the prompt out of that mess:
#  - the clock on the right only on the current line (old lines don't drag it along)
#  - the directory shortened from the left (…/kawt-shell) so the first line always fits:
#    the width left after the blocks around it and a branch, never less than 10
setopt transient_rprompt
typeset -g kawt_who="" kawt_reserve=24
if [[ -n $SSH_CONNECTION ]]; then
    kawt_who='%K{$kawt_c[border]}%F{$kawt_c[fg]} %n@%m %f%k'
    (( kawt_reserve += ${#USERNAME} + ${#${(%):-%m}} + 3 ))
fi

#   %n user · %m host · %~ directory · %? last exit code · %(!.#.>) # when root
#   directory inverted and bold · branch on grey · a failed command's code on red · > accent
PROMPT=$kawt_who'%K{$kawt_c[fg]}%F{$kawt_c[bg]}%B %$(( COLUMNS - kawt_reserve > 10 ? COLUMNS - kawt_reserve : 10 ))<…<%~%<< %b%f%k$(kawt_git)%(?..%K{$kawt_c[warn]}%F{$kawt_c[onwarn]} %? %f%k)
%(!.%F{$kawt_c[warn]}#.%F{$kawt_c[accent]}>)%f '
RPROMPT='%F{$kawt_c[dim]}%*%f'

# The helpers, from where the distros put them (Arch: /usr/share/zsh/plugins/<name>/,
# Debian / Fedora: /usr/share/<name>/). Sourced here at the top level, not inside a function:
# their own variables would end up local to it. syntax-highlighting wants to come last, after
# every other key binding: the kawt line is at the end of .zshrc for that too.
kawt_plugin() { # kawt_plugin <name>: $REPLY = its file, if it's installed
    local f
    for f in /usr/share/zsh/plugins/$1/$1.zsh /usr/share/$1/$1.zsh; do
        [[ -r $f ]] && { REPLY=$f; return 0; }
    done
    return 1
}
if [[ ${KAWT_ZSH_PLUGINS:-1} != 0 ]]; then
    (( $+functions[_zsh_autosuggest_start] )) || { kawt_plugin zsh-autosuggestions && source $REPLY; }
    (( $+functions[_zsh_highlight] )) || { kawt_plugin zsh-syntax-highlighting && source $REPLY; }
fi

# last, so the prompt above is set even if reading the colors ever fails. It must end well
# (status 0): the first prompt shows how the last thing .zshrc ran ended, and that's this
# file, so a stray 1 here showed up as a [1] right after logging in
kawt_colors
