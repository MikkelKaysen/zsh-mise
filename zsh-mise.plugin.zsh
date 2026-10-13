# Copyright (c) 2026 Mikkel Kaysen

# According to the Zsh Plugin Standard:
# http://zdharma.org/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html

0=${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}
0=${${(M)0:#/*}:-$PWD/$0}

# Then ${0:h} to get plugin's directory

if [[ ${zsh_loaded_plugins[-1]} != */zsh-mise && -z ${fpath[(r)${0:h}/functions]} ]] {
    fpath+=( "${0:h}/functions" )
}

# Standard hash for plugins, to not pollute the namespace
typeset -gA Plugins
Plugins[ZSH_MISE_DIR]="${0:h}"

(( ${+commands[mise]} )) && () {

  local command=${commands[mise]}
  [[ -z $command ]] && return 1

  # Non-interactive: shims only. Full hooks belong in interactive shells.
  if [[ ! -o interactive ]]; then
    eval "$($command activate zsh --shims)"
    return
  fi

  local cachedir=$1

  # Cache the activate script. Regenerate when mise is newer.
  local activatefile=$cachedir/mise-activate.zsh
  if [[ ! -e $activatefile || $activatefile -ot $command ]]; then
    $command activate zsh >| $activatefile
    zcompile -UR $activatefile
  fi

  # Define compdef as a no-op before sourcing the activate script.  mise's
  # hook-env output calls compinit when compdef is not yet defined:
  #   if ! (( $+functions[compdef] )); then autoload -Uz compinit; compinit -i; fi
  # In zimfw, the completion module (which calls compinit) loads after this
  # module.  The no-op compdef prevents a premature compinit call.
  compdef() { :; }
  source $activatefile
  unset -f compdef

  # Schedule a one-shot precmd hook to re-run hook-env once the completion
  # module has made the real compdef available.  This registers tool
  # completions (fnox, usage, etc.) at the right time, then restores the
  # activate state so the precmd optimization continues to work.
  _mise_register_completions() {
    add-zsh-hook -d precmd _mise_register_completions
    unset -f _mise_register_completions
    _mise_hook --force
    export __MISE_ZSH_ACTIVATE_PATH="$PATH"
    export __MISE_ZSH_ACTIVATE_ENV="$(_mise_hook_env_state)"
  }
  add-zsh-hook precmd _mise_register_completions

  # Generate mise completion function.  Regenerate when mise is newer.
  local compfile=$cachedir/functions/_mise
  [[ -d ${compfile:h} ]] || mkdir -p ${compfile:h}
  if [[ ! -e $compfile || $compfile -ot $command ]]; then
    $command complete --shell zsh >| $compfile
    print -u2 -PR "* Detected a new version of 'mise'. Regenerated completions."
  fi
  fpath+=(${compfile:h})
} ${Plugins[ZSH_MISE_DIR]}