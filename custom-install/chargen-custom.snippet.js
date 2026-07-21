// CHARGEN CUSTOM JS SNIPPET
//
// Inklings chargen component integration
//
// FILE: ares-webportal/app/components/chargen-custom.js
//
// INSTRUCTIONS:
// 1. Open ares-webportal/app/components/chargen-custom.js
// 2. Find the onUpdate() method
// 3. Locate the "return {" line with field data
// 4. Copy and paste these 4 lines into the return { } block:

    inkling_secret_title: this.get('char.custom.inkling_secret_title'),
    inkling_secret_text: this.get('char.custom.inkling_secret_text'),
    inkling_goal_title: this.get('char.custom.inkling_goal_title'),
    inkling_goal_text: this.get('char.custom.inkling_goal_text'),

// 5. Save the file
// 6. Restart the web portal with: website/deploy
