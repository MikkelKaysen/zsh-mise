# zsh-mise

A Zsh plugin that activates [mise](https://github.com/jdx/mise) and registers completions for tools installed by mise.

## Requirements

- [mise](https://github.com/jdx/mise) must be installed and available on your `$PATH`.

## Installation

### zinit

```zsh
zinit light mikkelkaysen/zsh-mise
```

### Oh My Zsh

Clone the repository into your custom plugins directory:

```zsh
git clone https://github.com/mikkelkaysen/zsh-mise.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-mise
```

Then add `zsh-mise` to your plugins list in `~/.zshrc`:

```zsh
plugins=(... zsh-mise)
```

### zimfw

Add the following to your `~/.zimrc`:

```zsh
zmodule mikkelkaysen/zsh-mise
```

Then run:

```zsh
zimfw install
```

> **TIP:** Add this module as early as possible in your `~/.zimrc` file. This allows other plugins to detect apps installed by `mise`.

## Features

When `mise` is found on the system, the plugin:

1. Caches the `mise activate zsh` script with `zcompile` for faster sourcing on subsequent shell starts. The cached file is regenerated only when the `mise` binary is newer.
2. Defines a no-op `compdef` stub before sourcing the activate script to prevent a premature `compinit` call. In zimfw, the completion module loads after this module — the stub ensures mise's `hook-env` does not trigger `compinit` before the completion module is ready.
3. Schedules a one-shot `precmd` hook that re-runs `hook-env` after the completion module has initialized, registering tool completions (fnox, usage, etc.) at the right time.
4. Generates the mise completion function (`_mise`) and regenerates it when the `mise` binary is newer.

## License

[MIT](./LICENSE) — Copyright (c) 2026 Mikkel Kaysen