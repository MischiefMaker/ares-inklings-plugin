// CHARGEN CUSTOM JS SNIPPET
//
// Adds the Secret and Goal field values to the chargen submission data.
//
// FILE: ares-webportal/app/components/chargen-custom.js
//
// STEP 1: Locate the file
// 1. Open your game's ares-webportal/app/components/chargen-custom.js
//
// STEP 2: Find the onUpdate method
// 2. Find the method: onUpdate() { ... }
// 3. Inside that method, look for the "return {" line with field data
//
// STEP 3: Copy and paste
// 4. Copy the 4 lines below (between the markers)
// 5. Paste them inside the return { } block, after any other fields
// 6. Save the file
//
// EXAMPLE OF WHAT YOU'RE LOOKING FOR:
// Your onUpdate() method probably looks something like:
//
//   onUpdate() {
//     return {
//       // Other custom fields go here
//     };
//   }
//
// After pasting, it will look like:
//
//   onUpdate() {
//     return {
//       // Other custom fields go here
//       inkling_secret_title: this.get('char.custom.inkling_secret_title'),
//       inkling_secret_text: this.get('char.custom.inkling_secret_text'),
//       inkling_goal_title: this.get('char.custom.inkling_goal_title'),
//       inkling_goal_text: this.get('char.custom.inkling_goal_text'),
//     };
//   }
//
// PASTE THESE 4 LINES INSIDE THE RETURN BLOCK:

// ---START COPY HERE---
      inkling_secret_title: this.get('char.custom.inkling_secret_title'),
      inkling_secret_text: this.get('char.custom.inkling_secret_text'),
      inkling_goal_title: this.get('char.custom.inkling_goal_title'),
      inkling_goal_text: this.get('char.custom.inkling_goal_text'),
// ---END COPY---
//
// IMPORTANT:
// - These field names MUST match the field names in chargen-custom.snippet.hbs
// - Do NOT change the "this.get('char.custom.inkling_*')" part
// - Add a comma at the end of each line if other fields come after
//
// IF YOU CUSTOMIZED chargen_required_types:
// If your game uses different inkling types (e.g., chargen_required_types: [hooks]),
// rename these accordingly. Example for "hooks" instead of "secret" and "goal":
//
//   inkling_hooks_title: this.get('char.custom.inkling_hooks_title'),
//   inkling_hooks_text: this.get('char.custom.inkling_hooks_text'),
//
// The pattern is: inkling_{type}_title and inkling_{type}_text
