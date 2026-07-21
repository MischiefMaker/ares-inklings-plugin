// Search box for inklings by tag, title, and message text.
// Automatically installed to ares-webportal/app/components/ via
// plugin/install. Shared by both the profile Inklings tab
// (inklings-tab.hbs) and the Admin Inklings page (admin-inklings.hbs) -
// each passes its own onSelect closure action since they need different
// data to open a result (see the onSelect doc below and each caller's
// openDetail/openSearchResult action).
//
// Classic Component.extend(), matching every other component in this
// plugin (inkling-create-form.js, inklings-tab.js, inkling-detail-modal.js)
// rather than @glimmer/component - this plugin is installed by raw file
// copy into a game's ares-webportal with no dependency negotiation, so it
// sticks to the one component style already verified to work there.

import Component from '@ember/component';
import { inject as service } from '@ember/service';
import { debounce } from '@ember/runloop';

// How long to wait after the last keystroke before firing a live search -
// the search itself scores every viewable inkling's tags/title/messages
// server-side (there's no cheap indexed lookup to fall back to), so firing
// on every keystroke would mean one full-dataset scoring pass per letter
// typed. The Search button/Enter still fire immediately, bypassing this.
const LIVE_SEARCH_DEBOUNCE_MS = 400;

export default Component.extend({
  gameApi: service(),

  // --- Required arguments ---
  // onSelect(inkling) - called with the full inkling summary object (id,
  // character_id, title, etc.) when a result row is clicked. The caller
  // decides what shape it needs from that object.
  onSelect: null,

  // --- Internal state ---
  query: '',
  searching: false,
  showResults: false,
  results: null,
  page: 1,
  totalPages: 0,
  totalCount: 0,

  init() {
    this._super(...arguments);
    this.set('results', []);
  },

  // Does the actual fetch for whatever this.page/this.query already are -
  // callers are responsible for setting page first (search() and
  // queryChanged() reset it to 1 for a new query; nextPage/previousPage
  // leave it alone).
  performSearch() {
    if (!this.query || !this.query.trim()) {
      this.set('results', []);
      this.set('showResults', false);
      return;
    }

    this.set('searching', true);
    this.gameApi.requestOne('inklings_search', {
      query: this.query,
      page: this.page || 1
    }, 'home')
      .then((response) => {
        if (response.error) {
          return;
        }
        this.set('results', response.inklings || []);
        this.set('page', response.page || 1);
        this.set('totalPages', response.total_pages || 0);
        this.set('totalCount', response.total_count || 0);
        this.set('showResults', true);
      })
      .finally(() => {
        this.set('searching', false);
      });
  },

  actions: {
    // Search button / Enter key - fires immediately, always page 1 (a new
    // explicit search shouldn't silently reuse whatever page a previous
    // query had scrolled to).
    search(e) {
      e?.preventDefault();
      this.set('page', 1);
      this.performSearch();
    },

    // Live-as-you-type - debounced, also resets to page 1 per keystroke
    // burst since it's searching for new text.
    queryChanged() {
      this.set('page', 1);
      debounce(this, this.performSearch, LIVE_SEARCH_DEBOUNCE_MS);
    },

    clearSearch() {
      this.set('query', '');
      this.set('results', []);
      this.set('showResults', false);
      this.set('page', 1);
    },

    openResult(inkling) {
      if (this.onSelect) {
        this.onSelect(inkling);
      }
    },

    nextPage() {
      if (this.page < this.totalPages) {
        this.set('page', this.page + 1);
        this.performSearch();
      }
    },

    previousPage() {
      if (this.page > 1) {
        this.set('page', this.page - 1);
        this.performSearch();
      }
    }
  }
});
