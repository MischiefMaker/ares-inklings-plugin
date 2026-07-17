// CHARGEN CUSTOM JS SNIPPET
//
// Adds the Secret and Goal field values to the chargen submission data.
//
// FILE: ares-webportal/app/components/chargen-custom.js
//
// STEP 1: Locate the file
// 1. Open your game's ares-webportal/app/components/chargen-custom.js
//
// STEP 2: Find the method
// 2. Find the method that builds the chargen data (usually getCustomFieldData() or similar)
// 3. It should return a hash/object with field data
//
// STEP 3: Copy and paste
// 4. Copy the 4 field lines below (between the markers)
// 5. Paste them inside the returned object/hash, after any other plugins' fields
// 6. Save the file
//
// IMPORTANT:
// - These field names MUST match the field names in chargen-custom.snippet.hbs
//   (inkling_secret_title, inkling_secret_text, inkling_goal_title, inkling_goal_text)
// - They MUST also match the names in custom_char_fields.snippet.rb
// - Do NOT change these names

// ---START COPY HERE---
      inkling_secret_title: this.char.custom.inkling_secret_title,
      inkling_secret_text: this.char.custom.inkling_secret_text,
      inkling_goal_title: this.char.custom.inkling_goal_title,
      inkling_goal_text: this.char.custom.inkling_goal_text,
// ---END COPY---
//
// EXAMPLE OF COMPLETE METHOD (yours may look different):
//
//   getCustomFieldData() {
//     return {
//       // Other plugins' fields here...
//       inkling_secret_title: this.char.custom.inkling_secret_title,
//       inkling_secret_text: this.char.custom.inkling_secret_text,
//       inkling_goal_title: this.char.custom.inkling_goal_title,
//       inkling_goal_text: this.char.custom.inkling_goal_text,
//     };
//   }
