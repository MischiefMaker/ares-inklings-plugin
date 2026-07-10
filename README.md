# Inklings

Inklings is a plugin for [AresMUSH](https://aresmush.com) that gives players and staff a threaded system for tracking character development, plot hooks, requests, and secrets - separate from (but linked into) the normal job/ticket system.

## Features

- **Player-initiated threads:** initiative, request, update, pitch, goal, secret
- **Staff-initiated threads:** hint, vision, nudge, hook
- Messages can be public, private (to specific participants + staff), or GM-only notes
- Threads can be shared with individual characters or with everyone matching a demographics group
- Dice rolls (FS3 or custom/static) can be attached to any thread, with optional luck-point rerolls from the web portal
- Every thread automatically gets a linked job in an `INKLINGS` job category, so staff are notified through the normal job workflow without duplicating data
- Every message and roll gets a permanent reference number in the form `<inkling id>.<sequence>` (e.g. `14.3`) for pointing back at a specific entry later
- The thread view shows a "Shared With" section listing which non-staff characters and groups have access
- A React tab (`InklingsTab.jsx`) for managing inklings from the character's web portal profile
- Chargen and app-review hooks that require a secret and a goal inkling before a character can be approved
- A coder-only, double-confirmation `+inkling/reset` command for wiping the system during development/testing

## Installation

1. Copy the `plugin/` folder into your game's `plugins/inklings/` directory.
2. Copy the contents of `webportal/components/` into your game's web portal component directory (wherever your install serves character-profile tab components from).
3. Copy `game/config/inklings.yml` into your game's `game/config/` directory, or merge its contents into an existing config if you already have one.
4. Restart your game.
5. In-game, create the job category Inklings expects:
   ```
   job/category create INKLINGS
   job/categoryroles INKLINGS=<roles that should see inkling-related jobs>
   ```
6. Confirm the `manage_game` permission exists and is assigned to your Coder role, since `+inkling/reset` depends on it. See [Using Permissions in Code](https://aresmush.com/tutorials/manage/roles.html#using-permissions-in-code) if you need to add it.

## Commands

See `plugin/help/player/inklings.md` and `plugin/help/admin/managing_inklings.md` for the full command reference, or run `help inklings` / `help managing inklings` in-game once installed.

Quick reference:

| Command | Who | Purpose |
|---|---|---|
| `+inklings` | Everyone | List your open inklings (`/closed`, `/all`) |
| `+inkling <id>` | Participants + staff | View a thread |
| `+inkling/new <kind>=<title>/<text>` | Players (own) / staff | Start a titled thread |
| `+inkling/hint`, `/vision`, `/nudge`, `/hook <char>=<text>` | Staff | Start a staff-initiated thread |
| `+inkling/secret <text>` or `<char>=<text>` | Players / staff | Start a secret thread |
| `+inkling/advance <id>=<text>` | Participants + staff | Add a visible update |
| `+inkling/private <id>=<text>` or `<name>/<text>` | Participants + staff | Add a private entry |
| `+inkling/gm <id>=<text>` | Staff | Add a staff-only note |
| `+inkling/roll <id>=<roll>` | Participants + staff | Attach a roll |
| `+inkling/share <id>=<char>,<char>` | Owner + staff | Grant access to specific characters |
| `+inkling/group <id>=<group>,<group>` | Owner + staff | Grant access to a demographics group |
| `+inkling/close <id>` | Owner + staff | Close a thread |
| `+inkling/delete <id>` | Owner + staff | Delete a thread |
| `+inkling/list <char>` | Staff | List all of a character's threads |
| `+inkling/reset` | `manage_game` permission only | Wipe the entire system (type twice to confirm) |

## Configuration

`game/config/inklings.yml`:

```yaml
inklings:
  shortcuts: {}
  job_category: INKLINGS
```

- `job_category` - the job category new inkling threads are linked into. Defaults to `INKLINGS` if omitted.

Permission checks live in `plugin/inklings.rb`:

- `Inklings.can_manage_inklings?(enactor)` - governs ordinary staff-side access (starting staff threads, GM notes, viewing/managing any thread). Defaults to reusing the Jobs plugin's `Jobs.can_manage_jobs?` check.
- `Inklings.can_reset_system?(enactor)` - governs the destructive `+inkling/reset` command. Checks the `manage_game` permission directly, which is normally only granted to Coders (Admins implicitly have every permission).

Adjust either method if your game's staff/coder structure differs from the defaults.

## Known Limitations / Things to Verify Before Production Use

- **`plugin/events/job_reply_event_handler.rb` is unconfirmed scaffolding.** There's no documented event fired when a `JobReply` is added in stock Ares, so the event class name and field names in that file are best-effort guesses. The plugin does **not** currently rely on this handler being wired up - instead, `Inklings.sync_job_replies` pulls in new job replies on demand whenever a thread is viewed or listed. If you want push-based notification instead, check `plugins/jobs/public/*.rb` on your install for the actual event Jobs fires (if any) and update this handler + `Inklings.get_event_handler` to match before enabling it.
- **FS3 integration is optional.** `+inkling/roll` requires `FS3Skills.parse_and_roll` to exist; if your game doesn't use FS3, that command will report the roll system as unavailable, but the rest of the plugin works fine without it.
- **Luck rerolls assume a `luck` attribute** (`char.luck`) on your character model, used by the web portal's reroll button. If your game doesn't track luck points, that feature is a no-op/error from the API side - the rest of the roll system doesn't depend on it.
- **`seq` (the `14.3`-style reference number) is not backfilled** for inklings created before this plugin adopted it. If you're upgrading an existing install with pre-existing data, write a one-off migration that walks every `Inkling`, sorts its `messages` and `rolls` by `created_at`, and assigns `seq` in order before relying on references being complete for old threads.
- **`+inkling/reset` is irreversible** and deletes every inkling thread, message, roll, and participant record for every character on the game. It does not touch linked jobs. Confirmation is a simple "type the command again within 60 seconds," held in memory only (a server restart clears any pending confirmation).

## License

Add your license of choice here before publishing.
