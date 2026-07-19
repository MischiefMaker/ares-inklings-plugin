// Inklings web portal component - list view.
// Automatically installed to ares-webportal/app/components/ via plugin/install.
// The web portal integration is optional - MUSH-only games do not need it.
//
// Renders the list of inklings and the "New Inkling" form. Selecting a row
// opens inkling-detail-modal (see the sibling inkling-detail-modal.js),
// which owns all detail-view state and every mutating action (reply, tag,
// roll, approve, share, close, delete...). This component only tracks
// which inkling is selected and reconciles its own list when the modal
// reports a change via onUpdate/onDelete - it never renders detail content
// itself.

import Component from '@ember/component';
import { A } from '@ember/array';
import { inject as service } from '@ember/service';

export default Component.extend({
  gameApi: service(),
  flashMessages: service(),

  // --- Required arguments (pass these in when invoking the component) ---
  characterId: null,
  viewerId: null,
  isStaff: false,
  isApproved: false,
  isSelf: false,
  // Array of { kind, name, color } this viewer may create, e.g.
  // typeInfo=this.char.custom.inkling_types - see
  // custom-install/custom_char_fields.snippet.rb. Supplied by the
  // character payload's get_fields_for_viewing hook rather than
  // fetched here, since it's small, viewer-scoped reference data
  // needed before the player has done anything (as soon as they open
  // the "New Inkling" form) - the same pattern other Ares plugins use
  // for profile-tab reference data (e.g. RPG's char.rpg.sheet,
  // Marque's char.custom.house_list).
  typeInfo: null,

  // --- Internal state ---
  inklings: null,
  // In-progress chargen draft(s) (secret/goal text saved before the
  // character is approved - see Inklings.chargen_drafts). Only ever
  // populated for an unapproved character, which in practice means only
  // staff viewing that character's tab receive anything here - see the
  // comment on InklingApi.get_inklings. Rendered as a visually distinct
  // "not yet approved" section, never as ordinary inklings-list rows.
  chargenDrafts: null,
  loading: true,
  statusFilter: 'open',

  showNewForm: false,
  newKind: '',
  newTitle: '',
  newText: '',

  selectedInklingId: null,

  init() {
    this._super(...arguments);
    this.set('inklings', A());
    this.set('chargenDrafts', A());
    this.set('canCreateInkling', false);
  },

  didReceiveAttrs() {
    this._super(...arguments);
    // Permission check: staff can always create, others only if viewing
    // their own approved profile. Called here after arguments are bound.
    this.set('canCreateInkling', this.isStaff || (this.isSelf && this.isApproved));
  },

  didInsertElement() {
    this._super(...arguments);
    this.loadInklings();
  },

  loadInklings() {
    this.set('loading', true);
    // requestOne, not requestMany - inklings_get_inklings returns a
    // composite hash ({ inklings: [...] }), and requestOne is the
    // Ares convention for that (requestMany expects the raw JSON
    // response to already be the array).
    return this.gameApi.requestOne('inklings_get_inklings', {
      char_id: this.characterId,
      status: this.statusFilter
    }, null)
      .then((response) => {
        if (response.error) {
          return;
        }
        this.set('inklings', A(response.inklings || []));
        this.set('chargenDrafts', A(response.chargen_drafts || []));
      })
      .finally(() => {
        this.set('loading', false);
      });
  },

  actions: {
    setStatusFilter(filter) {
      this.set('statusFilter', filter);
      this.loadInklings();
    },

    toggleNewForm() {
      this.toggleProperty('showNewForm');
    },

    setNewKind(kind) {
      this.set('newKind', kind);
    },

    createInkling() {
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

      this.gameApi.requestOne('inklings_create_inkling', {
        char_id: this.characterId,
        kind: this.newKind,
        title: this.newTitle,
        text: this.newText
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.inklings.unshiftObject(response.inkling);
        this.setProperties({
          newKind: '',
          newTitle: '',
          newText: '',
          showNewForm: false
        });
      });
    },

    // Only selectedInklingId is set here - inkling-detail-modal decides
    // when to actually open (after it has fetched detail) via its own
    // internal state, so the modal's opening animation never fires in the
    // same tick as our own data fetch. See inkling-detail-modal.js.
    openDetail(id) {
      this.set('selectedInklingId', id);
    },

    closeDetail() {
      this.set('selectedInklingId', null);
    },

    // Called by inkling-detail-modal whenever it fetches or mutates the
    // selected inkling, so the list row (badges, status, message count)
    // stays in sync without the list ever touching detail fields itself.
    inklingUpdated(updated) {
      let list = this.inklings;
      let idx = list.findIndex((i) => i.id === updated.id);
      if (idx > -1) {
        list.removeAt(idx);
        list.insertAt(idx, updated);
      }
    },

    inklingDeleted(id) {
      let match = this.inklings.find((i) => i.id === id);
      if (match) {
        this.inklings.removeObject(match);
      }
      this.send('closeDetail');
    }
  }
});
