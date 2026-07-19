import Component from '@ember/component';

// Chargen extension component for inkling required types (secret, goal, etc.)
// Auto-installed by plugin/install and wired up via custom_char_fields.rb
//
// This component renders form fields for chargen-required inkling types during
// character generation. The form fields are bound to char.custom.inkling_* values
// populated by get_fields_for_chargen in the backend's custom_char_fields.rb hook.
//
// The onUpdate() callback is invoked by the chargen framework when this step is
// completed. It collects the form field values and returns them as an object.
// The chargen framework passes these values to save_fields_from_chargen in the
// backend to save the inkling data.
//
// Template: webportal/templates/components/chargen-custom.hbs
// Backend: custom_char_fields.rb (in game's aresmush/plugins/profile/)

export default Component.extend({
  tagName: '',

  // These are passed in when the component is invoked by the chargen framework
  char: null,

  // onUpdate is the chargen extension callback invoked by the chargen framework
  // after the user completes this step. We return an object with all inkling_*
  // field values from char.custom. The chargen framework passes these to
  // save_fields_from_chargen() in the backend.
  onUpdate() {
    let fields = {};

    // Dynamically collect all inkling_* fields from char.custom.
    // This makes the component work with any chargen_required_types config
    // without needing user customization - just define the types in config
    // and this component will pick them up automatically.
    if (this.char && this.char.custom) {
      Object.keys(this.char.custom).forEach((key) => {
        if (key.startsWith('inkling_')) {
          fields[key] = this.char.custom[key];
        }
      });
    }

    return fields;
  }
});
