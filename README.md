# shell-cook

Describe what you want in plain language, get a single shell command back,
review it, and run it. Built on the
[Claude Agent SDK](https://github.com/anthropics/claude-agent-sdk-python).

```console
$ cook "list the json files here with an int field abc: filename: value, sorted"
⠹ Generating command (sonnet/low) · [▰▰▰▱▱▱▱▱▱▱] 3/8 · 7s · Bash: head -c 200 a.json
✓ Generating command (sonnet/low) (9s)
$ for f in *.json; do echo "$f: $(jq -r '.abc' "$f")"; done | sort -t: -k2 -n
```

The command appears in an editable prompt. Enter runs it, Ctrl+C aborts.

## Features

- **Context-aware:** knows your system (`context.md`) and your working
  directory, and may inspect files with read-only tools while thinking.
- **Guard rails, not guarantees:** read-only exploration with path deny
  rules, a regex blacklist enforced in code, tripwires that force a
  second-stage risk review by a stronger model, and a review prompt before
  anything runs.
- **Short commands only:** anything longer than 8 lines is discarded, and
  Python one-liners are opt-in. If the task cannot be solved cleanly, it
  aborts instead of guessing.
- **Live status:** spinner, phase, turn bar and the agent's last action.
- **Plain-text configuration:** system info and rules live in two small files
  you can edit by hand or via natural language.

## Requirements

- Linux with bash
- Python 3.11+ and [uv](https://docs.astral.sh/uv/) (or pipx)
- Access to Claude: sign in with `shell-cook login` (uses the Claude Code
  CLI bundled with the SDK; the installer offers this step) or set an
  `ANTHROPIC_API_KEY`. Check Anthropic's current terms for using a
  subscription from your own scripts. Without access, requests fail with
  `error: not logged in to Claude`.

## Installation

### One step

```bash
git clone https://github.com/jannes02/shell-cook.git
cd shell-cook
./install.sh
```

The script:

1. checks that `uv` is installed,
2. asks before it installs the tool with `uv tool install`,
3. runs `shell-cook setup`, which creates the default configuration,
   asks which command name you want (default: `cook`), warns if that name
   already exists in bash, and asks again before it touches `~/.bashrc`
   (it skips the edit if the line is already there),
4. offers `shell-cook login` if you are not signed in yet.

Options:
`-y` (no questions), `-e` (editable install of the checkout), `--name NAME`
(command name), `--dry-run` (only print the steps).

Piping works too (the questions are read from the terminal). Read the script
first if you prefer:

```bash
curl -fsSL https://raw.githubusercontent.com/jannes02/shell-cook/main/install.sh | bash
```

### Manual

```bash
uv tool install git+https://github.com/jannes02/shell-cook
```

Then run the setup. It creates the default configuration and asks whether to
add the shell integration to your `~/.bashrc` (nothing is changed without
your confirmation):

```bash
shell-cook setup
```

```text
Name of the shell command [cook]:
The shell integration defines `cook`:
  eval "$(shell-cook shell-init)"
Add it to /home/you/.bashrc now? [y/N]
```

For another name, e.g. `cmd`, the line becomes
`eval "$(shell-cook shell-init cmd)"`. Prefer to do it yourself? Answer
`n` and add the line to `~/.bashrc` manually. In scripts use
`shell-cook setup -y [--name NAME]` to skip the questions. With `-y`, a
name that already exists in bash is refused.

The `cook` function runs the generated command in your current shell (right
directory, aliases, variables) and lets you edit it first.

To update later, pull the repository and run the installer again (it is safe
to repeat), or reinstall directly:

```bash
uv tool install --force git+https://github.com/jannes02/shell-cook
```

On first start, default configuration files are created in
`~/.config/shell-cook/`. Run `cook update` once so the generator learns
about your system.

## Usage

```text
cook [options] "what you want"            generate a command
cook status                               show the system context
cook rules                                show the rules
cook update ["hint"]                      refresh the system context (diff first)
cook configure "change"                   change the rules in plain language
shell-cook login [status|logout]          sign in to Claude, check or sign out
shell-cook setup                          create default config, offer to edit ~/.bashrc
shell-cook shell-init [name]              print the bash function (for eval)
```

| Option | Meaning |
| --- | --- |
| `-m XY` | Model and effort: `h`/`s`/`o` (haiku/sonnet/opus) plus `1`-`4` (low/medium/high/max). Default `s1`. Haiku ignores the effort. |
| `-s`, `--secure` | Second stage: Opus reviews the command and prints `[RISK-LEVEL: n/10]` (green 0-3, yellow 4-6, red 7+). |
| `-p`, `--python` | Allow `python3 -c '...'` in the result. Otherwise Python is discarded. |
| `-l`, `--long` | Do not discard commands longer than 8 lines. |

Options must come before the request; everything after the first word of the
request is taken literally, so `cook show ls -l output` works unquoted.

Commands containing `sudo`, `doas`, `pkexec`, `run0` or `su`, or matching one
of the risky patterns in `rules.toml` (recursive `rm`, `find -delete`,
`xargs`, `curl`/`wget`, `eval`, `sh -c`, `chmod`/`chown`, `kill`, writes via
redirection, package installs, ...), always get the risk review. At risk 7 or
higher (or if the risk cannot be assessed) the shell function additionally
asks you to type `yes`.

Multi-line commands (only possible with `-p` or `-l`) cannot be edited in the
one-line prompt. They are printed unchanged and you confirm with `y`.

A request that starts with `status` or `rules` followed by more words is
treated as a normal request. `update` and `configure` are always subcommands.

## Configuration

Files live in `$XDG_CONFIG_HOME/shell-cook/` (default
`~/.config/shell-cook/`). Set `SHELL_COOK_CONFIG_DIR` to use another
directory. Updates of the program never touch these files.

- `context.md`: facts about your machine (distro, hardware, package manager,
  tools). Keep it current with `cook update`. A hint appears when it is older
  than 30 days.
- `rules.toml`:
  - `[whitelist]` read-only tools the agent may use while exploring,
  - `[deny]` paths the agent must not read (`~/.ssh`, `.env`, keys, ...),
  - `[blacklist]` regex patterns; a matching command is blocked and not
    printed,
  - `[review]` regex tripwires; a match forces the risk review,
  - `[no_gos]` free-text rules passed to the model.

Patterns are tried on the command as written and on a normalized copy with
quotes and backslashes removed, which catches trivial tricks like `r''m`.
They are heuristics: they will miss some things and flag some harmless ones.

Delete a file to get the packaged default back on the next run. Updates never
change an existing `rules.toml`, so after an upgrade check the packaged
defaults (`[review]` and `[deny]` are filled in automatically if your file
lacks them, but changed blacklist patterns are not).

The agent does not load any Claude settings from `~/.claude` or from the
current directory.

## How it works

1. The agent explores with whitelisted read-only tools and answers with a
   single `<cmd>...</cmd>` (or `<fail>reason</fail>`).
2. The code checks the result: blacklist, Python and length limits.
3. Optionally (`-s`, or forced by `sudo` and the `[review]` tripwires) a second
   model rates the risk. It treats the command as untrusted data.
4. Only the command is written to stdout. The shell function puts it into an
   editable prompt.

Exit codes: `0` ok, `1` aborted or blocked, `2` usage error, `10` command
printed but high risk.

## Status

Early alpha (0.1.0). Most of this code was written with the help of an AI
assistant (Claude Code) and reviewed by the maintainer.

This is an unofficial community project. It is not affiliated with, endorsed
by or sponsored by Anthropic. "Claude" is a trademark of Anthropic.

Not covered yet:
- There are no automated tests.
- Tested only on Linux with bash; Python 3.14/3.15 only (3.11+ declared).
- Not exercised end to end: browser login, `-s`, `-p`, `-l`, `cook update`,
  `cook configure`, Haiku with effort settings, and the `[deny]` path rules
  (their effect on the agent is untested).
- Blacklist and risk review are heuristics, not guarantees.

Bug reports and pull requests are welcome, see
[CONTRIBUTING.md](CONTRIBUTING.md).

## Safety notice

The output comes from a language model and can be wrong. The blacklist and
the risk review reduce risk but do not remove it. Always read the command
before you press Enter.

## Development

```bash
git clone https://github.com/jannes02/shell-cook.git
cd shell-cook
uv sync
uv run shell-cook --version
uv run isort src && uv run pyink src && uv run pylint src/shell_cook
```

To use your working copy as the installed tool:

```bash
uv tool install --editable .
```

The code follows the
[Google Python Style Guide](https://google.github.io/styleguide/pyguide.html).

## License

[MIT](LICENSE)
