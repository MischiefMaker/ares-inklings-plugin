// CHARGEN CUSTOM JS SNIPPET - REFERENCE GUIDE
//
// FILE: ares-webportal/app/components/chargen-custom.js
// NOTE: This is a REFERENCE showing what THIS PLUGIN needs. You will MERGE these
//       lines into your game's existing chargen-custom.js alongside other plugins' fields.
//       DO NOT copy this whole file or replace your chargen-custom.js with it.
//
// INSTRUCTIONS:
// 1. Open your game's ares-webportal/app/components/chargen-custom.js
// 2. Find the method that returns custom field data (usually getCustomFieldData())
// 3. Add these four lines to the returned hash, after any other plugins' fields:
//
//    inkling_secret_title: this.char.custom.inkling_secret_title,
//    inkling_secret_text: this.char.custom.inkling_secret_text,
//    inkling_goal_title: this.char.custom.inkling_goal_title,
//    inkling_goal_text: this.char.custom.inkling_goal_text
//
// EXAMPLE: Your getCustomFieldData() method should look something like:
//
//   getCustomFieldData() {
//     return {
//       // Fields from other plugins already here...
//       inkling_secret_title: this.char.custom.inkling_secret_title,
//       inkling_secret_text: this.char.custom.inkling_secret_text,
//       inkling_goal_title: this.char.custom.inkling_goal_title,
//       inkling_goal_text: this.char.custom.inkling_goal_text
//     };
//   }
//
// These four keys MUST match exactly what custom_char_fields.snippet.rb expects.
