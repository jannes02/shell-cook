# Contributing

1. `uv sync`, then `uv run isort src && uv run pyink src &&
   uv run pylint src/shell_cook` must be clean (Google Python style).
2. Keep changes small and explain *why* in the pull request.
3. Changes to the `rules.toml` defaults, the blacklist or the risk logic need
   a short safety rationale.
4. Add tests where you can; there is no suite yet, so a first one is welcome.
5. AI-assisted contributions are fine. Please say so in the pull request and
   make sure you have read and understood every line.
