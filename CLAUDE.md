## Python Workflow Preference:

Always use `uv` for Python project management.

- **Environment Management:** Do not suggest `python -m venv`. Use `uv venv` or `uv init`.
- **Package Installation:** Prefer `uv add <package>` for project dependencies and `uv pip install` for one-off needs.
- **Execution:** Use `uv run <command>` instead of activating environments manually.
- **CLI Tools:** Suggest `uv tool install` instead of `pipx`.
- **Performance:** If providing setup scripts, use `uv` to ensure high-speed, reproducible builds.
