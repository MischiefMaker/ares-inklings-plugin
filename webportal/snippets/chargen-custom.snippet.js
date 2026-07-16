// MERGE-IN SNIPPET - not a complete file, and not meant to be
// included/imported as-is.
//
// chargen-custom.js (ares-webportal/app/components/) collects data
// from every plugin's custom chargen fields and sends it back to the
// game as one combined hash when the player submits chargen. The
// exact shape of that collection point differs a bit by AresMUSH
// version, so treat this as a reference for what THIS plugin's
// contribution should look like - merge it into however your game's
// chargen-custom.js already gathers data from this.char.custom
// (alongside any other plugins' fields), rather than replacing the
// whole file.
//
// This plugin's four chargen fields (see chargen-custom.snippet.hbs)
// need to end up in the hash sent to the server, e.g. inside
// whatever existing method already builds that combined hash:
//
//   getCustomFieldData() {
//     return {
//       // ...other plugins' fields already here...
//       inkling_secret_title: this.char.custom.inkling_secret_title,
//       inkling_secret_text: this.char.custom.inkling_secret_text,
//       inkling_goal_title: this.char.custom.inkling_goal_title,
//       inkling_goal_text: this.char.custom.inkling_goal_text
//     };
//   }
//
// Those four keys are exactly what
// plugin/public/custom_char_fields_snippet.rb's
// save_fields_from_chargen expects to find on the args hash it
// receives.
