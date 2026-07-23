# AresMUSH Plugin Development Guide

A development reference for building and maintaining AresMUSH plugins, distilled
from the Inklings project. This is **not** an Inklings design document — it
captures conventions, architecture, and lessons that apply to any AresMUSH
plugin (Grimoire, SOUL, or whatever comes next).

Treat this as a starting checklist, not a substitute for verifying against
current Ares source before you write code.

---

## Git Workflow

**Always push work to `main`.** Do not use feature branches for completed work.

`plugin/install <url>` installs from the repository's default branch (`main`),
not from feature branches or development branches. A fix or feature that only
exists on a `claude/...` or other working branch is invisible to plugin
installation and updates — a user running `plugin/install` will not receive the
change even if the branch is pushed to GitHub. The failure mode is confusing
(no error, just missing functionality), so this rule exists to prevent it.

After completing any task:
1. Run `git status` and review all changes
2. Commit with a clear, descriptive message
3. **Push to main:** `git push origin main`
4. Report the commit hash and push status

**Never leave completed work only on a feature branch.** Merge it to main and
push before marking the task complete.

---

## 1. Core Philosophy

1. **Follow existing AresMUSH conventions before inventing anything.** If Ares
   already has a pattern for a problem (routing, data loading, custom fields,
   formatting, permissions), use it. A plugin that "feels native" reuses the
   host application's plumbing instead of building parallel plumbing next to it.

2. **Verify APIs against actual Ares source code, not memory or tutorial
   prose.** Tutorials describe the general shape of a system; they go stale,
   omit details, and sometimes describe an older API. The checked-in source of
   `aresmush/aresmush` and `aresmush/ares-webportal` is the only thing that's
   actually running. When in doubt, read the code that will execute, not a
   description of it.

3. **Prefer existing helpers and hooks over custom implementations.** Before
   writing a helper, a formatter, a filter, or a lifecycle hook, check whether
   Ares (or the specific bundled addon it ships, like `ember-truth-helpers`)
   already provides it. Every custom helper is something a future maintainer
   has to learn instead of already knowing.

4. **Keep MUSH and Web functionality in parity.** Whatever a player or staff
   member can do from the MUSH command line, they should be able to do from
   the web portal (and vice versa), assuming the plugin ships web
   integration. Treat the MUSH command set as the authoritative feature list;
   the web layer is a second front end onto the same backend logic, not a
   separate feature surface.

   **MUSH-only commands (documented exceptions on this plugin):** Not every
   command needs a web equivalent - the rule is about *functionality*, not
   every individual command. A handful on this plugin are intentionally
   MUSH-only, for two different reasons:

   *Command-line convenience for something the web already fully exposes a
   different way* (by explicit direction; nothing is hidden from the web
   that these reveal):
   - `+inkling/new` (bare, no args) - `InklingNewUnreadCmd`. Cycles through
     unread inklings one at a time, bbnew-style. The profile tab's list
     already shows unread state per-thread - this is just a MUSH-idiom
     convenience for stepping through them one at a time on the command
     line.
   - `+inkling/comment <ref>` - `InklingCommentCmd`. Jumps straight to one
     numbered entry (`<inkling_id>.<seq>`, e.g. `3.4`) without showing the
     rest of the thread. The web detail view already shows every entry
     inline with its ref number.
   - `+inkling/view-secret`, `+inkling/view-goal` - `InklingViewChargenDraftCmd`.
     Read-only view of your own chargen draft before approval. The web
     chargen "Secret & Goal" tab is the same data, read/write, live -
     these two commands exist for players who prefer the MUSH client
     during chargen.

   *Deliberately kept off the web UI, not a parity gap at all:*
   - `+inkling/reset` - `InklingResetCmd`. A destructive, confirmation-token-
     gated wipe of every inkling thread in the game, restricted to
     `manage_game` (Coders/Admins). This is the one command on this plugin
     where *not* having a one-click web equivalent is the point.

   When adding a new MUSH command, default to also giving it a web path
   (or explicitly note here why not) - these are exceptions because a
   *command-line-specific convenience for reaching content the web already
   fully exposes*, or a *deliberately-not-web-accessible destructive action*,
   is different from a capability gap. Don't use "it's MUSH idiom" to justify
   skipping a web equivalent for something the web portal genuinely can't do
   yet - that's still a parity gap, and belongs in the README's Known
   Limitations instead.

5. **Minimize duplicated logic between Ruby and Ember.** Authorization
   checks, filtering rules, and formatting decisions should exist in exactly
   one place — almost always Ruby, since that's where the MUSH command side
   already has to implement them. If a JS computed property re-derives a
   permission check that a Ruby method already performs, one of them will
   drift out of sync with the other. It's not a question of if, only when.

6. **Keep the web layer as thin as possible.** Ember components should bind
   to data, dispatch actions, and render — not decide who's allowed to do
   what, not reshape API payloads, not carry business rules. If a template
   helper or component method is doing anything more sophisticated than
   `{{if}}`/`{{eq}}`-level branching, ask whether that logic belongs server-side.

7. **Push business logic into Ruby where appropriate.** Ruby is where
   authorization, validation, and cross-cutting rules (config-driven types,
   permission checks, formatting for different viewers) belong, because it's
   the side that already has access to the full data model and is already
   the enforcement point for the MUSH commands.

---

## 2. Research Process

Start every plugin task — new feature or bug fix — with research, in this
order:

1. **Read the official tutorials** at `aresmush.com/tutorials/code/`. They
   give you the vocabulary and the intended shape of a system (Routes vs.
   Components, GameApi, custom fields, hooks). Treat them as an index, not
   ground truth.

