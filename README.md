# Inklings

Inklings is a plugin for [AresMUSH](https://aresmush.com) that gives players and staff a threaded system for tracking character development, plot hooks, requests, and secrets - separate from (but linked into) the normal job/ticket system.

## Features

- **Configurable types:** inkling types (hint, vision, goal, secret, progress, etc.) are defined in `game/config/inklings.yml`, not hardcoded - add, remove, rename, or redescribe them there. Run `+inkling/types` in-game for the current live listing.
- Every thread requires a title, whether started by a player or staff (matching `+inkling/new`'s `<title>/<text>` syntax)
- Messages can be public, private (to specific participants + staff), or GM-only notes
- Threads can be shared with individual characters or with everyone matching a demographics group
- Dice rolls (FS3, custom/static, or NPC rolls with a free-text NPC name) can be attached to any thread, with optional luck-point rerolls from the web portal
- Players build up a thread freely - staff see nothing until the player explicitly runs `+inkling/submit`, which locks the thread and sends its full contents to a single staff job. The thread remains locked while staff review it - only `+inkling/approve` (to approve) or `+inkling/needschanges` (to request revisions) change its status.
- Players can no longer delete their own thread outright - `+inkling/delete` closes it and files a job requesting staff approval for the permanent deletion
- Every message and roll gets a permanent reference number in the form `<inkling id>.<sequence>` (e.g. `14.3`) for pointing back at a specific entry later
- The thread view shows a "Shared With" section listing which non-staff characters and groups have access
- Names, titles, and inkling types are ansi-colored in in-game output (see [Using Formatting Codes](https://aresmush.com/tutorials/code/formatting.html))
- A structured approval workflow for submitted inklings: draft → submitted → approval (via staff decision) - staff can request changes to send back to player, or approve to end the review cycle
- Staff can grant rewards (XP, FS3 skills, or custom reward types) to characters in connection with their inklings, with configurable visibility (private to recipient, or visible to all thread participants)
- Optional periodic bonus XP (via a Cron job) for characters who've created a configured inkling type (Progress by default) - requires FS3Skills
- A native Ember web portal component (`inklings-tab`) for browsing/managing inklings - see "Chargen & Profile Web Integration" for installation
- Chargen and app-review hooks that require a secret and a goal inkling before a character can be approved
- A coder-only, double-confirmation `+inkling/reset` command for wiping the system during development/testing

## Installation

1. Copy the `plugin/` folder into your game's `plugins/inklings/` directory.
2. See **"Chargen & Profile Web Integration"** below for the web portal side - it's a native Ember component plus a couple of small merge-in snippets, none of which are a simple drop-in-and-restart step.
3. Copy `game/config/inklings.yml` into your game's `game/config/` directory, or merge its contents into an existing config if you already have one.
4. Restart your game.
5. In-game, create the job category Inklings expects:
   ```
   job/createcategory INKLINGS
   job/categoryroles INKLINGS=<roles that should see inkling-related jobs>
   ```
6. Confirm the `manage_game` permission exists and is assigned to your Coder role, since `+inkling/reset` depends on it. See [Using Permissions in Code](https://aresmush.com/tutorials/manage/roles.html#using-permissions-in-code) if you need to add it.

## Chargen & Profile Web Integration

The web portal side is now native AresMUSH (classic Ember - `.hbs` templates + `.js` component classes), not the earlier React reference version. It's split into two independent pieces:

1. **A real, self-contained `inklings-tab` component** (`webportal/app/components/inklings-tab.js` + `webportal/app/templates/components/inklings-tab.hbs`) with the full browsing/reply/roll/share/close/delete/submit feature set. It talks to the game via AresMUSH's own cmd-dispatch web request system (`plugin/web/*.rb`, see "Web Request Handlers" below) and saves its own changes immediately, so it does **not** need to participate in AresMUSH's [Custom Character Fields](https://www.aresmush.com/tutorials/code/hooks/char-fields.html) hook or the Profile page's save flow at all - it only needs to be *displayed* somewhere.
2. **A small Custom Character Fields integration** for just the two chargen-required fields (secret, goal), since that hook is genuinely designed for simple fields - the tutorial's own worked example is a single "goals" text box - not a full threaded-messaging UI.

### Web Request Handlers

AresMUSH dispatches web portal requests by a `cmd` name to a handler class with a `handle(request)` method (`request.cmd`/`request.args`), registered via a plugin's `get_web_request_handler` - the same pattern as `get_cmd_handler` for in-game commands. See [Plugins](https://www.aresmush.com/tutorials/code/plugins.html) and [Debugging Web Requests](https://www.aresmush.com/tutorials/code/web-debug.html). Plugin folders also have a distinct `web/` directory for this (separate from `public/`, which is for Ruby interfaces *other plugins* call - not for HTTP).

This plugin registers 11 handler classes in `plugin/web/`, wired up via `Inklings.get_web_request_handler` in `plugin/inklings.rb`. Every one of them is a thin adapter that unpacks `request.args` and calls straight into `InklingApi`/`RollsApi` (`plugin/public/`) - all the actual logic still lives there, unchanged.

**What's verified vs. not:** the server-side half of this (handler classes, `get_web_request_handler`, the `plugin/web/` folder convention) is confirmed against AresMUSH's own documentation. What is **not** independently verified is the exact client-side transport - the `inklings-tab` component's `callServer()` method posts `{ cmd, args }` as JSON to a single `/api/web` endpoint as a reasonable default, but if your `ares-webportal` app issues cmd-based requests differently (a dedicated injected service, a different endpoint, a different envelope shape), adjust `callServer()` to match - it's the one method everything else in the component calls through, so it's a single-point fix. One more explicitly-flagged gap: rerolling a roll with luck needs to compute the actual reroll result via FS3Skills' own web handler first (not something this plugin owns), and `character_luck_reroll` in `rerollWithLuck()` is a **guess** at that cmd's name - check FS3Skills' `plugin/web/` handlers on your install and correct it if it differs.

### Installing the `inklings-tab` component

Copy into your `ares-webportal` checkout, preserving the paths:

| From this plugin | To your `ares-webportal` |
|---|---|
| `webportal/app/components/inklings-tab.js` | `app/components/inklings-tab.js` |
| `webportal/app/templates/components/inklings-tab.hbs` | `app/templates/components/inklings-tab.hbs` |
| `webportal/app/helpers/*.js` (7 files) | `app/helpers/` |
| `webportal/app/styles/inklings-tab.css` | append into your main stylesheet (e.g. `app/styles/app.scss`) - Ember apps typically compile one global stylesheet rather than loading per-component CSS files |

The 7 helper files (`eq`, `and`, `or`, `not`, `format-date`, `join-list`, `join-list-upper`) exist because those aren't built into core Ember (only `{{get}}`, `{{if}}`, `{{each}}`, `{{with}}`, `{{action}}`, `{{input}}`, `{{textarea}}` are) - they're shipped rather than assuming an addon like `ember-truth-helpers` is already installed on your game.

Then invoke it from wherever you want it to appear - see `webportal/snippets/profile-custom-tabs.snippet.hbs` and `profile-custom.snippet.hbs` for the two small merge-in fragments that add it as its own tab on the character Profile page:

```hbs
{{inklings-tab characterId=this.char.id viewerId=this.viewer.id isStaff=this.viewer.isStaff}}
```

Everything in `webportal/snippets/` is a **fragment to merge into an existing shared file**, not a complete file to drop in and overwrite - `profile-custom-tabs.hbs`/`profile-custom.hbs` are single shared files per game, and other plugins may already have their own tabs defined there.

### Installing the chargen secret/goal fields

`chargen_hook.rb` requires a secret and goal inkling before chargen can complete, but only the actual Custom Character Fields hook can put those fields into the chargen web flow itself. Merge these snippets into your game's existing shared hook files:

| Snippet | Merges into |
|---|---|
| `webportal/snippets/chargen-custom-tabs.snippet.hbs` | `ares-webportal/app/templates/components/chargen-custom-tabs.hbs` |
| `webportal/snippets/chargen-custom.snippet.hbs` | `ares-webportal/app/templates/components/chargen-custom.hbs` |
| `webportal/snippets/chargen-custom.snippet.js` | `ares-webportal/app/components/chargen-custom.js` |
| `webportal/snippets/custom_char_fields.snippet.rb` | `plugins/profile/custom_char_fields.rb` |

Since secret/goal both require a title (matching `+inkling/secret <title>/<text>` and `+inkling/goal <title>/<text>` in-game), the chargen form collects four fields (title + text for each) rather than the tutorial's single "goals" box. The Ruby snippet's `save_inkling_field` helper calls into `InklingApi.create_inkling`/`reply_to_inkling` rather than writing to the `Inkling` model directly, so chargen submissions still go through this plugin's normal validation and title requirements.

**A verified note on file paths:** AresMUSH's own tutorial series is inconsistent about exactly where each hook's `.hbs` lives - Profile Display and Chargen templates live under `app/templates/components/`, while Profile Edit's live under `app/components/` (alongside their `.js`). The paths above match what's actually documented for each hook; if your install's directory layout differs, treat these as strong defaults to verify against your own `ares-webportal` checkout rather than as absolute certainties.

For a full worked example of wiring a field through this entire pipeline end-to-end, see AresMUSH's own step-by-step series: [Modifying the Web Portal](https://www.aresmush.com/tutorials/code/add-web) (its example field is literally called "Goals").

## Commands

See `plugin/help/player/inklings.md` and `plugin/help/admin/managing_inklings.md` for the full command reference, or run `help inklings` / `help managing inklings` in-game once installed.

Quick reference:

| Command | Who | Purpose |
|---|---|---|
| `+inklings` | Everyone | List your open inklings (`/closed`, `/all`) |
| `+inkling/types` | Everyone | List available inkling types with descriptions, live from config |
| `+inkling <id>` | Participants + staff | View a thread |
| `+inkling/new <kind>=<title>/<text>` | Players (own) / staff | Start a titled thread |
| `+inkling/hint`, `/vision`, `/nudge`, `/hook <char>=<title>/<text>` | Staff | Start a staff-initiated thread |
| `+inkling/secret <title>/<text>` or `<char>=<title>/<text>` | Players / staff | Start a secret thread |
| `+inkling/advance <id>=<text>` | Participants + staff | Add a visible update |
| `+inkling/private <id>=<text>` or `<name>/<text>` | Participants + staff | Add a private entry |
| `+inkling/gm <id>=<text>` | Staff | Add a staff-only note |
| `+inkling/roll <id>=<roll>` | Participants + staff | Attach a roll |
| `+inkling/submit <id>` | Owner + staff | Lock the thread and send it to staff as a single job - nothing reaches staff before this |
| `+inkling/approve <id>[=<msg>]` | Staff | Approve a submitted inkling, close the linked job, and lock it |
| `+inkling/needschanges <id>=<feedback>` | Staff | Send a submitted inkling back to the player for revisions, unlock it, and close the job |
| `+inkling/reward <id>=<type>:<amount>` | Staff | Grant a reward (e.g. `xp:5` or `fs3_skill:Skill:1`) to the inkling's subject character; use `/all` flag to make it visible to all participants |
| `+inkling/share <id>=<char>,<char>` | Owner + staff | Grant access to specific characters |
| `+inkling/group <id>=<group>,<group>` | Owner + staff | Grant access to a demographics group |
| `+inkling/close <id>` | Owner + staff | Close a thread |
| `+inkling/delete <id>` | Owner + staff | Staff: delete immediately. Players: close + request staff approval |
| `+inkling/list <char>` | Staff | List all of a character's threads |
| `+inkling/reset` | `manage_game` permission only | Wipe the entire system (type twice to confirm) |

## Approval Workflow

Inklings follow a structured review process once submitted to staff:

1. **Draft** (initial state) - Player builds the thread freely. Staff can't see it. Player can edit/add to it anytime.
2. **Submitted** - Player runs `+inkling/submit <id>`, which locks the thread and sends its full contents to staff as a single job.
3. While submitted:
   - **Staff can reply** via `+inkling/advance` or `+inkling/private` for discussion - these replies are visible to the player but do NOT unlock the thread or change its approval status.
   - **Player can view** the thread and staff replies, but cannot add new updates.
   - **Staff can approve** via `+inkling/approve <id>` to end the review (closes the linked job, marks as approved).
   - **Staff can request changes** via `+inkling/needschanges <id>=<feedback>` to unlock the thread for player revisions.
4. **If sent back for changes** - Thread unlocks, player can edit/revise and resubmit, repeating the process.
5. **If approved** - Thread remains locked (review complete), linked job closes.

Staff can also grant rewards during or after review via `+inkling/reward <id>=<type>:<amount>`, which records the reward in the thread history and applies it if applicable (e.g., XP via FS3Skills).

## Configuration

`game/config/inklings.yml` (see the file itself for full inline comments):

```yaml
inklings:
  shortcuts: {}
  job_category: INKLINGS
  types:
    hint: { category: staff, name: Hint, description: "..." }
    # ...one entry per type...
  inkling_type_xp: progress
  xp_amount: 1
  award_cron:
    day_of_week: [Sat]
    hour: [21]
    minute: [0]
```

- `job_category` - the job category new inkling threads are linked into. Defaults to `INKLINGS` if omitted.
- `types` - the full list of valid inkling types. See "Inkling Types" below.
- `inkling_type_xp`, `xp_amount`, `award_cron` - the optional bonus-XP cron feature. See "Bonus XP" below.

Permission checks live in `plugin/inklings.rb`:

- `Inklings.can_manage_inklings?(enactor)` - governs ordinary staff-side access (starting staff threads, GM notes, viewing/managing any thread). Defaults to reusing the Jobs plugin's `Jobs.can_manage_jobs?` check.
- `Inklings.can_reset_system?(enactor)` - governs the destructive `+inkling/reset` command. Checks the `manage_game` permission directly, which is normally only granted to Coders (Admins implicitly have every permission).

Adjust either method if your game's staff/coder structure differs from the defaults.

## Inkling Types

Types are entirely config-driven (`game/config/inklings.yml`, under `types`) rather than hardcoded - add, remove, rename, or redescribe them without touching code. Each entry has a `category` (`staff`, `player`, or `shared` - see the inline comments in the config file for what each means), a `name`, a `description`, and an optional `chargen: true` flag. Run `+inkling/types` in-game to see the current live listing, always pulled straight from config so it can never drift out of sync with a doc page.

`Inklings.staff_kinds`, `.player_kinds`, `.shared_kinds`, `.all_kinds`, `.chargen_kinds`, `.valid_kind?`, `.kind_label`, and `.kind_description` (all in `plugin/inklings.rb`) read this config; nothing else in the plugin hardcodes the type list.

## Bonus XP

An optional feature that periodically awards bonus XP to characters who've submitted a configured inkling type, via a [Cron job](https://www.aresmush.com/tutorials/code/cron.html). Requires the **FS3Skills** plugin - if it isn't loaded, the cron job is a complete no-op (checked with `defined?(FS3Skills)`).

**Config** (`game/config/inklings.yml`):

- `inkling_type_xp` - the inkling type that qualifies for the bonus. **Defaults to `"progress"`**, a player-created inkling type for personal character development records. Characters who create progress entries earn the bonus XP, with no need to submit them to staff.
- `xp_amount` - bonus XP per qualifying character per award period. Default `1`.
- `award_cron` - standard Ares cron config controlling how often the cycle runs. Default is weekly, Saturday 9pm. Set to `{}` to disable without removing the other settings.

**How it works:** `InklingXpCronHandler` (`plugin/events/`) handles the engine's `CronEvent`, checks it against `award_cron` via `Cron.is_cron_match?`, and if it matches, calls `Inklings.run_xp_award_cycle`. That method walks every approved character, and for anyone who has *created* an inkling of the configured type since the last cycle completed, calls `FS3Skills.modify_xp(char, xp_amount)` - the same helper FS3's own XP-granting code uses ([`plugins/fs3skills/helpers/xp.rb`](https://github.com/AresMUSH/aresmush/blob/master/plugins/fs3skills/helpers/xp.rb)) - rather than reimplementing XP logic here.

**Note on the job workflow change:** eligibility here is based on when an inkling was *created* (`Inkling#created_at`), not on `+inkling/submit`. A character can create a matching inkling, never submit it, and still earn the bonus. If you'd rather reward actual staff-facing engagement (i.e. only inklings that were submitted at least once), that's a straightforward change to `Inklings.run_xp_award_cycle` - check for an `InklingMessage` or a submitted state instead of `Inkling#created_at` - but it isn't implemented that way currently.

**Duplicate prevention:** each award cycle is identified by a `period_start` timestamp that only advances once the *entire* cycle finishes (tracked in the `InklingXpCronState` singleton record). Every award is logged in `InklingXpAward` (character + that cycle's `period_start`). If the cycle is interrupted partway through - a crash, a restart, or the cron firing again before `period_start` advances - a retry reuses the same `period_start`, and characters who already have an award record for it are skipped, so only the remaining, not-yet-processed characters get evaluated. (The one accepted residual risk: a crash in the narrow window between granting XP and writing that character's award record could in theory cause one extra award for that one character - intentionally accepted as a far smaller problem than silently never rewarding someone.)

On the very first run ever (no prior `InklingXpCronState`), the eligibility window looks back 1 week rather than the game's entire history, so turning the feature on doesn't suddenly sweep in and reward every matching inkling ever created.

## Color Conventions

Per [Using Formatting Codes](https://aresmush.com/tutorials/code/formatting.html), in-game output (list rows, thread view, warnings, share/group confirmations) colors:

- **Names** (character and group names) - cyan (`%xc`)
- **Titles** - green (`%xg`)
- **Inkling Types** (kind labels like `HINT`, `GOAL`, `SECRET`) - magenta (`%xm`)

These are implemented as `Inklings.color_name`, `Inklings.color_title`, and `Inklings.color_type` in `plugin/inklings.rb`. They're deliberately only applied to text emitted directly to a client (`client.emit_success`, `notify_player`, etc.) - never to persisted data like `Inkling#title` or Job titles, since those get read back by other systems (the Jobs web view, this plugin's own web portal JSON API) that shouldn't have to deal with raw ansi escape codes.

## Lifecycle Hooks

Other plugins can listen for inkling lifecycle events via AresMUSH's `Global.dispatcher` mechanism. This plugin fires the following events:

- **`inkling:created`** - when a new inkling is created. Passed: the `Inkling` object.
- **`inkling:submitted`** - when a player submits an inkling for staff review. Passed: the `Inkling` object.
- **`inkling:approved`** - when staff approves an inkling. Passed: the `Inkling` object, the staff `Character` who approved it.
- **`inkling:needs_changes`** - when staff sends an inkling back for revisions. Passed: the `Inkling` object, the staff `Character` who requested changes.
- **`inkling:shared`** - when an inkling is shared with a character. Passed: the `Inkling` object, the `Character` it was shared with.
- **`inkling:rewarded`** - when a reward is granted to an inkling. Passed: the `Inkling` object, the `InklingReward` object.

A listening plugin can register handlers like this:

```ruby
def self.on_inkling_approved(inkling, staff)
  # Handle inkling approval
end

Global.dispatcher.add_event_handler("inkling:approved", method(:on_inkling_approved))
```

These hooks are **dispatch-only** - they do not alter inkling behavior, and the listening plugin cannot prevent the event or modify the inkling.

## Auditing & Timestamps

Inkling records include the following timestamps for auditing:

- `Inkling#created_at` - when the inkling was first created.
- `Inkling#updated_at` - when the inkling's metadata last changed (status, approval state, locks, shared access, tags). Updated whenever the inkling record is modified.

Message, roll, reward, and participant records have immutable semantics - they record `created_at` but not `updated_at`, since they're never modified after creation.

## Verification Notes

This plugin's core APIs (`Jobs`, `FS3Skills`, `Character`, `CommandHandler`, `Ohm`/`ObjectModel`, `get_cmd_handler`/`get_event_handler`/`get_web_request_handler`, the `plugin/web/` handler pattern) were checked against AresMUSH's own documentation and the real `FS3Skills` source rather than assumed. Specifically confirmed:

- `Jobs.create_job(category, title, description, author)` and `Jobs.close_job(enactor, job, message)` - confirmed twice, against both the "Common APIs" tutorial and real usage in `fs3skills/helpers/xp.rb`. Exact match to how this plugin calls them.
- `FS3Skills.modify_xp(char, amount)` - confirmed against the actual source at `plugins/fs3skills/helpers/xp.rb`. Exact match.
- `character.has_permission?("...")` - confirmed via the same FS3 source (`can_manage_xp?` uses `actor.has_permission?("manage_abilities")`), matching this plugin's use of it for `can_reset_system?`.
- The `get_web_request_handler(cmd_name)` pattern and the `plugin/web/` folder - confirmed against the official Plugins and Debugging Web Requests docs. **This was a real gap that got fixed during this verification pass**: earlier versions of this plugin's web API lived only in `plugin/public/` (correct location per the docs for *inter-plugin Ruby interfaces*, e.g. `Jobs.create_job`) and was called from the Ember component via invented REST-style URLs (`/api/characters/:id/inklings`) that were never actually reachable - `public/` is not automatically web-routable. `plugin/web/*.rb` now provides 11 real handler classes registered via `get_web_request_handler`, each a thin adapter into the unchanged `InklingApi`/`RollsApi` logic.

Not independently confirmed, called out explicitly where they matter most:

- **The client-side transport** the `inklings-tab` Ember component uses to issue a cmd-based request (`callServer()`, posting `{cmd, args}` to `/api/web`) - the server-side half of this contract is verified; the exact URL/envelope your `ares-webportal` actually expects is not. See "Web Request Handlers" above.
- **`character_luck_reroll`**, the presumed FS3Skills cmd name used by the reroll-with-luck flow - explicitly flagged as a guess in the code and in "Web Request Handlers" above, since it belongs to FS3Skills, not this plugin.
- `Jobs.can_manage_jobs?` and `Jobs.comment(job, actor, message, admin_only)` - not found verbatim in the pages checked, but strongly consistent with the documented `<Plugin>.can_manage_<plugin>?` naming convention shown for other plugins, and were already present in this plugin's code before this verification pass.
- **API method organization**: this plugin nests its public API methods in `InklingApi`/`RollsApi` classes (`Inklings::InklingApi.create_inkling`) rather than directly on the plugin module (`Inklings.create_inkling`, matching how `Jobs.create_job` is actually structured per the docs). Functionally fine either way - `public/inklings_api.rb` is still the correct file location - but it's a style deviation from the idiomatic convention, inherited from this plugin's original structure rather than introduced during verification.

## Known Limitations / Things to Verify Before Production Use

- **The lock only blocks replies, private replies, and rolls** (`+inkling/advance`, `+inkling/private`, `+inkling/roll` and their web equivalents) for non-staff. `+inkling/share`, `+inkling/group`, `+inkling/close`, and `+inkling/delete` all still work on a locked thread, since none of those are "building up content for staff to review" - a player can still close or request deletion of a thread that's awaiting a response, for example. Adjust the relevant commands' `check_not_locked` if you want a stricter scope.
- **Resubmitting sends the whole thread again, not just what's new.** `+inkling/submit` always compiles and sends/mirrors the *entire* current thread, every time - so a second submission after a back-and-forth will repeat earlier messages in the job's comment history rather than showing only the delta. This was a deliberate simplicity choice (see `Inklings.compile_thread_text`/`submit_inkling`) rather than tracking exactly which messages were already sent in a prior submission.
- **Approval decisions (approve/needschanges) can only be made on submitted inklings.** Only `+inkling/approve` and `+inkling/needschanges` change the approval state. Ordinary staff replies via `+inkling/advance` or `+inkling/private` add discussion but do not unlock the thread or change approval status - they're meant for back-and-forth discussion, not decisions.
- **Reward types are generic.** The reward system records `reward_type` as a free-form string (e.g. "xp", "fs3_skill"), not an enum. This plugin automatically applies "xp" rewards via FS3Skills if installed, records "fs3_skill" rewards for staff to apply manually, and records any other custom `reward_type` for future plugins (e.g. SOUL, Boons, Banes) to pick up - no schema changes needed if you add a new reward system later.
- **Bonus XP eligibility is based on when an inkling was created, not on `+inkling/submit`.** See the note in "Bonus XP" above - a character can create a qualifying inkling, never submit it, and still earn the bonus under the current implementation.

- **The `inklings-tab` Ember component's client-side request transport is a best-effort default, not fully verified** - see "Web Request Handlers" above. The server-side handler classes and `get_web_request_handler` registration *are* verified against AresMUSH's own docs; the exact way your `ares-webportal` issues a cmd-based request from the client is the one piece to double-check.
- **The merge-in snippets in `webportal/snippets/` assume a Bootstrap-style tab structure** (`nav-item`/`nav-link`/`tab-pane`/`data-toggle="tab"`) matching what AresMUSH's own tutorial examples use. If your game's Profile/Chargen pages use a different tab component, adapt the markup rather than pasting it verbatim.
- **`plugin/events/job_reply_event_handler.rb` is unconfirmed scaffolding.** There's no documented event fired when a `JobReply` is added in stock Ares, so the event class name and field names in that file are best-effort guesses. The plugin does **not** currently rely on this handler being wired up - instead, `Inklings.sync_job_replies` pulls in new job replies on demand whenever a thread is viewed or listed. If you want push-based notification instead, check `plugins/jobs/public/*.rb` on your install for the actual event Jobs fires (if any) and update this handler + `Inklings.get_event_handler` to match before enabling it.
- **FS3 integration is optional.** `+inkling/roll` requires `FS3Skills.parse_and_roll` to exist; if your game doesn't use FS3, that command will report the roll system as unavailable, but the rest of the plugin works fine without it.
- **Luck rerolls assume a `luck` attribute** (`char.luck`) on your character model, used by the web portal's reroll button. If your game doesn't track luck points, that feature is a no-op/error from the API side - the rest of the roll system doesn't depend on it.
- **`seq` (the `14.3`-style reference number) is not backfilled** for inklings created before this plugin adopted it. If you're upgrading an existing install with pre-existing data, write a one-off migration that walks every `Inkling`, sorts its `messages` and `rolls` by `created_at`, and assigns `seq` in order before relying on references being complete for old threads.
- **`+inkling/reset` is irreversible** and deletes every inkling thread, message, roll, and participant record for every character on the game. It does not touch linked jobs. Confirmation uses a one-time token: running the command displays a token to copy, and re-running it with that token performs the reset. The token expires after 5 minutes and is held in memory only (a server restart clears any pending confirmations).
- **A character's inklings are looked up via an explicit `Inkling.find(character_id: ...)` query, not `char.inklings`.** An earlier version of this plugin used a `collection :inklings` reverse-reference macro on `Character`, which was found to sometimes return the wrong character's threads (e.g. staff seeing their own list instead of the target's when running `+inkling/list`). If you're extending this plugin, keep using the explicit query rather than reintroducing that macro.
- **NPC rolls accept a free-text name** (`npc_name` on `InklingRoll`) that isn't tied to any `Character` record, for NPCs without a character sheet. The web portal's NPC roll form uses this by default; `npc_char_id` is still available for API callers who want to link an actual `Character`.
- **Bonus XP requires FS3Skills.** `Inklings.run_xp_award_cycle` checks `defined?(FS3Skills)` and does nothing at all if that plugin isn't loaded - it never falls back to any other XP system.
- **Bonus XP eligibility is "approved characters," full stop** - it doesn't currently exclude staff-permission characters, since a staff member's own PC arguably still deserves XP for playing. Narrow `run_xp_award_cycle`'s `Character.all.to_a.select { |c| c.is_approved? }` filter if you want a different definition of "eligible."

## License

Add your license of choice here before publishing.
