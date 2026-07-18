# Audit: Could Ares Collapsible Markdown Replace Inkling Expansion?

**Question:** Could AresMUSH's built-in collapsible Markdown feature (`[[collapsible ...]]`) replace the Inklings plugin's custom Inkling expansion implementation?

**Conclusion:** No. Collapsible Markdown is designed for static read-only content; Inkling expansion requires a fully interactive Ember component with API integration and dynamic state management.

---

## 1. How Ares Collapsible Markdown Works

**Nature**: Purely static HTML rendering
- Converts `[[collapsible Label]] ... [[/collapsible]]` syntax into browser-native collapsible HTML elements
- Likely uses HTML5 `<details>`/`<summary>` or equivalent CSS-based toggle
- No JavaScript interactivity beyond browser-native show/hide
- Renders at **page generation time**, not on user interaction

**Intended Use**: Per `ARES_PLUGIN_DEVELOPMENT_GUIDE.md` (lines 304-309), collapsible Markdown is described as "genuinely domain-specific layout" — a static rendering feature, not an interactive component framework.

**Scope**: Read-only text display only. Cannot wrap:
- Ember components
- Form inputs with state
- Event handlers/actions
- API integrations

---

## 2. Current Inkling Expansion Implementation

### Architecture: Fully Interactive Ember Component

**Component File**: `webportal/components/inklings-tab.js`

**State Management**:
- `expandedId` property (line 34) — tracks which inkling is currently expanded
- `expandedInkling` computed property (lines 115-134) — looks up full detail object by ID from the list
- Conditional template rendering: `{{#if (eq this.expandedId inkling.id)}}` shows/hides detail section

**API Integration**:
- `reloadInklingDetail(id)` method (lines 102-119) — makes API call when user clicks expand
- Calls `inklings_get_inkling` web handler (`plugin/web/inklings_get_inkling_web_handler.rb`)
- Response contains: full messages, rolls, shared_with, staff controls, etc.
- `replaceInkling()` updates the inkling object in the list with full detail

**Interactive Actions**: 20+ Ember actions in the detail view:
```
submitReply(id)           — add public reply (API call)
submitPersonalReply(id)   — add private note (API call)
togglePrivateReply(id)    — toggle reply privacy (state)
updateReplyText(id)       — update reply input (state)
addTag(id)                — add tag (API call)
removeTag(id)             — remove tag (API call)
addRoll(id)               — attach dice roll (API call)
rerollWithLuck(id)        — reroll with luck points (API call)
approveInkling(id)        — staff approval (API call)
requestChanges(id)        — send back for revisions (API call)
grantReward(id)           — award XP/skills (API call)
submitInkling(id)         — submit for review (API call)
shareInkling(id)          — share with characters (API call + state)
closeInkling(id)          — close thread (API call)
deleteInkling(id)         — request deletion (API call + job creation)
unlockInkling(id)         — reopen for editing (API call)
```

**Template**: `webportal/templates/components/inklings-tab.hbs` (lines 89-332)

Detail section renders **only when expanded**, containing:
- Threaded messages with visibility filtering
- Rolls with reroll-with-luck buttons (calls `rerollWithLuck` action)
- Forms for replies (text inputs, checkboxes for private/personal)
- Action buttons (Approve, Request Changes, Grant Reward, Submit, Share, Close, Delete, Unlock)
- Staff-only sections (GM notes, reward history)
- Tag input with add/remove buttons

**Styling**: `webportal/styles/inklings-tab.scss` (394 lines)
- `.inkling-header.expanded` — background color on expand
- `.expand-icon.open` — arrow rotates 180° when detail visible
- `.inkling-detail` — padding/borders for expanded content
- Smooth transitions on state change

---

## 3. Data Flow Comparison

### Collapsible Markdown
```
1. Page loads → Server renders all inkling summaries as HTML
2. Markdown processor generates static `<details>` for each summary
3. All detail content pre-rendered in the HTML (bloats page size)
4. User clicks expand → Browser toggles visibility (no server call)
5. Detail content is already there, just shown/hidden
```

### Inkling Expansion
```
1. Page loads → Component renders list of inkling summaries only
2. User clicks expand arrow → expandInkling action fires
3. reloadInklingDetail() makes API call to get full thread
4. API handler format_inkling_detail() returns: messages, rolls, shared_with, etc.
5. Component receives response, replaces summary with detail, sets expandedId
6. Template conditional {{#if expandedId}} now renders the full detail view
7. Detail view is interactive: user can submit replies, add rolls, approve, etc.
```

---

## 4. What Would Break With Collapsible Markdown

| Feature | Current Implementation | With Collapsible Markdown |
|---------|----------------------|-------------------------|
| **Reply Forms** | Hidden until expanded; appear only in detail view | Must always be pre-rendered (bad UX) or not supported |
| **API Calls** | Triggered on expand; fetch only needed data | All detail data must be pre-rendered on page load |
| **Form State** | Component manages reply text, tag inputs, roll selectors via properties | Would need uncontrolled HTML inputs; no validation |
| **Permissions** | `{{#if this.isStaff}}` hides staff-only controls client-side | Cannot conditionally render based on permissions; must render for everyone or server-render separately |
| **Message Threading** | Dynamically filtered via `visible_messages_for(inkling, viewer)` API call | Must pre-render all messages server-side; permissions leak |
| **Unread Status** | `player_unread` updated dynamically when viewing via API call | Would require page reload |
| **Reroll with Luck** | Ember action checks character's luck, calls reroll API, updates rolls | Not possible; would need page reload |
| **Staff Actions** | Approve, Request Changes, Grant Reward, Unlock all trigger API calls | Page reload required after each action |
| **Tag Management** | Add/remove via Ember actions; no page reload | Page reload required |
| **Sharing** | Modal/form to select characters; API call on submit | Not possible in collapsible Markdown |
| **Deletion Workflow** | Confirm dialog, API call, creates job — all without reload | Would require navigating away and back |

