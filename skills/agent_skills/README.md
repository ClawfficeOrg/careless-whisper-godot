# Agent Skills Bundle — README

This directory contains a sample rendered output of the Zoid agent skills
bundle feature (`agent-skills`). These files are included in this repository
as a human-reviewable reference for what the generator produces.

## Files

| File | Purpose |
|------|---------|
| `fetch_gpui_docs.md` | How to safely retrieve current GPUI API documentation. |
| `build_generated_project.md` | Commands for building, linting, and testing a generated project. |
| `create_gpui_component.md` | Patterns for creating GPUI views, elements, and actions. |
| `update_docs.md` | Process for keeping `docs/memory.md` and `docs/learnings.md` accurate. |
| `NOTES-security.md` | Shell whitelist, forbidden patterns, and trust policy. |
| `TRUST_POLICY.md` | Full skill bundle trust policy. |

## Usage

To include these skills in a generated project, pass `--include-features=agent-skills`
to `zoid create`. The skill files will be written to the `skills/` directory of
the generated project.

## Trust

All skills in this directory are local and human-authored. They were generated
from vetted Zoid templates. See `TRUST_POLICY.md` for the full policy.

**Skills are never auto-installed from the internet.**
