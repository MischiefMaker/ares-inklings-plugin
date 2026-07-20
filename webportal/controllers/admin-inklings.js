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
// model is { listing: <paginated inklings_list_all response>,
// characters: <core "characters" response> } (see the route) - listing
// gets replaced wholesale on reload()/pagination, characters is fetched
// once and stays put for the lifetime of the page.
//
// Add Inkling is the shared inkling-create-form component (mode="admin"
// here, mode="profile" on the profile tab - see
// webportal/components/inkling-create-form.js), not a form owned by
// this controller - this controller only reacts to its onCreated
// closure action.

import Controller from '@ember/controller';
import { inject as service } from '@ember/service';
import { A } from '@ember/array';

export default Controller.extend({
  gameApi: service(),

  statusFilter: 'open',
  page: 1,

  showNewForm: false,

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
      this.set('model.listing', response);
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

    // Called by inkling-create-form (mode="admin") once it has
    // successfully created the inkling. A full reload (rather than
    // unshifting locally, the way the profile tab's inklingCreated
    // does) is simplest here since the new inkling may not even belong
    // on the current page/filter (it could be for any character, and
    // this list is server-paginated).
    inklingCreated() {
      this.set('showNewForm', false);
      this.reload(1);
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
      let list = A(this.model.listing.inklings);
      let idx = list.findIndex((i) => i.id === updated.id);
      if (idx > -1) {
        list.removeAt(idx);
        list.insertAt(idx, updated);
      }
    },

    inklingDeleted() {
      this.reload(this.page);
      this.send('closeDetail');
    }
  }
});
