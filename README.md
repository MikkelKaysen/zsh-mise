# zsh-mise

[zim](https://github.com/zimfw/zimfw) module for [mise](https://github.com/jdx/mise).

Fixes the double `compinit` call that occurs when mise's `hook-env` activates
before zim's completion module.  A no-op `compdef` stub prevents the premature
`compinit`, and a one-shot `precmd` hook re-runs `hook-env` after the completion
module has initialized, registering tool completions at the right time.

TIP: Add this module as early as possible to the `.zimrc` file.
  This allows other plugins to detect apps installed by `mise`.