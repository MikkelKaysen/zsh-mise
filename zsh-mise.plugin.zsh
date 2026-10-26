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

# WSL: the launcher may omit the Windows PATH entries (e.g. /mnt/c/Windows/System32,
# user tool dirs). Recover them from cmd.exe, convert with wslpath, and append
# any existing, not-yet-present directories to $path. Never fails startup.
_zsh_mise_wsl_restore_path() {
  local cmdexe=${commands[cmd.exe]:-/mnt/c/Windows/System32/cmd.exe}
  local wslpathbin=${commands[wslpath]}
  [[ -x $cmdexe && -n $wslpathbin ]] || return 0

  local winpath
  winpath="$("$cmdexe" /d /c 'echo %PATH%' 2>/dev/null)" || return 0
  winpath=${winpath//$'\r'/}
  [[ -n $winpath && $winpath != *'%PATH%'* ]] || return 0

  local -a entries
  entries=( ${(s:;:)winpath} )

  local entry converted
  for entry in $entries; do
    entry=${entry//\"/}
    [[ -n $entry ]] || continue
    converted="$("$wslpathbin" -u "$entry" 2>/dev/null)" || continue
    [[ -n $converted && -d $converted ]] || continue
    (( ${path[(Ie)$converted]} )) || path+=( "$converted" )
  done
  return 0
}

(( ${+commands[mise]} )) && () {

  local command=${commands[mise]}
  [[ -z $command ]] && return 1

  local is_wsl=0
  if [[ -n ${WSL_DISTRO_NAME-} || -n ${WSL_INTEROP-} ]]; then
    is_wsl=1
    _zsh_mise_wsl_restore_path
  fi

  # Non-interactive: shims only. Full hooks belong in interactive shells.
  if [[ ! -o interactive ]]; then
    eval "$($command activate zsh --shims)"
    return
  fi

  local cachedir=$1

  # Off WSL: cache the activate script. Regenerate when mise is newer.
  # On WSL: the activation depends on the environment, so evaluate it fresh.
  local activatefile=$cachedir/mise-activate.zsh
  local activate_script=
  if (( is_wsl )); then
    activate_script="$($command activate zsh)" || activate_script=
  elif [[ ! -e $activatefile || $activatefile -ot $command ]]; then
    $command activate zsh >| $activatefile
    zcompile -UR $activatefile
  fi

  # Define compdef as a no-op before sourcing the activate script.  mise's
  # hook-env output calls compinit when compdef is not yet defined:
  #   if ! (( $+functions[compdef] )); then autoload -Uz compinit; compinit -i; fi
  # In zimfw, the completion module (which calls compinit) loads after this
  # module.  The no-op compdef prevents a premature compinit call.
  compdef() { :; }
  if (( is_wsl )); then
    [[ -n $activate_script ]] && eval "$activate_script"
  else
    source $activatefile
  fi
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
    # The real `compdef` is now available (the completion module has loaded).
    # Tie the `mse` function to mise's completion function.
    (( ${+functions[mse]} )) && compdef _mise mse
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

# `mse` runs mise through fnox so [bootstrap.secrets] templates resolve from
# the age-encrypted cache instead of prompting each apply. No-op when fnox
# isn't installed — plain `mise` still works (with --prompt-secrets if needed).
#
# Defined as a function rather than an alias so the generated `_mise`
# completion does not resolve it. An alias would be rewritten to
# `fnox exec -- mise`, which mise's completion engine cannot parse — so `mse`
# completions would fall back to files/commands. As a function, `mse` stays
# out of `$aliases`, the completion sees `mse <args>`, and `compdef _mise mse`
# (registered in the precmd hook below) provides full mise completions.
if (( ${+commands[fnox]} )); then
  # Drop a stale `mse` alias (e.g. from an older config) so the function
  # definition below is not parsed as a function based on an alias.
  unalias mse 2>/dev/null
  function mse { fnox exec -- mise "$@" }
fi