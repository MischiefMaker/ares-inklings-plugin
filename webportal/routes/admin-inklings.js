// Admin "every inkling in the game" page route.
// Automatically installed to ares-webportal/app/routes/ via plugin/install,
// mirroring the same 1:1 directory-copy convention already used for
// webportal/components/*.js -> app/components/*.js. Requires a matching
// route registration in the game's app/custom-routes.js (see
// custom-install/custom-routes.snippet.js) and, to appear in the Admin
// dropdown, a top_navbar entry in game/config/website.yml (see
// custom-install/website_top_navbar.snippet.yml) - see the Jobs route
// (app/routes/jobs.js in ares-webportal) for the equivalent core-plugin
// pattern this follows: a model hook that fetches page 1 and hands the
// full response straight to the controller, which owns pagination from
// there (see previousPage/nextPage/setStatusFilter in
// webportal/controllers/admin-inklings.js, all funneling through one
// reload() that re-requests and replaces the model).
//
// Server-side authorization (manage_inklings, via
// InklingApi.list_all_inklings) is the actual gate - this route doesn't
// duplicate that check client-side. An unauthorized viewer still gets
// { error: ... } back from the API, which GameApi's requestOne already
// flashes automatically (see ARES_PLUGIN_DEVELOPMENT_GUIDE.md's note on
// this - don't add a second flashMessages call on top of it).
//
// characters is fetched here (not by inkling-create-form itself) via
// the same core "characters" web request Jobs' job-edit.js model() hook
// uses for its own Submitter/Assigned To/Other Participants dropdowns
// (select: "all" - every character, not just approved ones, matching
// this endpoint's own default when no filter is requested). No
// Inklings-specific character-list endpoint exists or is needed.

import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';
import RSVP from 'rsvp';

export default Route.extend({
  gameApi: service(),

  model() {
    return RSVP.hash({
      listing: this.gameApi.requestOne('inklings_list_all', { status: 'open', page: 1 }, 'home'),
      characters: this.gameApi.requestMany('characters', { select: 'all' })
    });
  }
});