2. **Check the current Ares source.** Clone or fetch (via GitHub API/raw URLs
   if you don't have a local checkout) `AresMUSH/aresmush` (the core engine —
   bundled plugins live under `plugins/<name>/`) and `AresMUSH/ares-webportal`
   (the Ember app — this is where `GameApi`, routes, mixins, and the
   `profile-*`/`chargen-*` extension-point components actually live). **This
   is the authoritative source.** When a tutorial and the current source
   disagree, the source wins — the tutorial is describing a version of Ares
   that may no longer exist.

   **`AresMUSH/aresmush` and `AresMUSH/ares-webportal` are read-only
   reference material — always.** Fetch and read them freely to verify
   real behavior (that's the whole point of this step), but never write to
   them: no commits, no branches, no forks, no pull requests against
   either repo. This project's job is a third-party plugin that consumes
   that source, not a contribution to it — any change belongs in
   `ares-inklings-plugin` (this repo), reflected either in the plugin code
   itself or, when the fix genuinely lives in a shared file the game owner
   already customizes, in `custom-install/`.

3. **Compare bundled plugins.** Core plugins like Jobs (`plugins/jobs/` in
   `aresmush`, plus `app/routes/job*.js` / `app/controllers/job*.js` /
   `app/templates/job*.hbs` in `ares-webportal`) show the full Route +
   Controller + Template pattern for a first-class page, including
   `RSVP.hash()` for parallel `gameApi` calls, `response.error` handling, and
   `this.send('reloadModel')` for refreshing after a mutation. FS3Skills and
   FS3Combat show web-handler dispatch conventions at scale.

4. **Compare high-quality third-party plugins.** Bundled plugins are often
   core-hardcoded into routes a real plugin can't touch (see Scenes below).
   For patterns a *third-party* plugin can actually replicate, look at real
   community plugins — `AresMUSH/ares-rpg-plugin` and
   `cailleach1310/ares-marque-plugin` were both directly useful during this
   project:
   - `ares-rpg-plugin`'s `webportal/components/rpg-profile.js` is nearly
     empty (`tagName: ''`) and reads `this.char.rpg.sheet` directly — no
     component-level data fetch at all.
   - `ares-rpg-plugin`'s `webportal/components/rpg-chargen.js` shows the
     `onUpdate()` callback-registration pattern chargen extensions use.
   - `ares-marque-plugin`'s `webportal/components/profile-dowayne.js` reads
     `@house` (bound from `this.char.custom.house_list`) with zero `gameApi`
     calls for initial data, and only calls `gameApi` from user-triggered
     actions.
   These two examples are what revealed that **third-party profile-tab
   components do not self-fetch their initial data** — see §3.

5. **Verify assumptions before implementing, not after.** If you write code
   that assumes an event name, a field name, or an API shape you haven't
   confirmed, say so in a comment and flag it for verification — don't let
   an assumption silently masquerade as a confirmed fact. (Inklings'
   `plugin/events/job_reply_event_handler.rb` is a good model for how to do
   this honestly: it's explicitly commented as "scaffolding, not a confirmed
   working implementation," names exactly which file to check to confirm the
   real event/field names, and explains why. That kind of comment is a gift
   to whoever picks the file up next — including future you.)

**When tutorials and current source disagree, current source is
authoritative — full stop.** Concretely on this project: the tutorial's
description of `GameApi` didn't mention that `requestOne`/`requestMany`
already flash `response.error` automatically, or that `requestMany` calls
`.map()` on the raw response (i.e. only works against endpoints that return a
bare array). Both facts only became clear from reading
`ares-webportal/app/services/game-api.js` directly, and both were load-bearing
for a real bug.

---

## 3. Web Portal Conventions

### Chargen Extension Components

When a plugin needs to add form fields to the chargen process, use copy-paste snippets,
NOT auto-installed components. This is a critical distinction from profile tabs.

**Pattern:** Provide merge snippets under `custom-install/` for:
- `chargen-custom-tabs.snippet.hbs` — paste into game's `chargen-custom-tabs.hbs`
- `chargen-custom.snippet.hbs` — paste into game's `chargen-custom.hbs`
- `chargen-custom.snippet.js` — paste into game's `chargen-custom.js`

**Critical:** Do NOT auto-install `chargen-custom.js` or `chargen-custom.hbs` as plugin files.

**Why:** These are shared game customization files, not plugin-owned extension points:
- `chargen-custom.js` and `.hbs` already exist in standard AresMUSH webportal installations
- The game owner or other plugins may have customized them
- Auto-installing plugin replacements at these paths **overwrites existing game code**
- This breaks the game owner's chargen setup and interferes with other plugin integrations

**Correct pattern:**
1. Custom fields hook (manual paste): `custom_char_fields.rb` snippet defines `get_fields_for_chargen`
2. Frontend hook (manual paste): `chargen-custom.snippet.*` files guide user to paste field
   definitions into existing game-owned files
3. Enforcement, if any, happens through hooks confirmed to actually exist and be
   auto-discovered - `get_app_review_issues(char)` (a top-level plugin-module method
   AresMUSH's app-review system calls automatically; see `AppReviewApi` in this
   project) flags missing/incomplete fields to staff during review, and
   `custom_approval` (a manual-snippet hook, fired once `char.is_approved` is
   already true - see `Inklings.convert_chargen_drafts`) is where this project
   converts draft fields into real records post-approval. Neither of these
   *blocks* the player from finishing chargen itself - see Lesson 33 below for
   why an earlier, unconfirmed `chargen_finalize` hook that tried to do exactly
   that never actually worked (and was since removed).

**Integration flow:**
- `get_fields_for_chargen` returns `{ inkling_secret_title: ..., inkling_goal_title: ..., ... }`
- These appear on char as `char.custom.inkling_*`
- Game's `chargen-custom.hbs` renders form fields bound to these values
- Game's `chargen-custom.js`'s `onUpdate()` collects them and returns to chargen framework
- Chargen framework calls `save_fields_from_chargen` with the collected values
- Plugin's `save_fields_from_chargen` (via manual snippet) creates/updates inklings

**Chargen field layout pattern** (verified on this project):
For multi-field sections with title + description, use:
- `<h2>` heading for the section name
- Flex row (`d-flex align-items-center gap-2 mb-3` with `style="width: 98%;"`) with a plain `<label class="form-label mb-0">` beside a text input
- Textarea directly below for the description, with no separate label (use placeholder for guidance)
- `<hr class="my-4">` to divide sections

Note: The flex container needs `style="width: 98%;"` to match Ares' textarea width constraint, ensuring the input and textarea visually align.

This pattern keeps labels readable (plain labels inherit theme text color; avoid `input-group-text` which carries its own background), uses only Bootstrap utilities for spacing and alignment, and works across all Ares themes without plugin-specific CSS.

**Common mistake:** Assuming chargen-custom files don't exist and creating them as plugin files.
Instead, verify they're standard Ares files by checking the target webportal for their
presence. If absent, provide clear instructions for creating them manually, not auto-install.

### Merge-Safe Snippet Format

When providing code snippets for users to copy-paste into shared game files (`custom_approval.rb`,
`custom_app_review.rb`, `chargen-custom.hbs`, etc.), follow this pattern:

**Do NOT comment out the code that needs copying.** Users will copy-paste it directly,
and having to uncomment it is friction that invites copy-paste mistakes and misalignment.

**Pattern:**
```
# FILE: path/to/shared/file
# PURPOSE: brief description

# INSTALLATION STEPS
# ===================
# 1. Open path/to/shared/file in your game folder
# 2. Find the target method/location
# 3. Paste this line:

Actual.code_to_copy(here)

# EXAMPLE (what it should look like after pasting):
#
# def self.method(arg)
#   Actual.code_to_copy(here)
#   # Other code may be present here
# end
```

The actual code to copy is **always uncommented and ready to paste verbatim**. Comments and
examples below it explain context and show how it fits into the host file. This pattern works
for all merge-safe snippets: Ruby hooks, YAML config, Handlebars templates, JavaScript methods.

**Why:** Users copy-paste line-by-line. Commenting out the payload means:
- They have to remember to uncomment it (friction + error opportunity)
- The instruction "paste this" becomes incomplete — it implies "uncomment and paste"
- "Uncomment" is easy to miss in a wall of documentation
- Commented code looks inactive/wrong, discouraging copy-paste confidence

Instead, make the payload obvious and uncommented. Wrap explanation and examples in comments below it.

### The three shapes a screen can take

- **Full page** — its own URL, its own Route + Controller + Template. Route's
  `model()` uses `RSVP.hash()` to fire parallel `gameApi` calls and returns
  `EmberObject.create(model)`. Mutating actions live on the Controller. This
  is the Jobs pattern (`app/routes/job.js`, `app/controllers/job.js`,
  `app/templates/job.hbs` in `ares-webportal`).

- **Embedded widget on an existing page** (a profile tab, a chargen tab) —
  a plain `Component`, invoked from a manual-paste snippet
  (`profile-custom.hbs`, `chargen-custom.hbs`) into a slot the *game owner's*
  webportal checkout already has. This is what a plugin adding a profile or
  chargen tab actually builds. See below for how these get their data.

- **Reusable template snippet** — a Helper, for genuinely trivial, stateless
  presentation logic with no existing Ares equivalent. Check
  `ember-truth-helpers` (bundled: `eq`, `and`, `or`, `not`) and Ares's own
  helpers (`local-date`, `ansi-format`, `title`, `link-to`) before writing one.

### How a profile/chargen tab component gets its data (this was the big one)

For **static or small viewer-scoped reference data** (a sheet, a config-driven
type list, a small nested table), the idiomatic pattern — confirmed against
`ares-rpg-plugin` and `ares-marque-plugin`, and already half-used by this
plugin for chargen-required fields before this project extended it — is:

1. Ares core (`aresmush/plugins/profile/custom_char_fields.rb`) defines the
   hooks:
   ```ruby
   def self.get_fields_for_viewing(char, viewer)   # profile display
   def self.get_fields_for_editing(char, viewer)   # profile edit form
   def self.get_fields_for_chargen(char)           # chargen form
   def self.save_fields_from_profile_edit2(char, enactor, char_data)
   def self.save_fields_from_chargen(char, chargen_data)
   ```
   `get_fields_for_viewing`/`get_fields_for_editing` receive `viewer`, so
   permission-scoped fields are computed server-side, once, with the right
   viewer context.
2. A plugin implements these hooks by pasting code into the game's own
   `aresmush/plugins/profile/custom_char_fields.rb` — a **shared file** every
   plugin that wants custom fields adds to, which is exactly why this can
   only be a manual-paste snippet, never an auto-installed file (see §5).
3. Whatever hash keys those hooks return show up as `char.custom.<key>` on
   the *already-loaded* Character API response — no extra request.
4. The profile-tab component receives that data as a passed-in attribute
   (`{{my-tab someProp=this.char.custom.my_key}}`) and just reads it. No
   `didInsertElement`, no `gameApi` call, no loading state, no race.

For **genuinely dynamic, mutation-heavy, per-viewer-filtered data** (a list
of threads, each with its own messages and permissions) there is **no clean
route-level hook available to a third-party plugin**. Scenes gets exactly
this treatment on the character page (`app/routes/char.js` in
`ares-webportal` adds a `scenes: api.requestOne('scenes', {...})` key to its
own `RSVP.hash()`) — but that's because Scenes is hardcoded into core's own
route, not because there's a general extension point. A third-party plugin
can't edit `char.js`. In this situation, a self-fetching component
(`didInsertElement` → `gameApi` call) really is the best available option —
just implement it correctly (see the GameApi pitfalls below) and keep the
*type/config data* the component also needs out of that same fetch by using
the `char.custom.*` mechanism instead, so the crash-prone part of the load
(the dynamic list) is isolated from the part that doesn't need to be dynamic
at all (the type picker).

### GameApi — the exact contract (read `app/services/game-api.js`, don't guess)

```js
requestOne(cmd, args = {}, transitionToOnError = 'home')
requestMany(cmd, args = {}, transitionToOnError = 'home')
```

- **`requestOne`** is for a single object *or a composite hash* (e.g.
  `{ inklings: [...] }`, `{ inkling: {...} }`, `{ types: {...} }`). On
  success it wraps the whole response in `EmberObject.create(response)`. This
  is the default choice for almost every handler that returns `{ error: }` on
  failure and a shaped hash on success.
- **`requestMany`** calls `response.map(r => EmberObject.create(r))`
  **directly on the raw response** — it only works if the handler's success
  response *is* a bare JSON array, not a hash wrapping one. Using it against
  a handler that returns `{ inklings: [...] }` throws inside the service's
  own `.then()`, silently rejects the promise, and the caller never sees an
  error — the list just stays empty forever. **This was a real, shipped bug
  on this project.** Rule of thumb: if your Ruby handler's happy path is
  `{ some_key: [...] }`, use `requestOne` and read `.some_key` off the
  result. Only use `requestMany` against a handler whose happy-path return
  value is a literal array.
- **Both methods already handle the error path for you.** On
  `response.error`, the service calls `this.flashMessages.danger(response.error)`
  itself and (unless you pass `null` as the third arg) redirects. **You do
  not need to add your own `.catch()` or call `flashMessages` yourself for
  API errors** — you only need `if (response.error) { return; }` before
  touching the response data, to stop success-path code from running against
  an error-shaped object. Confirmed against Jobs' and Marque's own
  controllers/components, which follow exactly this shape:
  ```js
  api.requestOne('someCmd', { ... }).then((response) => {
    if (response.error) { return; }
    // ... use response.whatever here, not response itself
  });
  ```
- **Unwrap composite responses before using them.** If your Ruby handler
  returns `{ inkling: {...} }`, the resolved value in `.then()` is the whole
  wrapper — `response.inkling`, not `response`, is the actual record. Passing
  the wrapper straight into a helper that expects the record (e.g.
  `list.findIndex(i => i.id === updated.id)`) fails silently: `updated.id` is
  `undefined`, the find never matches, and the UI just doesn't update instead
  of throwing. **This was also a real, shipped bug on this project** — three
  separate actions passed the raw wrapped response into code expecting the
  unwrapped record. When you add a new action, write down the Ruby method's
  actual return shape next to the JS call site, or you will get this wrong.

### Web request handlers (Ruby side of the same contract)

Every plugin dispatches web requests the same way it dispatches commands and
events — by `cmd` name, through a `case`/`when` in the plugin module:

```ruby
def self.get_web_request_handler(request)
  case request.cmd
  when "my_plugin_do_thing"
    return MyPluginDoThingWebHandler
  end
  nil
end
```

Handler classes are thin: check login, unpack `request.args`, delegate to a
`public/*_api.rb` class that holds the actual logic (so the same logic is
reachable from MUSH commands and web handlers alike), and return a hash. Every
guard clause returns `{ error: "..." }` on failure — this is what `GameApi`
expects and automatically surfaces via `flashMessages`.

### Custom fields, profile hooks, chargen hooks

Covered in detail above — the single most important mechanism for getting
plugin data onto the profile page and chargen without a separate request.
Two things worth calling out explicitly because they're easy to get wrong:

- Merging a helper method's returned hash into a hash literal requires
  **double splat (`**`)**, not single splat (`*`). `{ a: 1, *some_hash }` is a
  hard Ruby `SyntaxError` (confirmed with `ruby -c`), not a runtime warning —
  if a snippet with this typo gets pasted into the game's shared
  `custom_char_fields.rb`, that file fails to load entirely, which can take
  down more than just your plugin's fields.
- `get_fields_for_viewing`/`get_fields_for_editing` receive `viewer` — use it.
  Computing a permission-filtered value once, server-side, in the hook is
  strictly better than shipping the unfiltered value and re-deriving the
  filter in Ember.
- **A custom character field has to be DECLARED before the hooks can touch
  it.** `char.my_field` / `char.update(my_field: ...)` only exist if some
  loaded file reopens `AresMUSH::Character` and calls `attribute :my_field`
  (see the char-fields and db-field tutorials). Ship that declaration as a
  plugin-owned model file — `plugin/models/<something>.rb` reopening
  `class Character` — since everything under a plugin's `models/` is
  auto-loaded. Skipping this produces a runtime `undefined method
  'my_field' for an instance of AresMUSH::Character` on **every** profile
  and chargen page load (it takes down the whole page, not just your field).
  Debugging note: the error's line number points at `custom_char_fields.rb`,
  which misleads you into rewriting the hook over and over — but the real
  fix is the missing `attribute` declaration, not the hook body. There is no
  `char.custom_field(...)` / `char.custom['...']` accessor on Character;
  those were dead ends. Custom fields are plain declared attributes.
- **The save hooks receive form data under a `'custom'` key, not as symbol
  args.** The exact contract from the stock file is
  `save_fields_from_chargen(char, chargen_data)` and
  `save_fields_from_profile_edit2(char, enactor, char_data)`, and your fields
  arrive as `chargen_data['custom']['my_field']` (string key). Reading
  `args[:my_field]` compiles fine and silently saves nothing — the classic
  "it says saved but the value never appears" symptom. Persist with
  `char.update(my_field: Website.format_input_for_mush(data['my_field'].to_s))`
  and return `[]` (an array of error strings; empty means success).
- Format text for its destination: `format_input_for_html` for the
  chargen/edit *form* fields, `format_markdown_for_html` for the read-only
  *view*, and `format_input_for_mush` when *storing* what the form sent back.
- **A pre-approval "draft" feature needs every consumer re-audited to read
  the draft, not the finished record.** Building a chargen draft-then-convert
  flow (fields saved on the character, turned into a real DB record only on
  approval) is easy to get half-right: it's natural to write the save/convert
  path correctly and then leave *other*, pre-existing code — a chargen
  "is this done yet?" gate, an app-review completeness check — still querying
  for the finished record, because that's what it did before the draft
  concept existed. Those checks then silently pass for a genuinely-empty
  field (nothing to find pre-approval) or block a genuinely-filled one
  (looking in the wrong place), and both failure modes are invisible in
  testing unless someone specifically tries the gate before approving. Grep
  for every place that used to query the finished record for something now
  backed by a draft, not just the save/read hooks — approval gates and
  completion checks are easy to miss because they don't look like part of
  "the chargen form."
- **A comment claiming "mirrors the permission check in X" is a claim, not a
  guarantee — verify it.** `Inklings.creatable_kinds` (feeds the web portal's
  "New Inkling" type dropdown) had a docstring saying it mirrored
  `InklingApi.create_inkling`'s authorization logic, but never actually
  checked approval at all - an unapproved character got the full type list
  with nothing they could actually submit, a dropdown full of dead ends
  (caught because the reported symptom was "the dropdown is blank" for a
  *different*, unrelated reason - a missing install step - which is what
  prompted a closer look at the method itself). A permission-adjacent
  "what can this viewer do" list-building helper is exactly the kind of code
  that silently drifts from the real enforcement point it's supposed to
  reflect, since nothing breaks loudly when they diverge - the UI just
  offers choices the backend will reject. When you see a comment asserting
  two code paths are kept in sync, read both and check.

### Helpers

Check before writing one:
- `ember-truth-helpers` (bundled): `eq`, `and`, `or`, `not`.
- Ares's own: `local-date` (dayjs-backed date formatting — don't write your
  own date helper), `ansi-format`, `title`, `link-to`.
- Array/string formatting (`join`, `uppercase`, `capitalize`) has **no**
  bundled equivalent in `ares-webportal` (`ember-composable-helpers` and
  `ember-cli-string-helpers` are not dependencies) — but before writing a
  helper for this, ask whether the formatting can move server-side instead
  (see below). A helper that only exists to `Array.join` data the API
  already assembled is a sign the API should just return the joined string.

### Templates

- Data flows in from a Route's `model` or a Component's passed-in
  attributes — not fetched imperatively inside the template.
- Use `{{#if}}`/`{{#each}}`/`{{eq}}` for branching; anything heavier belongs
  in a computed property (Component) or the Ruby formatter (server).
- Bootstrap 5 (`bootstrap` + `ember-bootstrap`) is loaded globally by
  `ares-webportal`'s own `app/styles/app.scss` on every page, including
  pages your plugin's tab renders into. `.btn`, `.btn-*`, `.btn-sm`,
  `.badge`, `.text-bg-*`, `.alert`/`.alert-*`, and the flex utility classes
  are free — don't hand-roll them.

### Styles

Only genuinely domain-specific layout (a custom collapsible-thread UI, a
custom filter-toggle control with no Bootstrap equivalent) belongs in a
plugin's own `.scss`. Before adding a rule, check whether it duplicates a
Bootstrap class name under a slightly different definition — that's strictly
worse than using the real class, since it silently shadows the framework
styling other pages rely on staying consistent.

### CSS Classes for End-User Customization

Every key web element should include a unique, semantic CSS class that end users can
target with their own custom CSS — not for the plugin to style, but to allow game
admins to customize the appearance without modifying plugin code or adding `!important`
overrides.

**Pattern:** Use a namespace prefix tied to the plugin or component, then a descriptive
element name:

```html
<!-- Good: unique, semantic classes for customization hooks -->
<div class="inkling-thread-list">
  <div class="inkling-thread-row">
    <h3 class="inkling-thread-title">{{ inkling.title }}</h3>
    <span class="inkling-thread-status">{{ inkling.status }}</span>
  </div>
</div>
```

**Why this matters:**
- Game admins can theme the plugin to match their site without CSS conflicts or
  `!important` workarounds
- Plugin CSS remains minimal and focused on layout; theming becomes the admin's
  responsibility with clear hooks
- A class like `inkling-thread-row` is stable and unlikely to conflict with
  other plugins' class names
- Avoid generic class names (`row`, `item`, `content`) that could collide with
  Bootstrap, other plugins, or custom game CSS

**For component root elements:** Always include a component-specific class:
```js
// inkling-detail-modal.js
export default class InklingDetailModalComponent extends Component {
  classNameBindings = ['inkling-detail-modal'];
  // ...
}
```

Then users can write:
```scss
.inkling-detail-modal {
  background: $my_theme_color;
}

.inkling-thread-row {
  border-left: 3px solid $my_accent;
}
```

### Data loading — server vs. client responsibilities

| Belongs in Ruby (server) | Belongs in Ember (client) |
|---|---|
| Authorization / permission checks | Rendering, based on what the server already decided |
| Filtering a list by viewer role or status | Local UI state (which row is expanded, form field values) |
| Formatting values for display (joined strings, labels, colors) | Dispatching actions and showing loading/error state |
| Computing "what can this viewer do" once | `{{if}}`/`{{eq}}`-level branching on server-provided flags |

If you find yourself writing a computed property that re-derives a
permission check the Ruby side already enforces (this project's
`availableKinds` computed property duplicated `create_inkling`'s staff-only
authorization check almost exactly), move the computation server-side and
have the client just render what it's given.

---

## 4. Ruby Plugin Conventions

Standard plugin directory layout (confirmed against this project's own
structure, which matches the tutorials):

```
plugin/
  <plugin_name>.rb        # module-level registration: get_cmd_handler,
                           # get_event_handler, get_web_request_handler,
                           # shared config-reading helpers
  commands/                # one class per MUSH command
  web/                      # one thin handler class per web request cmd
  public/                   # *_api.rb classes — the actual business logic,
                             # shared by commands and web handlers
  models/                   # Ohm::Model classes
  events/                   # event handler classes (CronEvent, etc.)
  locales/                  # locale_en.yml — all user-facing strings
  help/{admin,en,player}/   # help file markdown
```

