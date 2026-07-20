# Inklings Plugin Development Guidelines

## Git Workflow Requirement

After completing any code, documentation, configuration, or repository changes, always commit the changes and push them to the configured GitHub remote unless I explicitly tell you not to.

**Do not leave completed work only in the local checkout.**

Before finishing a task:

1. Run `git status` to review all changes
2. Review the changed files carefully
3. Create an appropriate commit message that describes the changes
4. Commit the changes via `git commit`
5. **Always push to main** via `git push origin main`
6. Report the commit hash and push status

**If push fails, clearly report the reason and do not claim the task is complete.**

This ensures that:
- All work is backed up on GitHub
- Other collaborators can see completed changes
- The repository state is always in sync with the remote
- No work is lost if the local checkout is damaged or deleted

## Development Guide

`ARES_PLUGIN_DEVELOPMENT_GUIDE.md` is a general-purpose reference for AresMUSH
plugin development (not Inklings-specific), covering web portal conventions,
Ruby plugin conventions, installation patterns, and a running list of concrete
mistakes made and fixed on this project. Consult it before making web-portal
or install-mechanism changes, and add to it whenever a genuine, verified
lesson is learned during this project's development or debugging — don't wait
to be asked. Follow the standing Git Workflow Requirement above for any
addition to it.

## Project Context

The Inklings plugin is a complete character development system for AresMUSH. It provides:
- Threaded inkling management (goals, secrets, plot hooks, character progression)
- MUSH commands and web portal integration
- Approval workflow, rewards, and auditing
- AresMUSH plugin installer support via `.ares-manifest.yml`

For more details, see README.md.
