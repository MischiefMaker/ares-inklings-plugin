// Admin "every inkling in the game" page controller.
// Automatically installed to ares-webportal/app/controllers/ via
// plugin/install. Pairs with webportal/routes/admin-inklings.js and
// webportal/templates/admin-inklings.hbs.
//
// Reuses inkling-detail-modal as-is for row click-through (see
// webportal/components/inkling-detail-modal.js) - that component only
// needs an inklingId + the inkling's OWN characterId, not a page-wide
// "current profile" the way inklings-tab.js has one, so each row passes
// its own character_id when opened (see openDetail below) rather than
// this controller tracking a single fixed characterId the way the
// profile tab does.
//
// Add Inkling reuses InklingApi.create_inkling/share_inkling entirely
// (via the create_inkling_by_name endpoint - see
// plugin/public/inklings_api.rb) rather than a second creation path;
// the only new surface is the owner/shared-with name fields this page
// needs that the profile tab's form doesn't (it already knows its own
// characterId). See the audit note in ARES_PLUGIN_DEVELOPMENT_GUIDE.md
// (§4) on why this ships as this page's own form block instead of a
// factored-out shared component: no confirmed reusable Ares character-
// selector component was found, so both this page and the profile tab
// already use the same plain free-text name pattern independently
// (this page's owner/sharedWith fields, the profile tab's shareTarget) -
// extracting a shared component was judged higher-risk to already-
// working code than the win justified for this pass.

import Controller from '@ember/controller';
import { inject as service } from '@ember/service';
import { A } from '@ember/array';

export default Controller.extend({
  gameApi: service(),
  flashMessages: service(),

  statusFilter: 'open',
  page: 1,

  showNewForm: false,
  newKind: '',
  newTitle: '',
  newText: '',
  newOwnerName: '',
  newSharedWith: '',

  selectedInklingId: null,
  selectedCharacterId: null,

  reload(page = 1) {
    return this.gameApi.requestOne('inklings_list_all', {
      status: this.statusFilter,
      page
    }, null).then((response) => {
      if (response.error) {
        return;
      }
      this.set('model', response);
      this.set('page', response.page);
    });
  },

  actions: {
    setStatusFilter(filter) {
      this.set('statusFilter', filter);
      this.reload(1);
    },

    // Plain actions rather than a template-level "add"/"sub" helper -
    // ember-truth-helpers (bundled here) only provides eq/and/or/not, and
    // no arithmetic helper was confirmed to exist, so the arithmetic
    // lives here instead of assuming one.
    previousPage() {
      this.reload(this.page - 1);
    },

    nextPage() {
      this.reload(this.page + 1);
    },

    toggleNewForm() {
      this.toggleProperty('showNewForm');
    },

    setNewKind(kind) {
      this.set('newKind', kind);
    },

    createInkling() {
      if (!this.newOwnerName || !this.newOwnerName.trim()) {
        this.flashMessages.danger('Please enter an owner character name');
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

      this.gameApi.requestOne('inklings_create_inkling_by_name', {
        owner_name: this.newOwnerName,
        kind: this.newKind,
        title: this.newTitle,
        text: this.newText,
        shared_with: this.newSharedWith
      }, null).then((response) => {
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
          newOwnerName: '',
          newSharedWith: '',
          showNewForm: false
        });
        this.reload(1);
      });
    },

    // Unlike inklings-tab.js (one fixed characterId for the whole tab),
    // each admin-list row can belong to a different character - the
    // modal needs THIS row's owner id, not a page-wide one.
    openDetail(inkling) {
      this.set('selectedCharacterId', inkling.character_id);
      this.set('selectedInklingId', inkling.id);
    },

    closeDetail() {
      this.set('selectedInklingId', null);
      this.set('selectedCharacterId', null);
    },

    inklingUpdated(updated) {
      let list = A(this.model.inklings);
      let idx = list.findIndex((i) => i.id === updated.id);
      if (idx > -1) {
        list.removeAt(idx);
        list.insertAt(idx, updated);
      }
    },

    inklingDeleted(id) {
      this.reload(this.page);
      this.send('closeDetail');
    }
  }
});