**Database models live in the base `AresMUSH` module, not the plugin's own
module**, even though the file lives under the plugin's folder:

```ruby
module AresMUSH
  # not module AresMUSH::MyPlugin
  class MyModel < Ohm::Model
    include ObjectModel
    ...
  end
end
```

### Commands

`include CommandHandler` and implement:
```ruby
def parse_args      # populate attr_accessors from cmd.args / cmd.switches
def required_args   # array of args that must be present
def check_*          # any number of validation methods, each returning
                      # nil (ok) or an error string
def handle           # the actual effect; client.emit_success/client.emit
```
**Validation `check_*` methods run in alphabetical order by method name, not
declaration order.** If one check depends on another having already run
(e.g. a "can I close this" check needs "does this exist" to have run first),
don't assume declaration order gives you that — memoize the lookup and guard
defensively (`return nil if !inkling` at the top of a later-alphabetical
check), the way `InklingCloseCmd#check_can_close` does.

Memoize repeated lookups (`def inkling; @inkling ||= Inklings.find_inkling(id); end`)
so multiple `check_*` methods and `handle` don't each independently re-fetch
the same record.

### Web handlers

Thin adapters only — see §3. `handle(request)` checks login, unpacks
`request.args`, delegates to a `public/*_api.rb` class, returns a hash.

### API classes (`public/`)

Where the actual logic lives, callable identically from a MUSH command and a
web handler. Every method that can fail returns `{ error: "..." }` on the
failure path — this is the contract both `CommandHandler` output and
`GameApi` (see §3) are built around. Format methods (`format_x_summary`,
`format_x_detail`) belong here too — this is the natural place to compute
anything a view (MUSH text or JSON) needs to display, so it's computed once
and doesn't drift between the two front ends.

### Configuration

`Global.read_config("plugin_name", "setting_key")`. Read config live rather
than memoizing it at boot — admins expect config edits to take effect without
a full plugin reload (a `+plugin/config` or file-edit-and-`@restart`
workflow, not a code deploy). Prefer config-driven enumerations (a `types:`
section admins edit in `game/config/<plugin>.yml`) over hardcoded constants
wherever the set of values is remotely likely to vary by game.

### Localization

All user-facing strings live in `plugin/locales/locale_en.yml`, namespaced
under the plugin name, and are referenced via `t('plugin_name.key')`
(interpolation via `%{name}` placeholders). Don't hardcode user-facing
strings directly in command/handler code — even for a single-locale game,
this keeps all copy in one auditable place.

### Permissions

