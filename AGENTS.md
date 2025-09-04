# AGENTS

This repository uses Codex CLI as a terminal-based coding assistant. These settings guide the agent’s defaults when running locally with the Codex CLI harness.

Agent Settings

- Approval Policy: never — do not require permission for commands.
- Sandbox Mode: workspace-write — allow edits within the workspace.
- Network Access: restricted — keep network access limited by default.
- Shell: powershell.exe (on Windows environments).

Config (for Codex CLI runners)

```yaml
codex:
  approval_policy: never        # Run without prompting for approvals
  sandbox_mode: workspace-write # Allow write access within workspace
  network_access: restricted    # Keep network disabled unless explicitly enabled
  shell: powershell.exe
```

Notes

- These settings document the intended defaults. The actual runtime policy is controlled by how the harness is launched. If you still see approval prompts, start the CLI with approvals disabled (e.g., using a flag or env var) to match this file:
  - Example: set `approval_policy=never` or pass `--approvals=never` when starting the agent.
- Only elevate or enable network when strictly necessary for the task.

