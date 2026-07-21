// CUSTOM ROUTES SNIPPET - ADMIN INKLINGS PAGE
//
// FILE: app/custom-routes.js
//       (in your game's ares-webportal checkout, NOT the plugin folder)
//
// NOTE: This is a SHARED GAME FILE. It already exists in a standard
// ares-webportal install and may already have other plugins' routes in
// it. ADD the line below inside the exported function - do not replace
// the whole file.
//
// ===========================================================================
// INSTALLATION
// ===========================================================================
//
// 1. Open app/custom-routes.js in your ares-webportal checkout
// 2. Find the exported setup function (it takes a `router` argument)
// 3. Add this line inside it (see example below):
//
// 4. Rebuild/restart the web portal for the route to take effect
//
// ===========================================================================
// EXAMPLE
// ===========================================================================
//
// export default function setupCustomRoutes(router) {

router.route('admin-inklings');

//   // Other plugins' custom routes may already be listed here
// }