---

## 5. Why Other Ares Plugins Don't Use Collapsible Markdown for Lists

**Reference**: `ARES_PLUGIN_DEVELOPMENT_GUIDE.md` (§4: Known Ares Web Patterns)

#### ares-rpg-plugin (Sheet Viewing)
- Shows character sheet as read-only text
- No expand/collapse needed — entire sheet fits on one tab
- Data embedded on character payload (`char.rpg.sheet`)
- No interactive elements, no API calls on interaction

#### ares-marque-plugin (House Directory)
- Shows house members in a table
- No expand/collapse
- Reads `char.custom.house_list` (embedded on payload)
- No actions; purely informational

#### Ares Jobs (Ticket List)
- Shows job summaries in a list
- Clicking a job navigates to a **full separate detail page** (Route + Controller + Template)
- Not an expandable row — a separate view with full detail rendering
- Detail page has Reply form, status buttons, all interactive controls
- POST requests for actions; user sees page refresh

#### Ares Scenes (Scene List)
- Clicking a scene navigates to scene detail page
- Not in-place expansion

**Pattern**: Ares uses either:
1. **Navigation to detail page** (Jobs, Scenes) — full Route + Controller + Template for interactive detail
2. **Embedded read-only data** (RPG sheet, Marque house list) — no interactivity needed

**None use expandable rows with interactive controls inside the row.** Inkling expansion is unique because it combines both patterns: in-place expansion (like Jobs' job list) with interactive controls inside the expansion (like detail page).

---

## 6. Architectural Assessment

### Is Inkling Expansion Unnecessarily Custom?

**No.** The implementation follows a legitimate pattern:
- **Component-based architecture** matches Ares conventions (use Ember components for interactive UI)
- **API-on-expand pattern** is optimal for:
  - Large lists (detail not pre-rendered, smaller page load)
  - Permission-sensitive data (detail fetched server-side with viewer context)
  - Stateful interactions (replies, tags, rolls managed in component)
  - Lazy loading (only fetch detail when user requests it)

### Could Ares Provide a Built-in Component for This?

Theoretically, Ares could provide a generic "expandable detail list component" that:
- Manages `expandedId` state
- Calls a configurable API endpoint
- Renders a slot for the summary and a slot for the detail

But this doesn't exist in the current Ares webportal, and Inkling is not "custom" for inventing it — it's a reasonable architectural choice given Ares's component-based design.

---

## 7. Could We Use Collapsible Markdown for Part of the UI?

**Possible but inadvisable**:

Could we use collapsible Markdown for the message text rendering inside the detail view?

```hbs
{{#each detail.messages as |msg|}}
  {{#if msg.is_markdown}}
    [[collapsible {{msg.author}}: {{msg.created_at}}]]
    {{{format_markdown msg.text}}}
    [[/collapsible]]
  {{else}}
    <div class="message">{{msg.text}}</div>
  {{/if}}
{{/each}}
```

**Why not**: 
- Adds unnecessary nesting (inkling expanded → message collapsed)
- Messages are short; not worth collapsing
- Introduces markdown dependency where plain text works
- No benefit over current message list

---

## 8. Final Recommendation

**Recommendation**: Keep the current Ember component implementation.

### Why

1. **Architectural alignment**: Matches Ares's component-based pattern (Jobs detail page also has interactive controls; Inkling just does it in-place)

2. **Functionality required**: Collapsible Markdown cannot support:
   - API calls on expand (essential for lazy-loading detail)
   - Form inputs with validation
   - Ember actions (20+ interactions)
   - Permission-scoped rendering (detail fetched with viewer context)

3. **Data model**: Messages are plain text, not pre-rendered Markdown. Converting to Markdown rendering would be a breaking change.

4. **User experience**: In-place expansion without page navigation is better UX than navigating to a separate detail page (which is what Jobs does).

5. **Development guide alignment**: `ARES_PLUGIN_DEVELOPMENT_GUIDE.md` (§7: Common Mistakes) explicitly calls out the problem being solved:
   > "Don't use a pre-fetched list of all possible values when you need only what a viewer can access."
   
   Inkling expansion solves this by fetching detail server-side with viewer context, only when needed.

### What To Do About the Current Errors

The "resolvedDefinition is null" error was caused by a **missing helper** (`local-date`), not by using custom expansion. The fix (adding the helper) is the correct solution.

If the component genuinely cannot be registered or the helper path is wrong, the issue is deployment/setup, not architectural.

---

## References

- **Component implementation**: `webportal/components/inklings-tab.js`
- **Template**: `webportal/templates/components/inklings-tab.hbs`
- **Styling**: `webportal/styles/inklings-tab.scss`
- **API handler**: `plugin/web/inklings_get_inkling_web_handler.rb`
- **API method**: `plugin/public/inklings_api.rb` → `format_inkling_detail()`
- **Comparison patterns**: `ARES_PLUGIN_DEVELOPMENT_GUIDE.md` (§4, §7)
- **Ares Markdown docs**: https://www.aresmush.com/help/markdown.html#collapsible-text (read-only feature, confirmed)
