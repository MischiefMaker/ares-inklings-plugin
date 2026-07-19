// CHARGEN CUSTOM JS SNIPPET
//
// Inklings chargen component integration
//
// FILE: ares-webportal/app/components/chargen-custom.js
//
// INSTRUCTIONS:
// 1. Check if your game has ares-webportal/app/components/chargen-custom.js
//    - If it EXISTS and has an onUpdate() method: use OPTION A (paste into existing)
//    - If it DOES NOT EXIST: use OPTION B (create new file from template below)
//
// ==============================================================
// OPTION A: FILE EXISTS - paste into existing onUpdate() method
// ==============================================================
//
// 1. Open ares-webportal/app/components/chargen-custom.js
// 2. Find the onUpdate() method
// 3. Locate the "return {" line with field data
// 4. Copy and paste ONLY these 4 lines into the return { } block:
//
    inkling_secret_title: this.get('char.custom.inkling_secret_title'),
    inkling_secret_text: this.get('char.custom.inkling_secret_text'),
    inkling_goal_title: this.get('char.custom.inkling_goal_title'),
    inkling_goal_text: this.get('char.custom.inkling_goal_text'),
//
// 5. Save the file
//
// ==============================================================
// OPTION B: FILE DOES NOT EXIST - create new file
// ==============================================================
//
// 1. Create a new file: ares-webportal/app/components/chargen-custom.js
// 2. Copy the ENTIRE code block below (between ---START and ---END):
// 3. Save the file
// 4. Restart the web portal with: website/deploy
//
// Note: If you already have an onUpdate() method in this file (from another
// plugin or custom code), use OPTION A instead to merge the Inklings fields.

// ---START COPY HERE (for OPTION B only) ---
import Component from '@ember/component';

export default Component.extend({
  onUpdate() {
    return {
      // Inklings chargen-required fields
      inkling_secret_title: this.get('char.custom.inkling_secret_title'),
      inkling_secret_text: this.get('char.custom.inkling_secret_text'),
      inkling_goal_title: this.get('char.custom.inkling_goal_title'),
      inkling_goal_text: this.get('char.custom.inkling_goal_text'),
    };
  }
});
// ---END COPY---
//
// IF YOU CUSTOMIZED chargen_required_types:
// If your game uses different types (e.g., [hooks] instead of [secret, goal]),
// update the fields accordingly. The pattern is: inkling_{type}_title and inkling_{type}_text
//
// Example for [hooks]:
//   inkling_hooks_title: this.get('char.custom.inkling_hooks_title'),
//   inkling_hooks_text: this.get('char.custom.inkling_hooks_text'),
