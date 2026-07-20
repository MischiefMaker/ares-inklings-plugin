// Shared "New Inkling" creation form, used by both the profile tab
// (inklings-tab.hbs, mode="profile") and the admin page
// (admin-inklings.hbs, mode="admin"). Automatically installed to
// ares-webportal/app/components/ via plugin/install.
//
// The two modes differ in character selection and sharing workflow:
//
// mode="profile" (inklings-tab.hbs):
//   - characterId and characterName are the profile being viewed
//   - Main Character is shown as a static label (not editable)
//   - Share With selector allows optional sharing with other characters
//   - Creation goes through inklings_create_inkling endpoint
//   - Profile owner can share with others; admins can share on any profile
//
// mode="admin" (admin-inklings.hbs):
//   - No single "current profile" exists; admin picks the owner via dropdown
//   - Main Character selector uses PowerSelect (single-select)
//   - Share With selector allows optional sharing with other characters
//   - Creation goes through inklings_create_inkling_by_name endpoint
//
// Share With workflow (both modes):
//   - User selects characters from PowerSelectMultiple (pendingSharedWith)
//   - User clicks "Add" to confirm selections (moves to sharedWithList)
//   - User reviews and can remove individuals from sharedWithList
//   - On submission, sharedWithList is sent as shared_with_ids

import Component from '@ember/component';
import { A } from '@ember/array';
import { inject as service } from '@ember/service';
import { computed } from '@ember/object';

export default Component.extend({
  gameApi: service(),
  flashMessages: service(),

  // --- Required arguments ---
  mode: 'profile', // 'profile' | 'admin'
  typeInfo: null,
  characterId: null, // both modes - the profile being viewed (or created for)
  characterName: null, // profile mode - display name of the character
  characters: null, // admin mode - array of { id, name, icon }
  onCreated: null, // closure action, called with the created inkling

  // --- Internal state ---
  newKind: '',
  newTitle: '',
  newText: '',
  newOwner: null, // admin mode - single character object
  pendingSharedWith: A(), // characters selected but not yet confirmed
  sharedWithList: A(), // characters confirmed to share with

  // Description of the currently-selected type, shown under the dropdown -
  // matches +inkling/types on the MUSH side, which already shows this.
  selectedTypeDescription: computed('newKind', 'typeInfo', function () {
    let selected = (this.typeInfo || []).find((t) => t.kind === this.newKind);
    return selected ? selected.description : null;
  }),

  actions: {
    setNewKind(kind) {
      this.set('newKind', kind);
    },

    ownerChanged(char) {
      this.set('newOwner', char);
    },

    pendingSharedWithChanged(chars) {
      this.set('pendingSharedWith', A(chars || []));
    },

    addSharedWith() {
      if (this.pendingSharedWith.length === 0) {
        return;
      }
      // Add pending selections to the confirmed list, avoiding duplicates
      let currentIds = new Set(this.sharedWithList.mapBy('id'));
      let toAdd = this.pendingSharedWith.filter((c) => !currentIds.has(c.id));
      this.sharedWithList.pushObjects(toAdd);
      // Clear pending selections
      this.set('pendingSharedWith', A());
    },

    removeSharedWith(char) {
      this.sharedWithList.removeObject(char);
    },

    submit() {
      let isAdmin = this.mode === 'admin';

      if (isAdmin && !this.newOwner) {
        this.flashMessages.danger('Please select a main character');
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
          shared_with_ids: this.sharedWithList.mapBy('id')
        }, null)
        : this.gameApi.requestOne('inklings_create_inkling', {
          char_id: this.characterId,
          kind: this.newKind,
          title: this.newTitle,
          text: this.newText,
          shared_with_ids: this.sharedWithList.mapBy('id')
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
          pendingSharedWith: A(),
          sharedWithList: A()
        });
        if (this.onCreated) {
          this.onCreated(response.inkling);
        }
      });
    }
  }
});
