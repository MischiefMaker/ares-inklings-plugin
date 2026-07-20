// Shared "New Inkling" creation form, used by both the profile tab
// (inklings-tab.hbs, mode="profile") and the admin page
// (admin-inklings.hbs, mode="admin"). Automatically installed to
// ares-webportal/app/components/ via plugin/install.
//
// The two modes differ only in who the owner is and whether "Players
// with Access" is offered - the type/title/text fields and validation
// are identical either way, which is why this is one component with an
// explicit `mode` argument rather than two forms or a component that
// inspects the current route.
//
// mode="profile" (inklings-tab.hbs):
//   - characterId is already known (the profile being viewed) - owner
//     is never asked for, and creation goes straight through the
//     existing inklings_create_inkling endpoint, completely unchanged
//     from before this component existed.
// mode="admin" (admin-inklings.hbs):
//   - No single "current profile" exists, so the operator picks an
//     owner (single-select) and, optionally, who else has access
//     (multi-select) from `characters` - the same PowerSelect/
//     PowerSelectMultiple pattern the core Jobs plugin's job-edit.hbs
//     uses for its Submitter/Assigned To (single) and Other
//     Participants (multi) fields, populated from the same core
//     `characters` web request Jobs itself uses (see
//     webportal/routes/admin-inklings.js). Creation goes through
//     inklings_create_inkling_by_name - a thin wrapper around
//     InklingApi.create_inkling/add_participants_by_id, not a second
//     creation path (see plugin/public/inklings_api.rb).
//
// Matching Jobs' own submission convention exactly: the single-select
// owner is submitted by name (job-edit.js's submitterChanged／
// assigneeChanged fields go by `.name`), the multi-select access list
// is submitted by id (job-edit.js's participantsChanged field goes by
// `.map(p => p.id)`).

import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  gameApi: service(),
  flashMessages: service(),

  // --- Required arguments ---
  mode: 'profile', // 'profile' | 'admin'
  typeInfo: null,
  characterId: null, // profile mode
  characters: null, // admin mode - array of { id, name, icon }
  onCreated: null, // closure action, called with the created inkling

  // --- Internal state ---
  newKind: '',
  newTitle: '',
  newText: '',
  newOwner: null, // admin mode - single character object
  newAccess: null, // admin mode - array of character objects

  actions: {
    setNewKind(kind) {
      this.set('newKind', kind);
    },

    ownerChanged(char) {
      this.set('newOwner', char);
    },

    accessChanged(chars) {
      this.set('newAccess', chars);
    },

    submit() {
      let isAdmin = this.mode === 'admin';

      if (isAdmin && !this.newOwner) {
        this.flashMessages.danger('Please select an owner');
        return;
      }
      if (!this.newKind) {
        this.flashMessages.danger('Please select a type');
        return;
      }
      if (!this.newTitle || !this.newTitle.trim()) {
        this.flashMessages.danger('Please enter an inkling title');
        return;
      }
      if (!this.newText || !this.newText.trim()) {
        this.flashMessages.danger('Please enter inkling text');
        return;
      }

      let request = isAdmin
        ? this.gameApi.requestOne('inklings_create_inkling_by_name', {
          owner_name: this.newOwner.name,
          kind: this.newKind,
          title: this.newTitle,
          text: this.newText,
          shared_with_ids: (this.newAccess || []).map((c) => c.id)
        }, null)
        : this.gameApi.requestOne('inklings_create_inkling', {
          char_id: this.characterId,
          kind: this.newKind,
          title: this.newTitle,
          text: this.newText
        }, null);

      request.then((response) => {
        if (response.error) {
          return;
        }
        if (response.share_warning) {
          this.flashMessages.warning(`Inkling created, but sharing failed: ${response.share_warning}`);
        }
        this.setProperties({
          newKind: '',
          newTitle: '',
          newText: '',
          newOwner: null,
          newAccess: null
        });
        if (this.onCreated) {
          this.onCreated(response.inkling);
        }
      });
    }
  }
});
