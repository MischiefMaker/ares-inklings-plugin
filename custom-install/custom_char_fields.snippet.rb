# CUSTOM CHARACTER FIELDS SNIPPET - CHARGEN-REQUIRED INKLING DRAFT FIELDS
#
# FILE: aresmush/plugins/profile/custom_char_fields.rb  (in the aresmush
#       folder, NOT ares-webportal, and NOT the inklings plugin folder)
#
# NOTE: This is a SHARED HOOK FILE. On a stock Ares install every method
#       below is present but returns {} or []. You are REPLACING the bodies
#       of five methods with the versions below. If other plugins already
#       added code to these methods, MERGE - keep their lines and add yours.
#
# ---------------------------------------------------------------------------
# HOW IT WORKS (read this - it's why earlier versions silently failed)
# ---------------------------------------------------------------------------
# 1. The custom fields must be DECLARED on the Character model first. That is
#    done by the Inklings plugin itself in:
#        aresmush/plugins/inklings/models/character_inkling_fields.rb
#    which declares:  attribute :inkling_secret_title  (etc).
#    Without those declarations, char.inkling_secret_title raises
#    "undefined method". This snippet ASSUMES that plugin file is installed.
#    (It ships with the plugin - no action needed beyond installing the plugin.)
#
# 2. On SAVE, Ares hands your custom fields to you inside a hash under the
#    'custom' key - chargen_data['custom']['inkling_secret_title'] - NOT as
#    keyword args. Reading the wrong place is why saving appeared to do
#    nothing. Store them with char.update(...).
#
# 3. On READ, format text for the context: format_input_for_html for the
#    chargen/edit forms, format_markdown_for_html for read-only viewing.
#
# 4. These fields hold DRAFT text only. On character approval the Inklings
#    plugin (Inklings.character_approved) converts each populated draft into
#    a real Inkling and clears the draft field.
#
# CONFIGURATION:
# If you change chargen_required_types in game/config/inklings.yml you MUST
# also, for each new kind:
#   - add an attribute pair in character_inkling_fields.rb
#     (attribute :inkling_<kind>_title / :inkling_<kind>_text)
#   - add the form fields in chargen-custom.snippet.hbs
#   - add the field names in chargen-custom.snippet.js
# The loops below then pick the new kind up automatically.
#
# ===========================================================================
# INSTALLATION STEPS
# ===========================================================================
#
# STEP 1: Copy the five method bodies below into your aresmush
# plugins/profile/custom_char_fields.rb file. Find the marked sections and
# paste the corresponding method bodies - replace what's there with what's
# below.
#
# STEP 2: If you want the Inklings tab to show on character profiles (strongly
# recommended), the type-picker data MUST be included in get_fields_for_viewing.
# The code below already includes it: the line `fields[:inkling_types] = ...`
# passes the list of types the viewer may create to the web portal component,
# so the "New Inkling" dropdown populates correctly. If your game has customized
# get_fields_for_viewing elsewhere, make sure this line is preserved.
#
# ===========================================================================
# Replace the five methods so they read:
# ===========================================================================
#
# NOTE ON THE `char.respond_to?` GUARDS:
# Each configured kind needs a matching `attribute :inkling_<kind>_title/_text`
# declaration on the Character model (see the inklings plugin's
# models/character_inkling_fields.rb). If chargen_required_types ever lists a
# kind with no such declaration, char.send(...) would raise "undefined method"
# and take down the ENTIRE profile/chargen page. The guard degrades that to
# "this one field is skipped" instead, so a config/declaration drift can't
# 500 the page. When everything is in sync (the normal case) the guard is a
# no-op.

      # --- chargen form: repopulate on return to chargen ---
      def self.get_fields_for_chargen(char)
        fields = {}
        Inklings.chargen_required_types.each do |kind|
          next unless char.respond_to?("inkling_#{kind}_title")
          fields["inkling_#{kind}_title".to_sym] = Website.format_input_for_html(char.send("inkling_#{kind}_title"))
          fields["inkling_#{kind}_text".to_sym]  = Website.format_input_for_html(char.send("inkling_#{kind}_text"))
        end
        fields
      end

      # --- read-only profile view ---
      def self.get_fields_for_viewing(char, viewer)
        fields = {}
        Inklings.chargen_required_types.each do |kind|
          next unless char.respond_to?("inkling_#{kind}_title")
          fields["inkling_#{kind}_title".to_sym] = Website.format_markdown_for_html(char.send("inkling_#{kind}_title"))
          fields["inkling_#{kind}_text".to_sym]  = Website.format_markdown_for_html(char.send("inkling_#{kind}_text"))
        end
        # Type list for the Inklings tab's "New Inkling" picker - filtered to
        # what this viewer may create. Passed to the web portal component as
        # typeInfo so it can populate the dropdown without a separate request.
        fields[:inkling_types] = Inklings::InklingApi.creatable_type_options(viewer)
        # Staff override flag for the Inklings tab's "Add Inkling" button -
        # computed server-side via the plugin's own permission check rather
        # than trusting an assumed web-portal viewer property (there is no
        # standard "isStaff" field on the Ares viewer payload). Passed to the
        # web portal component as isStaff.
        fields[:can_manage_inklings] = Inklings.can_manage_inklings?(viewer)
        fields
      end

      # --- profile editor form ---
      def self.get_fields_for_editing(char, viewer)
        fields = {}
        Inklings.chargen_required_types.each do |kind|
          next unless char.respond_to?("inkling_#{kind}_title")
          fields["inkling_#{kind}_title".to_sym] = Website.format_input_for_html(char.send("inkling_#{kind}_title"))
          fields["inkling_#{kind}_text".to_sym]  = Website.format_input_for_html(char.send("inkling_#{kind}_text"))
        end
        fields
      end

      # --- save from chargen ---
      def self.save_fields_from_chargen(char, chargen_data)
        data = chargen_data['custom'] || {}
        Inklings.chargen_required_types.each do |kind|
          next unless char.respond_to?("inkling_#{kind}_title=")
          char.update("inkling_#{kind}_title".to_sym => Website.format_input_for_mush(data["inkling_#{kind}_title"].to_s))
          char.update("inkling_#{kind}_text".to_sym  => Website.format_input_for_mush(data["inkling_#{kind}_text"].to_s))
        end
        []
      end

      # --- save from profile edit (use ...edit2, NOT the deprecated edit) ---
      def self.save_fields_from_profile_edit2(char, enactor, char_data)
        data = char_data['custom'] || {}
        Inklings.chargen_required_types.each do |kind|
          next unless char.respond_to?("inkling_#{kind}_title=")
          char.update("inkling_#{kind}_title".to_sym => Website.format_input_for_mush(data["inkling_#{kind}_title"].to_s))
          char.update("inkling_#{kind}_text".to_sym  => Website.format_input_for_mush(data["inkling_#{kind}_text"].to_s))
        end
        []
      end

# ===========================================================================
# DONE!
# ===========================================================================
# After editing this file, restart the game. A full restart is the reliable
# way to pick up changes to the profile plugin AND the new Character model
# attribute declaration in the inklings plugin.