Gate staff-only functionality behind a **configurable** permission name, not
a hardcoded role check:
```ruby
def self.can_manage_my_thing?(enactor)
  return false if !enactor
  permission = Global.read_config("my_plugin", "manage_permission") || "manage_jobs"
  enactor.has_permission?(permission)
end
```
Defaulting to an existing permission (`manage_jobs`, in this project's case)
means games that already have a working staff-permission structure get
sensible behavior with zero config. Reserve genuinely narrower permissions
(`manage_game`) for irreversible/destructive commands specifically, not for
everyday staff functionality.

### Events

Registered the same way as commands and web handlers:
```ruby
def self.get_event_handler(event_name)
  case event_name
  when "CronEvent"
    return MyPluginCronHandler
  end
  nil
end
```
**Do not guess an event's class name or field names.** If you're hooking
into another plugin's event (e.g. a Jobs reply event) and haven't confirmed
the exact class/fields against that plugin's actual source in the target
install, write the handler defensively (`event.respond_to?(:field) ? event.field : ...`)
and leave an explicit, honest comment saying so — see
`plugin/events/job_reply_event_handler.rb` in this repo for the pattern.
Fix it for real the moment you can check the actual dependency's source.

### Formatting helpers

Ansi color helpers (`color_name`, `color_title`, `color_type` in this
project) are applied to text emitted directly to a MUSH client, never to
values that get read back by another system (a web JSON payload, another
plugin's formatter) — those callers shouldn't have to strip ansi escapes
back out. Keep a clean line between "text for a terminal" and "data for
anything else."

---

## 5. Installation Best Practices

### `plugin/install` pulls from the repo's default branch — always merge fixes to `main`

`plugin/install <url>` clones/fetches the **default branch** (`main` on this
project), not any feature/dev branch. A fix that only exists on a
`claude/...` or other working branch is invisible to `plugin/install` and to
anyone re-running it to pick up an update — the installed code on their
server won't change even after a successful `plugin/install` run, and the
failure mode is confusing: no error, just the old method/behavior still
missing after the "update." **Confirmed the hard way on this project**: an
app-review integration fix was developed and pushed to a feature branch, the
user ran `plugin/install` to pick it up, and got `undefined method
'get_app_review_issues'` — the code was real, tested, and pushed, just not
on `main` yet. Merging the feature branch into `main` and pushing fixed it
immediately, no other change required.

**Rule:** any change intended for an end user to receive via `plugin/install`
(a bug fix, a new hook, anything outside pure in-progress development) must
be merged into `main` and pushed before telling the user to (re-)run
`plugin/install`. Landing it only on a feature branch is not enough, even if
that branch is pushed to GitHub.

### `plugin/install` expectations

`plugin/install <url>` (or manual copy into `plugins/<name>/`) handles:
- Plugin Ruby code
- Merging `game/config/<plugin>.yml`
- Copying files that are **always safe to auto-copy** into the target
  webportal checkout, if any

It does **not** merge into files the game already owns and other plugins
also want to extend (`profile-custom.hbs`, `profile-custom-tabs.hbs`,
`chargen-custom.hbs`, `chargen-custom-tabs.hbs`, `chargen-custom.js`,
`custom_char_fields.rb`). Those are shared, hand-edited files by design —
there is no manifest format that lets an automated installer safely append
to them without risking another plugin's already-pasted code.

**There is no `.ares-manifest.yml` convention.** This project added one
speculatively, then had to remove it after confirming against actual Ares
plugin-installer behavior that it does nothing — `plugin/install` doesn't
read or expect it. Don't invent an installer manifest format; verify what
the installer actually consumes before assuming a config file will be
picked up.

### What should be automated (auto-copied by `plugin/install`)

Only files that are **unconditionally safe to place into the target
directory regardless of whether the optional web integration is ever
completed** — meaning files that Ember's own resolver won't choke on and
that do nothing until wired up:
- The component's `.js`/`.hbs`, in the exact resolver-expected paths
  (`webportal/components/`, `webportal/templates/components/`)
- Helpers, in `webportal/helpers/`
- Styles, in `webportal/styles/` (inert until imported into `app.scss`)

### What belongs in `custom-install/` (manual snippets, never auto-copied)

Anything that requires editing a file the *game* already owns and that other
plugins may also be extending:
- `profile-custom.hbs` / `profile-custom-tabs.hbs` insertions
- `chargen-custom.hbs` / `chargen-custom-tabs.hbs` / `chargen-custom.js` insertions
- `custom_char_fields.rb` hook additions
- Anything documented as a numbered "find this method, paste before this
  line" instruction rather than a drop-in file

Write these as literal, mechanical, "find X, paste Y before Z" steps a
non-developer administrator can follow without understanding Ember or Ruby —
not prose describing the change.

### Optional web integration

Structure the README so a MUSH-only install (Step 1 only) works completely
and the web tab is simply absent — never broken. A partially-completed web
install (some files present, others not) should degrade gracefully, not
throw a routing error. Concretely: never let a file with the wrong resolver
shape (see below) end up somewhere Ember's auto-resolver will find and try
to load it.

### README expectations

**Audience:** Write all outward-facing text (README, help files, install instructions) for laypeople installing and running the plugin — game administrators, not developers. Never explain how things work on a code level. Focus on features (what players and staff can do) and the specific steps installers need to take to make it work.

**Specifically:**
- Describe the plugin's features and what it does (player-facing) and what staff can do with it
- Do NOT explain implementation details (how the web components load data, how the hooks work, database schema, Ruby conventions, etc.)
- Write installation steps as mechanical, numbered procedures a non-developer can follow
- When referencing files or directories, use game-owner-relative paths (`game/config/inklings.yml`, not `plugins/inklings/game/config/inklings.yml`)
- Use plain language; avoid technical jargon that requires AresMUSH knowledge to understand

**Mechanical requirements:**
- Describe exactly what's automatic vs. manual, matching what actually
  happens — don't describe an aspirational installer.
- Give a numbered, mechanical install path with clear optional/required
  markers per step.
- Keep a "Known Limitations" section honest about things that don't fully
  work (e.g. a feature that depends on the specific game having a
  particular field configured).

### Lessons learned from the legacy React implementation

This plugin's web tab started as a React component
(`InklingsTab.jsx`/`InklingsTab.css`, added early in the project) before
being rewritten in Ember, which is what `ares-webportal` actually is. Real
consequences, from this project's own git history:

1. **A leftover `.jsx` file auto-copied into `app/components/` broke the
   entire web portal**, not just the plugin's own tab. Ember's resolver
   discovered the file in the components directory and tried to treat it as
   an Ember component, producing an unrelated-looking error ("More context
   objects were passed than there are dynamic segments for the route") that
   gave no hint the actual cause was a stray React file. **A framework
   mismatch in an auto-copied file is a whole-portal risk, not a
   contained one.**
2. **The fix was two-part and both parts mattered**: delete the dead
   React files outright (don't just stop referencing them — an unused file
   in a resolver-scanned directory is still dangerous), *and* verify every
   remaining auto-copied file is in the exact path Ember's resolver expects
   (`webportal/components/`, not `webportal/app/app/components/` or similar
   nesting mistakes — this project went through several path corrections
   before landing on the right structure).
3. **When in doubt about whether a file is safe to auto-copy, it isn't.**
   This project's install path oscillated (auto-copy → manual-only →
   auto-copy again) before settling on: auto-copy only pure, inert
   framework files in exactly the right resolver paths; manual-paste
   everything that touches a file the game already owns. If you're not
   certain a file is inert until wired up, put it in `custom-install/` and
   make the admin paste/copy it deliberately.

---

## 6. Extensibility Principles

- **Config over hardcoding.** Enumerable domain concepts (types, categories,
  reward kinds) belong in `game/config/<plugin>.yml`, read live via
  `Global.read_config`, not as Ruby constants or (worse) hardcoded lists
  duplicated in Ember. Every hardcoded list is a place a game owner has to
  either accept your defaults or fork your code.
- **Generic hooks over plugin-specific special-casing.** Use Ares's existing
  hook points (`app_review_issues`, custom-fields hooks, event handlers,
  `custom_approval`) rather than reaching into another plugin's internals
  directly. This is also what keeps a plugin functional when the *other*
  plugin isn't installed. **Verify a hook name is real before building
  against it** - see Lesson 33 below for a hook this project coded, never
  confirmed, and shipped for multiple releases without it ever actually
  being called.
- **Generic reward/interop systems**, not point-to-point integrations. This
  project's reward system (`reward_type`/`reward_key`/`amount`, applied via a
  generic `grant_reward` path rather than one method per possible reward
  kind) is the shape to reuse: add a new reward kind by handling a new
  `reward_type` value, not by adding a new API method.
- **Avoid direct dependencies on plugins that may not be installed.** Guard
  optional integrations (this project's FS3Skills-dependent rolling, luck
  points) behind existence checks, and document plainly what happens when
  the dependency is absent (degrade, don't crash). Don't assume a "common"
  plugin is present.
- **Avoid direct dependencies on *future* plugins or unconfirmed APIs.**
  Don't wire a hard integration against another plugin's event/field names
  you haven't verified against that plugin's actual source — see the
  `job_reply_event_handler.rb` scaffolding note in §2 and §4. Ship the
  honest, verifiable version; leave the rest as a documented gap, not a
  guess dressed up as a fact.
- **Lifecycle events over polling or manual coordination.** Prefer firing/
  listening for events (`CronEvent`, plugin-specific dispatch events) over
  having one plugin poll another plugin's state.

---

## 7. Performance Guidelines

- **Ruby**: authorization, filtering, formatting, anything that determines
  *what* a viewer is allowed to see or do. Compute it once, server-side,
  scoped to the actual viewer — not "compute everything, filter in the
  client."
- **Ember**: rendering what the server already decided, local UI state
  (expanded/collapsed, form inputs, filters that don't need a round trip),
  and dispatching actions. If a component method's job is "look something up
  in a hash the server sent" (a label, a color, a description), consider
  whether the server should just include that value directly on the record
  instead of sending a separate lookup table for the client to join against
  — one fewer place for the join key to be missing/stale/racy against.
- **Avoid duplicate filtering.** If the server already filters a list by
  viewer permission/status, don't re-filter it in a computed property. If
  you find yourself doing this, it usually means the server's filtered
  result and the client's "what should I be able to do" logic have started
  to drift apart — see §3's table.
- **Avoid unnecessary API calls.** Static or small per-viewer reference data
  (a type list, config-driven options) should ride along on data the page
  already loads (`char.custom.*` — see §3) rather than triggering its own
  request. Reserve separate requests for data that's genuinely too large,
  too dynamic, or too privacy-sensitive to eagerly load on every page view.
- **Minimize client-side logic generally.** Every computed property,
  helper, or component method is something that has to independently agree
  with the server's behavior forever. The less of that surface exists, the
  less can drift.

---

## 8. Common Mistakes

Each of these happened on this project — concretely, not hypothetically.

1. **Inventing APIs / event names instead of verifying them.** The Jobs
   reply event handler was written against a plausible-but-unconfirmed event
   class/field set. *Avoid it*: if you can't check the actual dependency's
   source before writing the integration, write it defensively and mark it
   explicitly as unverified scaffolding — don't let a guess read as fact in
   the code.

2. **Creating new hooks, methods, or classes without checking if they already
   exist.** Before writing any new hook, method, class, or helper, always
   search the Ares source (both core and bundled plugins) and any relevant
   third-party plugins to see if the same or similar functionality already
   exists. *Avoid it*: check `aresmush/aresmush` and `AresMUSH/ares-webportal`
   for existing hooks, methods, and patterns. Use grep, GitHub search, or code
   inspection to confirm the exact behavior of something you think exists
   before writing a replacement. If it exists, use it; if you need a variant,
   extend it rather than reinventing it.

3. **Inventing helpers Ares already provides.** This project shipped its own
   `eq`/`and`/`or`/`not` helpers, duplicating `ember-truth-helpers`
   (bundled), and its own `format-date` helper, duplicating the built-in
   `local-date`. *Avoid it*: check `ares-webportal`'s `package.json` and
   `app/helpers/` before writing any helper.

4. **Building custom architecture where Ares already had a pattern.** The
   `.btn`/badge/alert CSS reinvented Bootstrap 5 components already loaded
   globally by `ares-webportal`. The `typeInfo` self-fetch reinvented what
   the `char.custom.*` hook mechanism already solves for exactly this kind
   of data. *Avoid it*: before writing a UI pattern or a data-loading
   mechanism, find the closest analog in a real Ares plugin and check
   whether it solved the same problem already.

5. **Client-side duplication of server-side logic.** `availableKinds`
   re-derived the staff/player authorization check `create_inkling` already
   enforced. *Avoid it*: any time a computed property or component method
   answers "is this viewer allowed to X," check whether an API method
   already answers that question, and have the server return the
   pre-filtered answer instead.

6. **Assuming web conventions instead of confirming them.** Assumed
   `requestMany` behaves like "fetch a list" in the abstract, without
   checking that it literally calls `.map()` on the raw response. Assumed a
   response object was the unwrapped record without checking the Ruby
   method's actual return shape. *Avoid it*: read `game-api.js` and the
   specific Ruby method you're calling before writing the `.then()`.

7. **Trusting stale GitHub state (default branch, file existence) without
   checking.** Different reference repos on GitHub used `master` vs. `main`
   as their default branch; guessing wrong silently returns a 404 that looks
   like "this doesn't exist" rather than "wrong branch name." *Avoid it*:
   check a repo's actual default branch (or try both) before concluding a
   file or pattern doesn't exist upstream.

8. **Incorrect install assumptions.** Assumed `.ares-manifest.yml` was a
   real, consumed installer format without checking; assumed single splat
   (`*`) merges a hash into a hash literal in Ruby without checking (it's a
   `SyntaxError`). *Avoid it*: for anything install-mechanism-related,
   verify against actual installer behavior or `ruby -c`, not intuition.

9. **Legacy code that should have been deleted, not left inert.** The
   original React component wasn't just unused — it was actively dangerous
   sitting in an auto-copied, resolver-scanned directory. *Avoid it*: when a
   rewrite makes a file obsolete, delete it in the same change, especially
   if it lives anywhere an automated process (installer, resolver, dispatch
   `case`/`when`) might still pick it up. An orphaned, unreferenced web
   handler + dispatch case is the same category of risk at a smaller scale —
   delete dead endpoints once nothing calls them, don't leave them as inert
   surface area.

10. **`{{#with}}` on a property that gets set asynchronously.**
   `{{#with someProperty as |alias|}}` reproducibly crashed this install's
   web portal with `resolvedDefinition is null` (cascading into "Recursive
   error condition - ignoring") whenever the wrapped property was set after
   an async fetch resolved — e.g. `this.set('detail', response)` inside a
   `gameApi` `.then()`. This wasn't a data-shape bug or a render-timing bug
   in the surrounding code — timing fixes (deferring the fetch via `next()`,
   decoupling a modal's `open` state from the fetch entirely) did not help,
   and the same block helper independently broke two unrelated templates
   months apart, isolated only by incrementally stripping a template to
   nothing and re-adding pieces until it broke again. We don't have a
   confirmed mechanism for *why* — only that referencing the property
   directly (`this.detail.foo`) instead of aliasing it through `{{#with}}`
   eliminated the crash every time, with no other change. *Avoid it*: don't
   reach for `{{#with}}` to alias a property that's populated by an
   async fetch inside an Ares web component; reference `this.property.foo`
   directly instead. If you hit this exact cryptic error on a
   fetch-then-render component, try removing any `{{#with}}` block before
   chasing render-transaction/timing theories - it's the cheaper thing to
   rule out first.

11. **Auto-installing files at shared customization points.** This plugin initially
    tried to auto-install `chargen-custom.js` and `chargen-custom.hbs` as plugin
    files, assuming they were plugin-owned. These are actually shared game
    customization files that already exist in standard AresMUSH installations and
    may contain other plugins' or the game owner's customizations. Auto-installing
    replacements breaks the existing chargen setup. *Avoid it*: distinguish between
    plugin-owned files (uniquely named components, plugin config, plugin styles)
    and shared game files (chargen-custom, profile-custom, custom_char_fields.rb).
    Shared files require manual-paste snippets only. Auto-installing template stubs
    is acceptable only if they're clearly named as stubs for users to customize, not
    as replacements for existing files.

12. **A `public/*_api.rb` method re-deriving a viewer it was already given.**
    `RollsApi.add_roll` and `RollsApi.reroll_with_luck` took `viewer_id` and
    did `Character[viewer_id]` to resolve it — but their only caller (a web
    handler) passes `request.enactor`, which is *already* a resolved
    `Character` object, matching the convention every other method in the
    plugin's own `InklingApi` class uses (`viewer` is accepted and used
    directly; only `char_id`-shaped params get looked up via `Character[]`).
    `Character[<a Character object>]` doesn't raise — it just returns `nil`,
    so every call returned `{ error: "Viewer not found" }`. Compounding it,
    the web component's action handlers uniformly do
    `if (response.error) { return; }` with no flash message on failure (see
    item 5 above on that same pattern being *correct* for expected
    validation errors) — so the bug surfaced as "the button does nothing,"
    not a visible error, and took much longer to find than a raised
    exception would have. *Avoid it*: when a new `public/*_api.rb` method
    takes a "viewer" or "enactor" parameter, check how its actual caller
    resolves that value before deciding whether the method should look it
    up (`Character[id]`) or use it directly (already an object) — don't
    default to re-deriving what the caller already has. And when a
    fire-and-forget web action seems to do nothing, check the Ruby side's
    return value before assuming the JS or the template is broken — a
    silently swallowed `{ error: ... }` looks identical to "nothing happened."

12. **Telling a user to re-run `plugin/install` before the fix was on `main`.**
    A real app-review integration bug was fixed, tested, and pushed — but
    only to a feature branch. The user ran `plugin/install`, which pulls the
    repo's default branch (`main`), and hit `undefined method
    'get_app_review_issues'` because the fix wasn't there yet. *Avoid it*:
    before telling a user to (re-)run `plugin/install` (or any install step
    that fetches from the repo URL) to pick up a fix, confirm the fix is
    actually merged into `main` and pushed — check with `git log
    origin/main..<feature-branch>` to see what's still missing from `main`,
    not just that it's pushed *somewhere*.

13. **Confusing `@restart` with an actual server restart - and previously
    telling users to `sudo reboot` the machine.** `@restart` does not exist
    in AresMUSH - never tell a user to run it. This guide previously also
    told users to fix a stale-code restart by running `sudo reboot` on the
    server, which is wrong on two counts: it reboots the entire OS (unasked-
    for, and something a game admin may not even have permission to do),
    and it's not what AresMUSH's own docs recommend. Verified against the
    real tutorial (`AresMUSH/aresmush.com`'s
    `tutorials/manage/shutdown.md`, fetched via
    `raw.githubusercontent.com` - see Lesson 22's technique for when
    `www.aresmush.com` itself isn't reachable): the correct procedure is
    (1) the in-game `shutdown` command, or Web Portal Admin -> Manage ->
    Shutdown if that fails, (2) wait ~10 seconds, (3) `bin/startares` from
    the server shell (`cd aresmush && bin/startares`) to bring it back up.
    *Avoid it*: never tell a user to "run `@restart`" (it doesn't exist) or
    to `sudo reboot` the machine (it's not the documented procedure, and is
    far more disruptive than necessary). When installation docs require a
    restart for plugin code changes to take effect, spell out the real
    `shutdown` + `bin/startares` sequence instead.

14. **Character approval integration must use the official hook.** A plugin's
    code that needs to run when a character is approved should NOT create a
    custom approval event or invent a hook dispatching mechanism. AresMUSH
    provides an official `Chargen.custom_approval(char)` hook (documented at
    https://www.aresmush.com/tutorials/code/hooks/approval-triggers.html).
    This hook is called by the Chargen plugin after `char.is_approved = true`
    is persisted, so the character is already marked approved. A plugin that
    provides lifecycle behavior tied to approval should (a) implement a
    plugin-side method with a clear, descriptive name (e.g.,
    `Inklings.convert_chargen_drafts(char)`), (b) provide a merge-safe snippet
    for the shared `custom_approval.rb` hook file showing how to call that
    method, and (c) document that the method runs after approval is finalized.
    *Avoid it*: do not poll for approval state, do not add custom event dispatch,
    do not modify Chargen core code, and do not put approval behavior in app-
    review hooks (which run during app review, not at approval time). Let the
    official hook carry the notification — the game owner's game/aresmush folder
    already owns `custom_approval.rb`, and a plugin's merge-safe snippet is the
    right way to extend it.

15. **A backlog audit found four real bugs by re-reading code, not by trusting
    old assumptions.** Four separate, unrelated defects, each worth its own
    lesson:
    - **(Later corrected — see the note below §9.) A claimed bug about
      `if (response.error) { return; }` "silently swallowing" errors was
      wrong, and contradicted a fact already documented earlier in this
      exact guide.** §2 already records that `GameApi.requestOne`/
      `requestMany` call `this.flashMessages.danger(response.error)`
      themselves, unconditionally, before the caller's `.then()` even runs
      — confirmed again directly against `ares-webportal/app/services/
      game-api.js`. `if (response.error) { return; }` in a component action
      is therefore the *correct*, complete pattern: the framework already
      told the user: the component just needs to stop before treating an
      error response as success. Adding a second `flashMessages.danger(...)`
      call on top doesn't fix a missing message, it duplicates a message
      that was never missing. **The actual lesson: when a candidate bug
      looks exactly like something this guide already documented a fact
      about, grep the guide itself before "fixing" it** — the fact was
      sitting in §2 the entire time this session diagnosed and "fixed" the
      same code.
    - **(Later corrected — see Lesson 23.) A MUSH-colorized field (`%x`
      codes) reused as both MUSH output and stored data will leak raw
      escape sequences into any web JSON built from it; the fix is to wrap
      it in `{{ansi-format}}` at render time.** The "leaks raw markup"
      diagnosis was right, but the fix was wrong: `{{ansi-format}}` parses
      real ANSI terminal escapes, not AresMUSH's own `%x` markup — a
      different format entirely, confirmed by reading the helper's actual
      source. See Lesson 23 for the real fix.
    - **A `public/*_api.rb` method that takes both `char_id` (whose page this
      is) and `viewer` (who's looking at it) must use the right one for each
      query, and it's easy to default to `viewer` for everything.**
      `InklingApi.get_inklings` used `viewer.id` for its "shared with me" and
      "group match" queries instead of `char.id`. For a player viewing their
      own profile the two are identical, so this shipped and passed casual
      testing — the bug only appears when *staff* view *someone else's*
      profile, where it silently mixed inklings shared with the staff
      member's own character into the target's list. Any time a handler
      takes both a subject and a viewer, audit every query in it for which
      one it actually keyed off, especially ones that only get exercised by
      a staff-viewing-another-character code path.
    - **An `if/elsif` chain used as a command dispatcher needs an explicit
      "none of these matched" branch, or unrecognized input silently falls
      through to whatever code follows the chain.** `Inklings.get_cmd_handler`
      had a long `elsif cmd.switch_is?(...)` chain with no final `else`; an
      unrecognized switch (e.g. a typo'd `+inkling/aprove`) fell out of the
      chain entirely into code written for the *different* case of "no switch
      at all," which silently matched the bare-list fallback instead of
      reporting anything. The fix: add `elsif cmd.switch.present?` as the
      last branch, returning `nil` so Ares' own unrecognized-command handling
      takes over — the same fallback that already applies to any `cmd.root`
      that isn't handled by this plugin at all. Prefer that (deferring to a
      mechanism that already exists) over inventing a new "unknown switch"
      error command.
      **Follow-up regression, caught before it shipped:** that `elsif
      cmd.switch.present?` catch-all is only safe once *every* switch a
      command legitimately handles is matched by an earlier branch.
      `InklingsCmd` handles `/closed` and `/all` itself, inside `#handle`,
      after being dispatched via the *unmatched-switch* fallthrough this
      lesson just described as a bug - so those two switches had no
      explicit branch in the dispatcher chain at all. Adding the catch-all
      turned that "works by falling through" case into "silently rejected
      as unrecognized." A command that reads its own switches in `#handle`
      rather than being routed by them still needs every one of those
      switches represented in the dispatcher, even switches whose *routing
      logic* is "just get me to this class." Grep the target command for
      every `cmd.switch_is?` call before adding a catch-all above it.

16. **"Custom routes" for a new top-level admin page is not a Ruby hook -
    it's two separate, already-established manual-snippet extension
    points, one Ember-side and one config-side.** Building an admin page
    (a genuinely new top-level route, not a tab within an existing page)
    required tracing this from `ares-webportal` source directly, since
    neither `aresmush/plugins/website/website.rb` nor `plugins/manage/
    manage.rb` define anything named "custom routes":
    - **The route itself**: `app/custom-routes.js` in `ares-webportal`
      exports `setupCustomRoutes(router)`, a function body that's empty
      except for a comment on stock installs - a game owner (or a
      plugin's snippet) adds `router.route('your-route');` inside it.
      This is the *same* manual-merge-into-a-shared-file pattern this
      project already uses for `chargen-custom.js`/`.hbs` - not a new
      convention to learn, just a new file it applies to.
    - **The Admin dropdown entry**: confirmed directly against
      `install/game.distr/config/website.yml` in the `aresmush` repo -
      the navbar (`website.top_navbar` in game config) is a plain,
      game-owner-edited YAML list, not a Ruby-side hook either. Its
      "Admin" section (`roles: [admin, coder]`) already lists entries
      like `- title: Manage / route: manage` - i.e. the bundled `manage`
      plugin gets its own Admin-menu entry through this exact mechanism,
      confirming it's the intended path for a plugin-contributed admin
      page. Per-item `roles:` on a *nested* menu entry (as opposed to
      the top-level section) was not independently confirmed in
      `ares-webportal/app/controllers/application.js`'s `topNavbar`
      computed property or the client-side `checkRoute` helper it calls
      - worth verifying against a running game before assuming it filters
      client-side navbar visibility; either way it is not the actual
      permission boundary, since the endpoint itself must enforce that
      independently regardless (see the Inklings admin page work, which
      gates both `InklingApi.list_all_inklings` and `InklingAdminCmd`
      directly rather than trusting the nav entry to hide anything).
    - **The reuse win worth repeating elsewhere**: the admin page's "Add
      Inkling, choose the owner" requirement needed zero new creation
      logic - `InklingApi.create_inkling(char_id, viewer, ...)` already
      took the owner as an explicit argument distinct from `viewer`
      (staff creating on someone else's behalf was already a supported
      case). The admin-only addition (`create_inkling_by_name`) is a
      thin owner-name-to-id wrapper around it, not a parallel
      implementation. Sharing works the same way at one more remove:
      `InklingShareCmd` (`+inkling/share`) doesn't inline its own
      participant-creation logic either - it calls a shared module
      method, `Inklings.add_participant(inkling, target, added_by)`.
      The admin page's `add_participants_by_id` calls that exact same
      method too, just resolving targets by id instead of by name -
      *not* through `InklingApi.share_inkling` (a separate, web-specific,
      name-based method that duplicates `add_participant`'s logic
      inline rather than calling it - a pre-existing seam worth
      revisiting someday, but out of scope for this pass). Before
      writing a new mutation for "staff does X on behalf of character Y,"
      check whether the existing single-character version already
      threads a distinct owner/actor pair through, *and* trace each
      MUSH command's `handle` back to find the actual shared module-level
      service it calls - that's the thing to reuse, not the MUSH
      command or the web API method sitting in front of it.

17. **The reusable Ares character-picker precedent is `ember-power-select`'s
    `PowerSelect`/`PowerSelectMultiple`, fed by the core `characters` web
    request - not something to assume doesn't exist.** An earlier pass on
    this admin page shipped free-text character-name fields after failing
    to find a selector component, reasoning (documented at the time) that
    none had been confirmed. That reasoning was correct given what had
    actually been checked (a scan of `ares-webportal/app/components/` for
    names containing "select"/"typeahead"/"char"), but the search stopped
    one level too early - it never looked inside a *page* that already
    solves this exact problem. Tracing `job-edit.hbs`/`job-edit.js`
    (`ares-webportal`) directly showed the real pattern:
    - `<PowerSelect @selected={{this.x}} @options={{this.model.characters}}
      @searchField="name" @searchEnabled=true @onChange={{action "y"}}
      as |char|>{{char.name}}</PowerSelect>` for a single pick (Jobs'
      Submitter/Assigned To fields), `<PowerSelectMultiple ...>` with the
      same arguments for multiple (Jobs' Other Participants field) -
      already a dependency of `ares-webportal` itself, since a bundled
      core plugin (Jobs) depends on it, so no new npm dependency needed.
    - `this.model.characters` comes from the CORE profile plugin's
      `characters` web request (`CharactersRequestHandler` in
      `aresmush/plugins/profile/web/characters_request_handler.rb`), not
      anything Jobs built itself - `select: "all"` returns every
      character (`Character.all.to_a`, no approval filter), minimal shape
      (`{id, name, icon}`), sorted by name. Reusable as-is by any plugin
      that needs a character picker; no new list-characters endpoint
      needed.
    - Submission convention differs by arity, confirmed from
      `job-edit.js`'s save action: a single-select value is sent as a
      **name string** (`.get('model.job.author.name')`), a multi-select
      value is sent as an **array of ids**
      (`(participants || []).map(p => p.id)`). Match whichever shape the
      field actually is, not one convention for both.
    - **The lesson**: "no reusable component was found" needs the search
      to include *pages already solving the same problem* (a full-page
      character-assignment UI like `job-edit.hbs`), not just a scan of
      component directory listings by name. A directory scan finds things
      that *announce* themselves by name; it won't find a generic addon
      component (`PowerSelect`) being used *inside* an unrelated feature's
      page. When a "does X exist" search comes back empty, try one more
      pass at "does anything already solve the same *user-facing*
      problem," not just "does anything with a matching *name* exist."

### Lesson 18: Config File Auto-Merge Limitations

Config files like `game/config/inklings.yml` are included in plugin/install, but
their updates don't always merge cleanly on subsequent installs, especially if
the user has customized the config locally. For critical config sections:

- **Document manual update steps** in the README's installation section, not
  just one-time installation
- **Clearly mark config sections** that are safe for users to customize
  separately from sections the plugin manages
- **Assume users will hand-edit** their config after the first install; make
  it safe for them to run plugin/install again without wiping those edits
- **Don't rely on auto-merge** for config — treat any config change as
  something the user will handle manually if needed

Example: Inklings plugin's config wasn't updating on re-install because the
user had already customized `game/config/inklings.yml`. The lesson: config
changes should be documented as "check if you need to merge these fields" in
the release notes, not hidden in an auto-install step that silently fails.

### Lesson 19: A component argument added later must be back-filled into every install snippet that invokes it

`inkling-create-form.js` was given a `characterName` argument (profile mode
needs it to display "Main Character" as a static label - see Lesson 17's
neighbor note on that decision) well after `custom-install/profile-custom.snippet.hbs`
had already been written and documented showing the `{{inklings-tab ...}}`
invocation *without* it. Nothing caught the gap: the component itself
degrades silently (an empty argument just renders an empty `<div
class="form-control">`, no error, no console warning), and the snippet file
is prose/markup meant for the user to hand-copy into their own webportal, not
code this repo's own tooling ever executes or type-checks. The result shipped
and stayed invisible until a user reported "Main Character shows a blank tiny
box" against their real, already-installed profile page - which is a *second*
copy of that markup this repo cannot see or grep, so the bug was invisible
from inside the repo even after the report.

- When a shared component gains a new required/consumed argument, grep
  `custom-install/*.snippet.hbs` (and any other snippet file) for every
  existing invocation of that component and update them in the same change -
  don't treat snippets as documentation-only, treat them as call sites.
- Because snippets are hand-copied, a fix here does NOT fix any installation
  that already copied the old version - the user must be told explicitly to
  re-copy (or manually patch) the specific line in their own
  `ares-webportal/app/components/profile-custom.hbs` (or wherever they pasted
  it). Say this plainly; don't imply `plugin/install` alone will pick it up.
- A quick guard against recurrence: before shipping a change to a shared
  component's argument list, grep the whole repo (not just the component's
  own directory) for the component's tag/name to find every place - snippet
  or otherwise - that invokes it.

---

### Lesson 20: `t()` locale strings only work from `CommandHandler` classes - plain module code needs its own text helper

A shared "new inkling message" notice existed as a locale key
(`inklings.new_message_notice`) and was correctly used via `t(...)` from three
`CommandHandler` command classes. But two other call sites that fired the
*exact same notification* - `Inklings.submit_inkling`'s job-reply mirror in
`inklings.rb` and `InklingApi#reply_to_inkling` in `inklings_api.rb` - are
plain module/class methods with no `t()` available (it's a `CommandHandler`
instance method, not a global). Rather than surface an error, those two sites
just hardcoded their own duplicate English string. One of the two duplicates
also silently lost the inkling ID in the process ("Use +inklings to view it"
instead of "Use +inkling #14 to view it"), so half the app's "you have a new
message" notifications couldn't tell the player which thread it was about.

- Don't assume a locale key is single-sourced just because it exists in
  `locale_en.yml` - grep every call site and check whether each one is
  actually reachable from a `CommandHandler` instance. If any aren't, the
  locale key is not really centralizing anything.
- For text needed by both `CommandHandler` classes and plain module/API code,
  put a plain Ruby method on the module itself (e.g. `Inklings.notify_new_message(char, inkling)`,
  next to `Inklings.notify_player`) rather than a locale key. It works
  identically from both contexts and there's exactly one place to edit the
  wording.
- When auditing "does every notification about inkling #N actually include
  #N," check not just whether the string interpolates an ID, but whether
  *every* call site sending that logical notification is going through the
  same code path. Near-identical hand-duplicated strings are exactly where
  one copy quietly drops the detail the others kept.

---

### Lesson 21: A fully-built backend endpoint with no caller is still an incomplete feature - and the README can claim it works anyway

`RollsApi.reroll_with_luck`, its `inklings_reroll_with_luck` web endpoint, and
the `InklingRoll` model's `reroll_count`/`luck_cost` fields are all real,
working code - complete with an honest comment on the handler explaining
exactly what the (never-written) frontend was supposed to do: call the game's
own FS3 luck-reroll endpoint first, then pass the result here. Nothing about
the backend code is wrong. But no `webportal/*.js` file ever calls it -
`inkling-detail-modal.js` only has `addRoll()`, no reroll action - so the
feature has literally no way to be triggered by a player. Meanwhile the
README's feature list confidently advertised "Reroll with luck - ... use them
to reroll attached dice from the web portal" as if it shipped, and the Known
Limitations section had a bullet caveating *when* the button wouldn't work
("if your game doesn't track luck points") instead of noting the button
doesn't exist at all. Both readings were plausible from the backend code
alone; only grepping the actual frontend for a caller settled it.

- Backend-complete is not feature-complete. When auditing "does X work,"
  grep the consuming side (webportal `*.js` for a `gameApi` call, a MUSH
  command for a code path) - a well-implemented, well-commented Ruby method
  proves nothing about whether anything actually invokes it.
- A dispatch-table entry (`when "some_cmd" ... return SomeWebHandler`) is not
  evidence of a caller either - that's still just server-side plumbing. The
  only real evidence is a `gameApi.requestOne`/`requestMany` call naming that
  exact `cmd` string somewhere in `webportal/`.
- Don't let a Known Limitations bullet describe a *conditional* failure mode
  ("won't work if your game lacks field X") when the real state is total
  absence ("doesn't exist yet regardless of config") - the former reads as
  "mostly works," which is a materially different, false claim to a game
  admin deciding whether to rely on the feature.

**Update:** Rather than build the missing frontend, this feature (rolls,
`InklingRoll.reroll_count`/`luck_cost`, `RollsApi.reroll_with_luck`, the
`inklings_reroll_with_luck` endpoint, and the README bullets describing it)
was removed outright - rarely used and not worth the added surface area.
Left the lesson above in place since the audit methodology it describes
(grep the consuming side, not just the implementation) generalizes beyond
this one feature.

---

### Lesson 22: When `github.com`/`api.github.com` are unreachable, `raw.githubusercontent.com` usually still is - use it to verify real Ares source instead of guessing

Needed the exact AresMUSH event fired on player login (name + field shape) to
hook a "notify on login if anything happened while you were offline" feature.
`github.com` and `api.github.com` both returned 403 in this sandbox (network
policy), and third-party mirrors (`jsdelivr`, `unpkg`, `codeload.github.com`)
were blocked too. `raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>`
was not blocked, and file paths could be guessed reliably by pattern-matching
this project's own already-confirmed real paths (the dev guide already cites
`aresmush/plugins/profile/custom_char_fields.rb`,
`aresmush/plugins/chargen/custom_approval.rb` - same `plugins/<name>/<file>.rb`
shape). That path led straight to `plugins/login/login.rb`
(`get_event_handler`, confirming the event is named `CharConnectedEvent`) and
`plugins/login/events/char_connected_event_handler.rb` (confirming the real
handler reads `event.char_id` and `event.client`) - both fetched from the live
`AresMUSH/aresmush` repo, not guessed.

- If `github.com`/`api.github.com` 403 in a sandboxed session, don't give up
  on verification and fall back to a guess - try
  `raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>` directly. It's a
  different host from the blocked ones and was reachable here even though
  `github.com` itself, `codeload.github.com`, `cdn.jsdelivr.net`, and
  `unpkg.com` were all policy-denied in the same session.
- There's no directory listing on `raw.githubusercontent.com` - you have to
  guess exact file paths. Anchor guesses to paths this project has *already*
  confirmed real (cited elsewhere in this guide or in this plugin's own
  source comments) rather than guessing blind; the naming convention usually
  carries over to the plugin/file you actually need.
- This is meaningfully better than the "flag it as scaffolding for the user
  to verify" fallback (see the `job_reply_event_handler.rb` precedent in §2)
  - a live fetch of the actual handler source is real verification, not a
    plausible-sounding guess with a disclaimer attached. Try this before
    reaching for scaffolding-with-a-warning.

---

### Lesson 23: Two different "color code" systems exist - AresMUSH `%x` markup and real ANSI escapes - and `{{ansi-format}}` only understands the latter

A user reported inkling roll entries showing on the web (badges, title) but
the roll *result* (e.g. "Good (7)") rendering as nothing. The template
already wrapped it in `{{ansi-format roll.result}}`, per §8 item 15's
`%x`-codes bullet (see the corrected version above) - which turned out to be
precisely the wrong fix, not a stale-install problem.

**Root cause, confirmed against real source (raw.githubusercontent.com):**
- `FS3Skills.print_dice` (`plugins/fs3skills/helpers/formatting.rb`) embeds
  AresMUSH's own `%x<code>...%xn` markup directly in the string it returns
  (e.g. `"%xg7%xn"`) - this is a MUSH-source-level convention
  (https://aresmush.com/tutorials/code/formatting.html), interpreted by the
  MUSH server's own emit pipeline when writing to a connected client.
- `ares-webportal`'s `{{ansi-format}}` helper (`app/helpers/ansi-format.js`)
  is a thin wrapper: `ansi_up.ansi_to_html(text, { use_classes: true })`.
  `ansi_up` parses **real ANSI terminal escape sequences** (`\e[32m` etc.) -
  a completely different, unrelated format. `%xg` is not an escape sequence
  to it; the text just passes through unrecognized, so the "colored" text
  effectively disappears or renders as junk instead of the intended value.
  These two systems share the vague idea "color codes for text" and nothing
  else - don't infer that a plausible-sounding helper name handles a given
  markup format without reading its actual implementation.

**The real, confirmed fix - two matched pairs of official converters, not a
custom parser:**
- `Website.format_input_for_html(text)` / `Website.format_input_for_mush(text)`
  (`plugins/website/public/website_api.rb`) convert MUSH's `%r` line-break
  markup to/from a real `\n`, in each direction. This project already used
  the pair correctly for chargen draft title/text
  (`custom_char_fields.snippet.rb`), but had NOT applied it anywhere in the
  Inkling message/reply/GM-note/approval-feedback pipeline - so a
  MUSH-typed multi-line reply lost its line breaks on web display (and a
  web-typed, multi-line reply lost them in the MUSH-side transcript/emit
  output), the exact same class of bug as the `%x` one, just for `%r`
  instead. **Confirmed against a real core plugin**:
  `plugins/jobs/web/job_reply_request_handler.rb` calls
  `Website.format_input_for_mush(reply)` on the way in, before saving -
  this project's `InklingApi.reply_to_inkling`/`add_gm_note`/`create_inkling`/
  `approve_inkling`/`request_changes_inkling` now do the same on the way in,
  and `InklingApi.format_message`/`Inklings.chargen_drafts` call
  `format_input_for_html` on the way out.
- `Website.format_output_for_html(text)` (same file) wraps
  `AresMUSH::MushFormatter.format(text)`, which converts **both** `%r` and
  `%x` codes into real HTML (with actual colors) in one pass - the correct
  call for text that genuinely has color markup, like `print_dice`'s output.
  Not adopted for `InklingRoll#result` in this pass - it returns literal
  HTML, which needs an explicit unescaped-render on the Ember side (a
  `{{{triple-mustache}}}`/`htmlSafe` pattern not yet confirmed against this
  project's Ember version) - `roll.result` is instead stripped of `%x`
  codes server-side (`Inklings.strip_color_codes`) for now: correct plain
  text, no color, pending that follow-up.
- The critical distinction driving which pair to use: is the field
  **user-typed free text** that might contain a line break (`%r` only -
  `format_input_for_html`/`_mush`), or **system-generated text with actual
  color markup** (`%r` and/or `%x` - `format_output_for_html`)? Don't reach
  for the color-capable converter on plain free text (it returns HTML,
  forcing an unescaped-render decision you don't need to make), and don't
  reach for the line-break-only converter on something with real `%x` in it
  (colors will render as literal junk).
- **Watch for the MUSH-vs-web call-site split.** `Website.format_input_for_mush`
  belongs ONLY at a web-exclusive entry point (a `public/*_api.rb` method
  only ever called by a web handler) - never inside a method also called
  directly from a MUSH command with already-`%r`-form text (e.g.
  `Inklings.approve_inkling`/`request_changes`, called by both
  `InklingApproveCmd`/`InklingNeedsChangesCmd` *and*
  `InklingApi.approve_inkling`/`request_changes_inkling`). Converting inside
  the shared method would double-process MUSH-typed input. Put the
  conversion in the web-only wrapper, immediately before it calls into the
  shared method - same principle as Lesson 6's viewer/actor distinction,
  applied to which caller a piece of text already came from.

---

### Lesson 24: The web portal's profile page never sends a separate "viewer" object to the client - viewer-relative data must be computed server-side and threaded through the custom-fields hook

`profile-custom.snippet.hbs` referenced `this.viewer.id` for two things - a
`viewerId` argument and an `isSelf` comparison
(`eq this.char.id this.viewer.id`) - since the snippet was first written.
Both were silently broken the entire time: a non-staff, fully-approved
character's own "New Inkling" button never appeared, because `isSelf` could
never be true.

**Confirmed against the user's real, live parent template** (the one that
invokes this component): only `@char` and `@game` are ever passed down -
`<ProfileCustom @char={{this.char}} @game={{this.game}}
@onReloadChar={{this.reloadChar}} />`. No `@viewer`/`@character`-as-viewer
argument exists anywhere in the chain. This matches the base `ares-webportal`
source (`app/templates/char.hbs`) exactly: every profile sub-component
(`ProfileDemographics`, `ProfileSystem`, etc.) receives `@char` only.
Viewer-relative permissions are computed server-side and baked directly
into the `char` payload instead (`char.can_manage`, `char.can_approve`) -
Ares' own pattern is "the server decides what the viewer is allowed to see
and hands the client a pre-resolved answer," not "hand the client both
objects and let it compare them."

**Same failure shape as Lesson 19 and the `is_approved` bug two lessons
above it**: a client-side reference to something that doesn't exist renders
as empty/`undefined`, not an error - so `this.viewer.id` produced no visible
symptom, no console warning, nothing to grep for. It just silently made
every comparison against it false, forever, for every character.

**The fix, and the general pattern it establishes:** the `get_fields_for_viewing(char, viewer)`
hook already receives BOTH the profile subject and the viewer as Ruby
parameters, server-side - the server has known "who's asking" the entire
time. Route that data through the same `custom` fields channel already
proven to work (this plugin's own `can_manage_inklings`/`inkling_types`):
`fields[:viewer_id] = viewer ? viewer.id : nil`, then reference
`this.char.custom.viewer_id` client-side, never a raw `this.viewer`.

- **Before assuming ANY object is available in an Ember template just
  because it would be convenient, find the actual invocation that renders
  that template and read its argument list.** A plausible-sounding
  property name (`viewer`, alongside an already-real `char`) is not
  evidence it exists - `char` being real proved nothing about `viewer`.
- **If a value the client needs isn't in the payload the base game sends,
  the fix is almost always "compute it server-side and add it to `custom`
  via `get_fields_for_viewing`"** - not inventing a new API endpoint, not
  trying to derive it from other client-side data. This hook is the
  general-purpose escape hatch for exactly this class of problem.
- When a bug report comes from a live, already-installed site, and the
  repo's own reference copy of a file looks correct: **ask for the literal
  rendered HTML** (or a temporary inline debug line printing the suspect
  properties: `{{this.isStaff}} {{this.isSelf}} {{this.isApproved}}`)
  before proposing more fixes blind. A real boolean `false` renders as the
  text "false"; `undefined`/`null` render as nothing - that distinction
  alone (as it did here) can immediately rule out entire categories of
  hypothesis (stale install vs. wrong field name vs. missing object)
  without needing shell access to the user's server at all.

---

### Lesson 25: Ember's `{{input}}` helper adds an `ember-checkbox`/`ember-text-field` class that a raw `<input>` tag doesn't - losing it can silently break theme-dependent styling

A web reply form's Private/Personal checkboxes rendered stretched full-width
with broken label alignment (v3 Bug 001). Both had been converted from
`{{input type="checkbox" checked=this.foo}}` to raw `<input type="checkbox"
checked={{this.foo}} onclick={{action "toggle"}}>` in an earlier round, to
attach a click handler for mutual-exclusivity - the markup itself
(`.form-check` wrapper, `.form-check-input`/`.form-check-label` classes) was
otherwise textbook Bootstrap and looked correct on inspection.

**The tell:** a structurally-identical roll-private checkbox a few lines
above, which still used `{{input}}`, was never reported broken. Same
wrapper, same classes, same theme - the only difference was helper vs. raw
tag. That made the helper's own output the prime suspect rather than the
visible HTML/CSS.

Ember's `{{input}}` component adds its own class (`ember-checkbox` for
`type="checkbox"`, `ember-text-field` for text inputs) on top of whatever
`class=` you pass - it doesn't replace it. A theme's CSS can end up keyed to
that Ember-added class (intentionally or as an accident of what the theme
author was actually looking at when they wrote the rule), so swapping to a
raw HTML tag keeps every class you wrote explicitly but silently drops one
you never knew was there.

- When replacing an Ember `{{input}}`/`{{textarea}}` helper invocation with
  raw HTML for more control (a custom event hook, `...attributes`, etc.),
  don't assume the visible `class=` list is the complete picture - the
  helper may be contributing its own class the surrounding theme depends on.
- If a raw-tag replacement regresses styling and an equivalent `{{input}}`
  invocation elsewhere in the same file still renders correctly, that's
  strong evidence to revert to the helper rather than chase the CSS. The
  helper's `change=`/`key-up=`/etc. closure-action hooks cover most of what
  people reach for raw HTML to get anyway (see `{{input type="checkbox"
  checked=this.foo change=(action "toggle")}}`).
- Adding an explicit, defensive CSS rule for the property that broke (here:
  pinning `.form-check-input { width: 1em; height: 1em; }`) is cheap
  insurance against the same regression recurring for an unrelated reason
  later, even after finding and fixing the actual root cause.

---

### Lesson 26: Changing a config default in code doesn't migrate servers that already have the old value baked into their setup

`+inkling/submit` and the web Submit button both started failing with a
generic "Could not notify staff of this submission" error (v3 Bugs 003/004)
- confirmed as a *regression*, not a pre-existing bug, since the web path
had worked in an earlier round.

**Root cause, confirmed against real AresMUSH core source
(`plugins/jobs/public/jobs_api.rb`):** `Jobs.create_job(category, ...)`
validates `category` against `Jobs.categories` (the game's actually-created
job categories) and returns `{ error: "Invalid job category ..." }` if it
doesn't match - it does not auto-create missing categories. A prior "release
polish" commit had changed this plugin's default `job_category` from
`"INKLINGS"` to `"Plots"` (config default only, not a live-server value).
Any server that had already run the plugin's *old* setup instructions
(`job/createcategory INKLINGS`) but never separately run `job/createcategory
Plots` would have every submission fail category validation from that
commit onward - on both MUSH and web, since both call the same
`Inklings.submit_inkling` → `ensure_job` → `Jobs.create_job` path, which is
exactly why the two bugs shared one identical, generic error message.

This compounds Lesson 18 (config auto-merge is unreliable) one level
further: even a *code-level default* isn't something you can casually rename
and expect existing installs to follow, because the thing the default names
(a job category) is manually created, one-time, real state on the live
server - not something `plugin/install` provisions. Changing what a default
points at is effectively the same as changing the config value itself, for
every server that's relying on the default rather than setting it
explicitly.

- Treat a default value that names external, manually-provisioned state
  (a job category, a channel, a role) as a breaking change if you rename it,
  even though it reads like an internal cleanup ("polish", "matches shipped
  config"). Grep the README/install docs for the old value before renaming
  a default - if setup instructions reference it, existing installs are
  depending on it.
- When a shared helper like `ensure_job` swallows a downstream error into a
  bare `nil`/generic message, the two symptoms it produces on different
  interfaces (MUSH command failure text, a web button that silently "does
  nothing") can look unrelated until you trace both back to the one call
  site. Preferring `{ result:, error: }`-shaped returns over sentinel `nil`
  throughout a call chain - as `submit_inkling` already did one level up,
  which is why threading it through `ensure_job` too was a small change - is
  what makes that trace possible instead of guesswork.
- A web action that discards `response.error` on failure without showing it
  anywhere (`if (response.error) { return; }`) will present as "the button
  doesn't work" for *any* server-side failure, not just this one. Once a
  component already injects a `flashMessages` service and uses it for
  client-side validation, reusing it for server-error responses is a
  one-line fix with an outsized effect on how "broken" a regression looks
  from the outside.

---

### Lesson 27: AresMUSH job categories are matched with an exact, case-sensitive string comparison - and the built-in defaults are upper-case

Lesson 26 already covered *renaming* a job category default as a breaking
change; a follow-up round of testing (v4 Bug 002) found the replacement
value itself was wrong in a different way: it was `"Plots"` (title case),
but AresMUSH's real default categories are upper-case (`PLOT`), and
`Jobs.create_job`'s category lookup is an exact string match - `"Plots"`,
`"plots"`, and `"PLOT"` are three unrelated strings to it, not
case-insensitive variants of the same category.

- When a default value names something that has to match a real,
  externally-defined string exactly (a job category, a permission name, a
  channel name), verify the *exact* casing against real source or an actual
  running game - don't assume title-case because it "reads" more like a
  normal config value. Guessing plausible-looking casing for a string that
  gets `==`-compared somewhere is the same class of mistake as guessing a
  file path; it fails silently and case-sensitively.
- Never uppercase (or otherwise transform) a configured value at runtime to
  "correct" it. An admin's exact configuration must be respected even if it
  doesn't match the shipped default's casing - transforming it silently
  would just trade one invisible mismatch for another, and would break any
  admin who deliberately created a differently-cased category on purpose.
- When a lookup like this can fail, make the failure diagnostic instead of
  generic: surface the exact string that was looked up and, if the
  underlying API provides it (as `Jobs.create_job` does - see Lesson 26),
  what the valid options actually are. That turns a silent case-sensitivity
  trap into a message that tells the admin exactly what to fix.

---

### Lesson 28: A field missing from a shared serializer breaks every template condition that reads it, on every page that uses it - and looks like a UI bug, not a data bug

Staff reported the web modal's Approve/Needs Changes controls were
completely missing on the admin page (v4 Bug 003) - "despite the previous
implementation attempt," per the bug report, implying the earlier round's
work (the unified review card, confirmed correct by reading the template
and the two web handlers it calls) simply didn't work. The template
condition gating the card was `{{#if (eq this.detail.approval_state
"submitted")}}` - correct-looking, and the same shape as several other
conditions in the same file that also silently never fired: the player's
"Request Unlock" button, and staff's own "Unlock" button.

**Root cause:** `InklingApi.format_inkling_summary` - the one serializer
both the detail view and every list view build on - never included
`approval_state` in its output hash at all. Every `this.detail.
approval_state` read on the client was `undefined`, forever, on every page,
for every inkling. `format_inkling_detail` merges on top of
`format_inkling_summary`, so the bug propagated to it automatically - fixing
one call site fixed every consumer.

This is the same failure shape as Lesson 24 (a raw `false` renders as text,
`undefined`/`null` render as nothing) one level removed: there the missing
thing was a whole object (`viewer`) the client assumed existed; here it was
one field silently absent from an otherwise-correct, otherwise-complete
payload. Both produce a `{{#if}}` that's always false with zero console
error, zero server error, and a template/component that reads entirely
correct on inspection - the bug is invisible until you check what the
*data* actually contains, not what the code that reads it says.

- When a reported "control is missing" bug survives a full read of the
  component/template that should render it (correct classes, correct
  nesting, correct action wiring - as it did here), stop reading the
  client and go verify what the *payload* actually contains for the field
  the condition depends on. A field a template reads but a serializer
  never sets is invisible from either side in isolation: the template
  looks right, and the serializer's omission isn't an error, just an
  absence.
- Prefer checking a real server response (or the shared serializer's
  source directly) over re-reading the same template a second time. Ares'
  own `{{#if (eq ...)}}` pattern gives no signal - no `undefined` warning,
  no key-not-found error - when the left-hand side was never set.
- If a bug report frames something as page-specific ("missing on the admin
  page") but the actual broken condition lives in a component shared
  across pages, verify whether it's really page-specific before scoping
  the fix that narrowly - here it wasn't (the same missing field affects
  every page using the shared modal), and fixing the one shared serializer
  method fixed every affected condition at once instead of patching the
  admin page in isolation.

---

### Lesson 29: A "close/change status with a message" Jobs API silently posts that message as its own comment - mirroring it back in later duplicates it

Approving an Inkling with a comment showed the comment twice (v5 Bug 001):
once as the canonical `[Approved]` entry this plugin creates directly, once
again moments later as a generic `[staff]` reply with identical text. The
bug report's own guess - "the web handler creates a staff reply and then
passes the same text to the approval workflow" - was wrong in a useful way:
reading the actual web handler showed it never creates a second reply at
all. The real cause was one level removed.

**Confirmed against real AresMUSH core source:** `Jobs.close_job(enactor,
job, message)` calls `Jobs.change_job_status(enactor, job, status,
message)`, which does `Jobs.comment(job, enactor, message, false)` as a
side effect - it posts `message` as an ordinary `JobReply` in addition to
changing the job's status. This plugin already has a mechanism that pulls
job comments back into the Inkling thread
(`Inklings.sync_job_replies`, called every time an inkling is viewed, on
both MUSH and web) precisely so staff replying via the linked job still
reaches the player. That mechanism doesn't know the comment it's mirroring
back in is the *same text* this plugin already recorded directly moments
earlier - it just sees an unmirrored `JobReply` and mirrors it, exactly as
designed. Two separately-correct behaviors compose into a duplicate.

This pattern recurred immediately while building the reopen feature in the
same round (v5 Bug 002): `Jobs.change_job_status` - the standard API for
moving a job to any status, reused to reopen the linked job - posts a
comment via the exact same path, so the reopen audit entry would have been
duplicated the same way if not caught before shipping.

- **Any call into a Jobs API that accepts a message/comment parameter
  should be treated as "this will also create a JobReply,"** even if nothing
  in the calling code creates one explicitly. `create_job`, `close_job`,
  and `change_job_status` all do this. If this plugin also records that
  same content directly (as `approve_inkling` and `reopen_inkling` both
  do), and `sync_job_replies` is in play, that's a duplicate waiting to
  surface the next time the thread is viewed - not immediately, which is
  part of what made it easy to miss originally.
- **The fix is to claim the JobReply as already-mirrored, not to suppress
  it or stop passing a message to the Jobs API.** After the Jobs call
  returns, look up the newest `JobReply` on the job
  (`JobReply.find(job_id:).max_by { |r| r.id.to_i }`) and set it as the
  `source_job_reply` on the message this plugin already created.
  `sync_job_replies`'s own dedup check
  (`InklingMessage.find(source_job_reply_id:).any?`) then skips it
  naturally. This preserves the real Jobs API's normal behavior (including
  whatever it does with `admin_only`, timestamps, etc.) instead of
  fighting it.
- **When fixing one call site of a shared pattern, grep for every other
  call site before declaring it done.** `mirror_to_job` (this plugin's own
  wrapper around `Jobs.comment`) is used by `unlock_inkling` and
  `request_changes` the same uncaught way `approve_inkling` used to be -
  not fixed in this round (out of the reported scope), but flagged as a
  near-certain latent duplicate for a future round rather than assumed
  fine because it wasn't reported yet.

---

### Lesson 30: Configurable permission names use a flat top-level config key, not a nested `permissions:` hash

Building a second plugin (SOUL) that needed three separate configurable
permission tiers (player/scene-GM/staff), the natural-looking design was a
nested hash: `permissions: { play: "play", gm_review: "gm", manage_soul:
"manage_jobs" }`. That was written into several design docs before anyone
checked it against a real, shipping example - this plugin's own
`manage_permission: manage_apps` setting (see `plugin/inklings.rb`'s
`can_manage_inklings?` and `game/config/inklings.yml`), which is a single
flat, top-level key under the plugin's own config section, not nested
under a shared `permissions:` block.

- When a design calls for "a permission name the admin can configure,"
  default to a flat `<verb>_permission` (or similarly named) top-level key
  per permission, matching the one real precedent in this ecosystem,
  rather than inventing a nested structure that merely looks more
  organized. Nesting isn't wrong in the abstract, but it's an unforced
  deviation from an established pattern with no confirmed benefit.
- This also matters mechanically: `AresMUSH::Manage::ConfigValidator`'s
  helpers (`require_nonblank_text`, `require_boolean`, etc. - see Lesson
  31) only read top-level fields of a config section
  (`@config[field]`). A nested hash forces custom validation code for
  every sub-key instead of one direct call per field.
- Most core AresMUSH plugins (Jobs, Chargen, etc.) don't make their
  permission names configurable at all - they hardcode a literal string
  like `"manage_jobs"` in the check itself. Configurable permission names
  are a deliberate design choice for plugins that want it (this plugin
  and SOUL both do), not a universal core convention to pattern-match
  against by default.

---

### Lesson 31: `AresMUSH::Manage::ConfigValidator` + a per-plugin `check_config` method is the real, confirmed mechanism for startup config validation - and no plugin is required to implement it

Every bundled core plugin that validates its own config (Jobs, Chargen,
FS3Skills, Website, Channels, Scenes, Roles, Login, and others - see
`aresmush/plugins/*/,*_config_validator.rb`) follows the identical shape:
a `self.check_config` class method on the plugin module (e.g.
`Jobs.check_config`), delegating to a `<Name>ConfigValidator` class that
wraps `AresMUSH::Manage::ConfigValidator.new(section_name)` and calls its
`require_boolean`, `require_int(field, min, max)`, `require_text`,
`require_nonblank_text`, `require_hash`, `require_list`,
`require_in_list(field, list)`, `check_cron`, `check_role_exists`,
`check_channel_exists`/`check_channels_exist`,
`check_forum_exists`/`check_forums_exist`, and `add_error` helpers,
finishing with `@validator.errors`. `PluginManager#check_plugin_config`
calls `check_config` on every loaded plugin that responds to it - so a
plugin without one simply isn't validated at startup, which is exactly
this plugin's own current state (`Inklings` defines no `check_config` at
all).

- Before writing custom config-validation code from scratch, check
  `AresMUSH::Manage::ConfigValidator` (`plugins/manage/config_validator.rb`)
  for an existing helper that already covers the check you need - most
  structural/type/range/reference checks (including "does this named role
  exist," "does this named channel/forum exist," "is this a valid cron
  hash") are already implemented there and reused by a dozen+ plugins.
- These helpers only validate **top-level** fields of a config section
  (`Global.read_config(section_name)` then `@config[field]`) - a nested
  hash's sub-fields need manual iteration and `@validator.add_error(...)`
  calls, not a `require_*` call with a dotted path (see Lesson 30 for why
  this favors flat config keys in the first place).
- `check_role_exists` validates that a config value names an actual
  **Role** (`Role.named(name)`) - it is NOT the right check for a
  configurable *permission name* setting like `manage_permission`. A
  permission is just a string that zero or more Roles happen to include
  in their `permissions` array (`AresMUSH::Role#has_permission?`); there's
  no fixed list of valid permission names to check membership against at
  config-load time. Use `require_nonblank_text` for those instead.

---

### Lesson 32: Help files load from a single `help/<locale>/*.md` directory per plugin - there is no separate admin-vs-player directory split

A design doc for a second plugin (SOUL) called for `help/admin/` and
`help/en/` as two separate directories, on the assumption that
admin-only topics would live somewhere distinct from player-facing ones.
Checking both halves of the real loading mechanism disproved this:
`PluginManager#help_files(plugin_module, locale)` globs exactly
`File.join(plugin_module.plugin_dir, "help", locale, "**.md")`, and the
separate game-level loader (`HelpReader#help_files`) globs
`File.join(AresMUSH.game_path, "help", locale, "**.md")` for game-authored
overrides. Neither mechanism knows or cares whether a topic is
"admin" or "player" - it's a single flat directory per locale
(`help/en/`, as this plugin's own `manage_inklings.md` demonstrates,
sitting in `help/en/` right alongside player-facing topics like
`inklings.md`).

- Admin-only help topics are distinguished by **content**, not directory:
  put a `> Permission Required: ...` blockquote near the top of the
  topic's body (see `plugin/help/en/manage_inklings.md`) rather than
  routing them to a different folder that nothing actually reads
  differently.
- Every help file needs YAML frontmatter with at least a `title:` field
  (`HelpReader#load_help_file` skips - with a warning - any file whose
  `MarkdownFile#metadata` comes back empty). Optional `toc:` groups it in
  a table-of-contents section; optional `aliases:` registers alternate
  lookup keys.
- Per CI-08-style conventions (see this plugin's own admin help topic
  naming), name the staff-facing topic file and its `title:` to match
  however staff are meant to type `help <topic>` for it - don't assume a
  separate directory will handle audience-appropriate discovery for you.

---

### Lesson 33: A class that looks like a real plugin hook isn't one until you find its actual call site - even in your own plugin's code

This plugin's own `plugin/hooks/chargen_hook.rb` defines
`ChargenHook.chargen_finalize(char)`, and its doc comments describe it as
a per-step chargen validation gate. Grepping the entire current AresMUSH
core (`aresmush/aresmush`, synced to a live 2026-07 commit - see Lesson 34
for why a stale checkout would have made this grep meaningless) for
`chargen_finalize` turns up **zero references** - nothing in the chargen
plugin, nothing in the dispatcher, nothing anywhere calls it. It is not
wired to anything. The real, confirmed chargen extension points are the
manual-paste `custom_approval.rb`/`custom_app_review.rb` snippets (see
`custom-install/custom_approval.snippet.rb` in this plugin, and
`aresmush/plugins/chargen/custom_approval.rb` / `custom_app_review.rb` in
core) - a completely different mechanism (game-owned file the admin
pastes a line into) from a plugin-defined hook class the framework
discovers and calls automatically.

- A hook-shaped class sitting in a plugin's own `hooks/` directory, with
  hook-shaped doc comments, is a **claim**, not a **guarantee** - the same
  principle as a stale "mirrors permission check in X" comment elsewhere
  in this guide. Before relying on it, replicating its pattern in another
  plugin, or writing documentation that describes it as real integration
  behavior, grep the actual framework source for the method name being
  "hooked." No hits means no wiring, regardless of how confident the
  surrounding comments sound.
- This is a stronger version of Lesson 1 (don't invent APIs without
  verification) - it applies even to reviewing your *own* already-written
  plugin, not just new integration code being written against another
  plugin's surface. Code that compiles and never errors (because nothing
  calls it) gives no signal that it's wrong.
- When this kind of dead hook is found, don't silently delete it without
  flagging it - it may represent a real, still-desired feature that was
  never finished being wired up, not merely a mistake. Surface it and let
  the project owner decide whether to wire it up for real, replace it
  with the confirmed mechanism, or remove it.

**Resolution (later session):** flagged directly to the project owner as
"check `chargen_finalize`'s call sites - dead code," with the same
three-way confirmation this lesson describes (structural placement inside
a nested class rather than a top-level `Inklings` method; no registration
or `custom-install/` reference anywhere in this plugin; the literal string
absent from current `AresMUSH/aresmush` core). Owner's call was to remove
it rather than wire it up - `plugin/hooks/chargen_hook.rb` is deleted, and
the two places elsewhere in this guide that cited `chargen_finalize` as a
real, usable hook pattern (§3's chargen "Correct pattern" list and §6's
Extensibility Principles hook-points bullet) were corrected to point at
`get_app_review_issues`/`custom_approval` instead - the mechanisms that
actually cover the adjacent, real behavior.

---

### Lesson 34: "Config is read live" means don't memoize it in your own plugin code - not that AresMUSH re-parses the YAML file on every call

`Global.read_config(section, key, subkey)` (`engine/aresmush/global.rb`)
delegates to `ConfigReader#get_config`, which reads from
`self.config[section_name]` - a hash parsed once, at boot
(`ConfigReader#load_game_config`), and re-parsed only when something
explicitly reloads it (`plugins/manage/commands/game/load_config_cmd.rb`,
the real `@config/load`-style staff command). It is an in-memory read, not
a disk read, on every call.

- Every plugin should still call `Global.read_config` fresh at each use
  site rather than caching the result in a Ruby-level constant or instance
  variable - that's what "changes take effect without a plugin reload"
  actually depends on. The cost being avoided is a plugin-level cache
  going stale after a staff config reload, not repeated file I/O (there
  isn't any on the hot path).
- Don't describe this behavior in plugin docs as "reads the YAML file live
  on every call" - it doesn't, and the distinction matters if anyone ever
  reasons about performance or about exactly when a config edit takes
  effect (answer: after the next config reload, not at the instant the
  file is saved to disk).

---

### Lesson 35: Before trusting a forked reference repo's conventions as "current," check its last commit date - a stale fork can look authoritative while actually contradicting live source

A reference checkout of AresMUSH core (`MischiefMaker/aresmush`, added to
verify a second plugin's design against real source per Lesson 1's own
advice) turned out to be frozen at a commit from **2019-12-15** - roughly
6.5 years stale relative to the actual current upstream, which had moved
to a 2026-07-08 commit sitting unfetched in the same fork the whole time.
Nothing about cloning or browsing the stale checkout signaled this; it
looked like a complete, ordinary AresMUSH installation right up until its
`git log -1 --date=short` was actually checked.

- Before treating any cloned reference repo as ground truth for "current"
  conventions, check its last commit date (`git log -1 --format='%ad'
  --date=short`) and compare it against how old the repo could plausibly
  be expected to be. A multi-year-stale core checkout can differ from live
  source in dispatcher internals, config validation helpers, plugin
  manager behavior, and more - several of the specific APIs this guide
  documents (`Global.plugin_manager.sorted_plugins`, the `check_config`
  mechanism) were confirmed only after fetching the fork's actual current
  upstream state.
- A fork that hasn't been synced in years isn't necessarily wrong to use -
  it's just not "current official AresMUSH conventions" (this guide's own
  stated authority-of-last-resort, above community examples) until it's
  confirmed to actually be current. Fetch and fast-forward it first, or
  explicitly flag findings sourced from it as reflecting that fork's
  specific (dated) commit rather than the live project.

---

## 9. Plugin Review Checklist

Before considering a plugin (or a plugin change) complete:

**Architecture**
- [ ] Every screen/component's data-loading approach matches a confirmed
      real-plugin precedent (Route+Controller for full pages; passed-in
      `char.custom.*` for static/small profile-tab data; self-fetch only
      where no cleaner extension point exists)
- [ ] No custom CSS/JS reimplements something Bootstrap 5 or
      `ember-truth-helpers` already provides
- [ ] No helper exists where a built-in Ares helper already covers it
- [ ] Web handlers are thin adapters; business logic lives in `public/*_api.rb`,
      shared with MUSH commands

**Parity & duplication**
- [ ] Every MUSH command has an equivalent web action, and vice versa
      (or the gap is deliberate and documented)
- [ ] No permission/filtering/formatting logic is duplicated between Ruby
      and Ember — checked explicitly, not assumed
- [ ] No dead/orphaned endpoints (grep for the web `cmd` name across the
      whole repo — if only the dispatch `case` and handler file reference
      it, it's dead)

**Configuration**
- [ ] Enumerable domain concepts are config-driven (`game/config/<plugin>.yml`),
      not hardcoded
- [ ] Permissions are configurable (a settable permission name), not
      hardcoded role checks
- [ ] Config is read live (`Global.read_config`), not memoized at boot

**Lifecycle & interop**
- [ ] Uses Ares's existing hook points (app review, chargen, custom fields,
      events) rather than reaching into other plugins directly
- [ ] Any dependency on another plugin's API/event is verified against that
      plugin's actual source, or explicitly flagged as unverified
- [ ] Optional dependencies degrade gracefully when absent, documented in
      "Known Limitations"

**Installation**
- [ ] A MUSH-only install (automated steps only, no manual web snippets)
      works completely, with the web tab simply absent
- [ ] Nothing auto-copied by `plugin/install` can break Ember's resolver if
      the optional web steps are never completed
- [ ] Everything that edits a shared game-owned file (`profile-custom.hbs`,
      `custom_char_fields.rb`, etc.) is a manual, mechanical `custom-install/`
      snippet — never assumed to be auto-mergeable
- [ ] README's automatic/manual split matches what the code actually does
- [ ] No legacy/dead implementation files remain anywhere an installer or
      resolver could pick them up

**Correctness**
- [ ] Every `gameApi.requestOne`/`requestMany` call matches its handler's
      actual return shape (bare array → `requestMany`; hash, including a
      composite one → `requestOne`)
- [ ] Every `.then()` that touches a response unwraps composite responses
      correctly (`response.thing`, not `response`) and guards on
      `response.error` before using the data
- [ ] Ruby hash-merge syntax (`**`, not `*`) verified with `ruby -c` on any
      snippet a user will paste

**Documentation**
- [ ] README accurately describes install steps, in the order they need to
      happen, with required/optional clearly marked
- [ ] Locale file has an entry for every user-facing string
- [ ] Help files exist for both player and admin-facing commands

---

## 9. FS3 System Integration

When a plugin needs to perform FS3 skill rolls (e.g., attaching rolls to
character development threads, scene logs, or activity results), use the
proper AresMUSH FS3 rolling API rather than trying to replicate the system.

### Rolling Skills

**Correct approach:**

```ruby
# Backend code
roll_params = AresMUSH::FS3Skills::RollParams.new(skill_name)
roll_outcome = AresMUSH::FS3Skills.one_shot_roll(character, roll_params)
# Returns: { success_title: "Good", successes: 3 }

result = "#{roll_outcome[:success_title]} (#{roll_outcome[:successes]})"
result_value = roll_outcome[:successes]
```

**Why:**
- `FS3Skills.one_shot_roll()` handles the full FS3 mechanics: determining
  dice pool, rolling, computing successes, generating success titles, and
  logging to game logs.
- Creating a `RollParams` object allows modifiers and linked attributes to be
  passed if needed (see source: `plugins/fs3skills/public/fs3skills_api.rb`).
- Never try to roll FS3 dice directly or implement your own success-counting
  logic — that will drift out of sync with the core FS3 system's actual
  behavior.

### Web Portal Rolls

For web portal forms that trigger rolls, don't perform rolls on the frontend.
Instead:

1. Frontend passes the skill name to backend (`gameApi.requestOne('handler', {skill: 'Spelling'})`).
2. Backend performs the roll using `FS3Skills.one_shot_roll()`.
3. Backend stores the result and returns it.

This matches the pattern used by `addSceneRoll` and `addJobRoll` in the core
engine — separation of concerns between the request layer (frontend) and the
operation layer (backend).

### Permission Check

Before allowing a player to roll via the web portal, verify their character is
approved:

```ruby
unless viewer.is_approved?
  return { error: "Your character must be approved to roll." }
end
```

Some systems (like luck rerolls) may have additional approval checks.

---

## 9b. Web Portal Styling

**Lesson learned (verified on this project, corrects earlier guidance below):**
An AresMUSH admin's theme color setup screen lists names like
`primary-words-color`, `box-background-color`, `border-color`, etc., and it's
natural to assume these are available to plugin CSS as runtime custom
properties (`var(--primary-words-color)`). **They are not.** They're Sass
variables (`$primary-words-color: #ebebeb;`) substituted directly into
specific compiled selectors (`h1`, `th`, `.list-group-item`, ...) at
theme-build time, on the *game's* build, not the plugin's. Confirmed via
browser devtools on a live install:

```js
getComputedStyle(document.documentElement).getPropertyValue('--primary-words-color')
// => "" (empty - the property does not exist)
```

Any plugin CSS rule written as `var(--primary-words-color)` (or any of the
other names below) silently resolves to nothing - no error, no fallback,
just as if the property/value were never set. This produced a long series of
"still doesn't look right" bugs on this project (wrong hover color, wrong
background) that each looked like a small tuning mistake, when the real
problem was that the color reference could never have worked.

**What to use instead:**

- **Don't set a color at all when possible.** Letting an element inherit is
  the most reliable way to pick up the game's real theme color, since the
  game's own compiled CSS already sets it correctly on ancestor elements
  (`body`, `.modal-content`, etc.) via the same Sass variables. This is the
  approach this plugin settled on for the Inklings list/modal text.
- **`currentColor` and `color-mix()`** for anything relative (a subtle hover
  highlight, a divider) - `currentColor` always reflects whatever the real,
  correctly-inherited text color is for the active theme, so
  `color-mix(in srgb, currentColor 10%, transparent)` adapts automatically to
  light or dark themes without ever needing to know the actual hex value.
- **Bootstrap's own `--bs-*` custom properties** (`--bs-border-color`,
  `--bs-secondary-bg`, etc.) - these genuinely are real runtime CSS custom
  properties in Bootstrap 5.3+, unlike the Ares theme names above. Prefer
  reaching them via an existing Bootstrap utility class over writing a
  custom rule that references the variable directly.
- **Never hardcode a hex color** as a substitute - that reintroduces the
  exact "wrong on this game's theme" problem these variables were meant to
  solve, just less discoverable.

Before assuming any admin-configurable theme name is a real CSS custom
property, verify it the same way: check with `getComputedStyle` in the
browser console on a live install, don't assume from the settings-screen
label.

**Second lesson learned (verified on this project): background-carrying
Bootstrap classes are not automatically safe either**, even though their
underlying `--bs-*` variables are real. `.bg-body-secondary` was tried on
this project for a subtle staff-message highlight and came back unreadable
(a light/white box) on a dark-themed install. Bootstrap 5.3's color-mode
variables only swap their light/dark values under a `data-bs-theme="dark"`
attribute on an ancestor element - and Ares' own theme system (recompiled
Sass per game, see above) has no reason to ever set that attribute, so
Bootstrap background utilities can silently stay locked to their light
default regardless of the game's actual theme. The same risk applies to
any Bootstrap class that carries a background as part of its design, not
just utility classes - `.input-group-text` was also tried for a form-field
label prefix and had the identical problem (unreadable label text against
its own baked-in background).

The practical rule this project settled on: **prefer classes/elements that
never set a background at all** over ones that do, whenever the only goal
is a visual accent or grouping, not an actual color-coded meaning:
- A **border** (`.border`, `.border-start`, `.border-bottom`) only sets
  `border-color`, never touches text or background color, so it can't
  create a contrast problem - use this instead of a background tint for
  "highlight this block."
- A **plain `<label>`** (or any element with no Bootstrap component class
  applied) has no background of its own and simply inherits the correct,
  already-working theme text color - use this instead of
  `.input-group-text` when you want a label sitting next to a field with no
  visual box around it.
- If a background is genuinely necessary, don't assume any Bootstrap
  utility that has one is theme-safe just because its variable is real -
  actually test it against a dark-themed install before trusting it.

### Contrast and Backgrounds

- Light backgrounds with light text = unreadable. Don't apply `.text-muted`
  (light grey) over `.bg-light` (white). Use Bootstrap's `.text-secondary` or
  `.text-dark` instead.
- When a component has conditional backgrounds (e.g., staff messages with
  `bg-light`), use semantic Bootstrap classes (`.text-secondary`, `.text-dark`)
  rather than custom color assignments, since they're designed to work in both
  dark and light contexts.
- **Don't apply `.text-muted` to semantic text that should inherit normal
  theme color.** Name fields, message counts, regular paragraph text, and other
  non-secondary content should inherit the parent element's already-correct
  theme text color. `.text-muted` is for genuinely de-emphasized content
  (timestamps, helper text, disabled items), not for avoiding an explicit color
  assignment on text that's meant to be primary.
- Always test with the installation's actual theme colors, not defaults. A
  game's primary color might be a light blue on a dark background, or
  vice versa.

### Form Labels Next to Inputs

When placing a label beside an input (not above it), use a plain `<label class="form-label mb-0">` in a flexbox row, never `input-group-text`. The `input-group-text` Bootstrap component carries its own background and border that don't reliably follow all Ares themes, producing unreadable text on dark-themed installs. A plain label has no background and inherits the correct theme text color:

```hbs
<div class="d-flex align-items-center gap-2 mb-3 w-100">
  <label for="field-title" class="form-label mb-0">Title</label>
  {{input id="field-title" type="text" class="form-control" ...}}
</div>
```

Add `w-100` to the flex container to ensure the row and its input stretch to full width, matching any textarea below it.

### CSS Installation

New CSS files in `webportal/styles/` need to be copied to the ares-webportal
installation, **imported into `app.scss`**, and the webportal needs to be
rebuilt. All three steps are required - missing any one leaves the plugin's
styles completely inert with no error or warning:

```bash
cp /path/to/plugin/webportal/styles/mycomponent.scss /path/to/ares-webportal/app/styles/
```

Then add an `@use` line to `ares-webportal/app/styles/app.scss` (alongside its
existing `@use` lines for other partials like `advanced-colors`):

```scss
@use "mycomponent";
```

Then rebuild:

```bash
cd /path/to/ares-webportal
npm run build  # or npm start for development
```

**Lesson learned (verified on this project):** copying the file into
`app/styles/` is *not* sufficient by itself, even after a rebuild - Ember's
Sass build only compiles files `app.scss` actually references via `@use`/
`@import`. A plugin can auto-copy its `.scss` into place (that part is safe,
inert-until-referenced), but the `app.scss` edit is a manual step against a
file the game already owns, and it's easy to never notice it's missing:
Bootstrap classes referenced directly in your templates (`.badge`,
`.border-bottom`, etc.) will render correctly regardless, since they come
from the separately-loaded global Bootstrap CSS - only rules that live in
your own uncompiled `.scss` file silently do nothing. On this project, that
produced a long string of "still not working" reports (no hover, no bullet
removal, no flex layout, not even a bare `cursor: pointer`) that looked like
a series of small CSS mistakes, when the actual cause was that the whole
stylesheet was never being compiled in at all. If a plugin's own CSS doesn't
seem to be having *any* effect - not even trivial layout properties -
suspect this before debugging individual rules. **This plugin's own README**
originally claimed "no plugin stylesheet to import," written before
`inklings.scss` existed and never updated - always double check that kind of
claim against what's actually in `webportal/styles/` before trusting it.

If using `.ares-manifest.yml` to install the plugin, include the
`webportal/styles/` directory in the install paths so the file is copied
automatically - but still document the required `app.scss` import as a
manual README step, since the installer cannot safely edit a file the game
owns.

---

---

## 10. References

**Official documentation** (aresmush.com/tutorials/code/) — read for
vocabulary and intent, verify against source for exact behavior:
- [Web Portal Overview](https://www.aresmush.com/tutorials/code/web-portal.html)
- [Web Portal Routes](https://aresmush.com/tutorials/code/web-routes.html)
- [Game Api](https://www.aresmush.com/tutorials/code/web-game-api.html)
- [Web Portal Services](https://www.aresmush.com/tutorials/code/web-services.html)
- [Web Portal Templates](https://www.aresmush.com/tutorials/code/web-templates.html)
- [Web Portal Mixins](https://www.aresmush.com/tutorials/code/web-mixins.html)
- [Web Portal Navigation](https://aresmush.com/tutorials/code/web-nav.html)
- [Debugging Web Requests](https://www.aresmush.com/tutorials/code/web-debug.html)
- [Custom Character Fields](https://aresmush.com/tutorials/code/hooks/char-fields.html)
- [Ares Architecture](https://www.aresmush.com/tutorials/code/architecture.html)
- [Using Permissions in Code](https://aresmush.com/tutorials/manage/roles.html#using-permissions-in-code)
- [Learning EmberJS](https://aresmush.com/tutorials/code/ember.html) (index page only — links out to general Ember docs)

**Authoritative source repositories** (clone or fetch via GitHub API/raw URLs
— treat as ground truth over the tutorials above):
- [`AresMUSH/aresmush`](https://github.com/AresMUSH/aresmush) — core engine
  and bundled plugins (`plugins/<name>/`). Look here for
  `custom_char_fields.rb`'s real hook signatures, bundled plugins' command/
  web-handler conventions, and locale file conventions.
- [`AresMUSH/ares-webportal`](https://github.com/AresMUSH/ares-webportal) —
  the actual Ember app. Look here for `app/services/game-api.js` (the real
  `GameApi` contract), `app/routes/char.js` (how the profile page's own
  route loads Scenes as a parallel `RSVP.hash` request), `app/routes/job.js`
  + `app/controllers/job.js` (full Route+Controller page pattern), and
  `app/components/profile-*`/`chargen-*` (the actual extension-point
  components a plugin's manual snippets get pasted into).

**Third-party plugins worth comparing against** for patterns a real,
non-core plugin can replicate:
- [`AresMUSH/ares-rpg-plugin`](https://github.com/AresMUSH/ares-rpg-plugin) —
  `webportal/components/rpg-profile.js` (near-empty component reading
  `char.rpg.sheet` directly — the "no self-fetch for static data" pattern)
  and `webportal/components/rpg-chargen.js` (the `onUpdate()` callback
  registration pattern for chargen extensions).
- [`cailleach1310/ares-marque-plugin`](https://github.com/cailleach1310/ares-marque-plugin) —
  `webportal/components/profile-dowayne.js` (actions-only component reading
  `char.custom.house_list`) and `custom_files/profile-custom.hbs` (a real,
  working example of the manual-snippet extension point in practice,
  including a nested list/table embedded entirely via `char.custom.*`).

**This project's own git history** is itself a useful reference for what
went wrong and how it was fixed — particularly:
- `2df299c` — removing a leftover React component that was breaking the
  Ember resolver, and the auto-copy vs. manual-snippet split that resulted.
- `a4af6d0`, `67a4a36` — removing custom helpers that duplicated bundled
  Ares/Ember functionality.
- `6f4f417` — removing a speculative `.ares-manifest.yml` that didn't match
  actual installer behavior.
- `plugin/events/job_reply_event_handler.rb` — a live example of how to
  write and honestly flag an unverified integration.
