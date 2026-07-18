# CUSTOM CHARACTER FIELDS SNIPPET - CHARGEN-REQUIRED TYPES + TYPE PICKER DATA
#
# FILE: ares/plugins/profile/custom_char_fields.rb (in the ares folder, not ares-webportal)
# NOTE: This is a SHARED HOOK FILE used by multiple plugins.
#       You will ADD CODE to existing methods, not replace the whole file.
#
# PURPOSE:
# This snippet integrates two things via the standard Ares custom-character-fields
# hooks (https://aresmush.com/tutorials/code/hooks/char-fields.html):
# 1. The CHARGEN-REQUIRED inkling types (as defined in game/config/inklings.yml
#    chargen_required_types) as editable custom character fields on the profile page.
# 2. The inkling TYPE LIST used by the {{inklings-tab}} component's "New Inkling"
#    type picker (char.custom.inkling_types) - embedded on the character payload
#    the profile page already loads, so the web portal component never needs a
#    separate request just to populate a dropdown. This is the same pattern other
#    Ares plugins use for profile-tab reference data (e.g. the RPG plugin's
#    char.rpg.sheet), rather than the component fetching it itself.
#
# IMPORTANT - TWO SEPARATE INTEGRATIONS:
# 1. THIS SNIPPET (custom_char_fields) - Chargen-required fields, AND the type
#    list the inklings-tab component's "New Inkling" picker depends on.
#    Skipping this snippet means the "New Inkling" type dropdown will be empty.
# 2. PROFILE-CUSTOM.SNIPPET.HBS (inklings-tab) - Shows ALL inklings for the character
#    Players see the full Inklings browser here (all types, all features)
#
# Do not confuse these - they serve different purposes:
# - custom_char_fields: Chargen-required fields + inklings-tab's type-picker data
# - inklings-tab: Full inkling management interface (shows all inklings)
#
# CONFIGURATION:
# If you change chargen_required_types in game/config/inklings.yml, you MUST also update:
# - chargen-custom.snippet.hbs (the form fields)
# - chargen-custom.snippet.js (the field names sent to server)
# This snippet will automatically handle any configured types.
#
# This snippet has 6 steps. Follow them in order. Each step is a separate copy-paste.
#
# IF YOU ALREADY INSTALLED AN EARLIER VERSION OF THIS SNIPPET:
# Steps 2 and 3 below use "**build_inkling_fields(...)" (double splat, needed to
# merge a Hash's keys into a surrounding hash literal). An earlier version of this
# snippet used a single "*" there, which is invalid Ruby in that position and would
# raise an error on every profile page load. If your live custom_char_fields.rb has
# a single "*" on those lines, change it to "**".

# ============================================================================
# STEP 1: Add fields to get_fields_for_chargen
# ============================================================================
#
# FILE: ares/plugins/profile/custom_char_fields.rb
# METHOD: def self.get_fields_for_chargen(char)
#
# This displays the chargen-required inkling types as editable fields during chargen.
#
# 1. Find the method "def self.get_fields_for_chargen(char)"
# 2. Find the line with "return {" or the opening "{"
# 3. Find the closing "}" of that hash
# 4. Copy and paste these lines BEFORE the closing "}":
#
# ---START COPY HERE---
        # Chargen-required inklings (displayed as custom fields)
        **build_inkling_fields(char, char, for_editing: true)
# ---END COPY---

# ============================================================================
# STEP 2: Add fields to get_fields_for_viewing
# ============================================================================
#
# FILE: ares/plugins/profile/custom_char_fields.rb
# METHOD: def self.get_fields_for_viewing(char, viewer)
#
# This displays the chargen-required inkling types as read-only fields on the
# profile, AND embeds the inkling type list the {{inklings-tab}} component's
# "New Inkling" picker needs (char.custom.inkling_types) - already filtered to
# what this viewer may create (get_fields_for_viewing receives viewer for
# exactly this kind of permission-aware field).
#
# 1. Find the method "def self.get_fields_for_viewing(char, viewer)"
# 2. Find the line with "return {" or the opening "{"
# 3. Find the closing "}" of that hash
# 4. Copy and paste these lines BEFORE the closing "}":
#
# ---START COPY HERE---
        # Chargen-required inklings (displayed as custom fields)
        **build_inkling_fields(char, viewer, for_editing: false),
        # Type list for the inklings-tab component's "New Inkling" picker
        inkling_types: Inklings::InklingApi.creatable_type_options(viewer)
# ---END COPY---

# ============================================================================
# STEP 3: Add fields to get_fields_for_editing
# ============================================================================
#
# FILE: ares/plugins/profile/custom_char_fields.rb
# METHOD: def self.get_fields_for_editing(char, viewer)
#
# This displays the chargen-required inkling types as editable fields on the profile.
#
# 1. Find the method "def self.get_fields_for_editing(char, viewer)"
# 2. Find the line with "return {" or the opening "{"
# 3. Find the closing "}" of that hash
# 4. Copy and paste these lines BEFORE the closing "}":
#
# ---START COPY HERE---
        # Chargen-required inklings (displayed as custom fields)
        **build_inkling_fields(char, viewer, for_editing: true)
# ---END COPY---

# ============================================================================
# STEP 4: Add code to save profile edits
# ============================================================================
#
# FILE: ares/plugins/profile/custom_char_fields.rb
# METHOD: def self.save_fields_from_profile_edit2(char, viewer, args)
#
# IMPORTANT: Use save_fields_from_profile_edit2, NOT save_fields_from_profile_edit
#            (save_fields_from_profile_edit is deprecated)
#
# 1. Find the method "def self.save_fields_from_profile_edit2(char, viewer, args)"
#    - It should look like: def self.save_fields_from_profile_edit2(char, viewer, args)
#    - NOT: def self.save_fields_from_profile_edit(char, char_data) (that's deprecated)
# 2. Find the line just before the "end" of that method
# 3. Copy and paste these lines BEFORE the "end":
#
# ---START COPY HERE---
      # Save chargen-required inklings from profile edit
      Inklings.chargen_required_types.each do |kind|
        title_key = "inkling_#{kind}_title".to_sym
        text_key = "inkling_#{kind}_text".to_sym
        save_inkling_from_args(char, viewer, kind, args[title_key], args[text_key])
      end
# ---END COPY---

# ============================================================================
# STEP 5: Add code to save chargen data
# ============================================================================
#
# FILE: ares/plugins/profile/custom_char_fields.rb
# METHOD: def self.save_fields_from_chargen(char, args)
#
# 1. Find the method "def self.save_fields_from_chargen(char, args)"
# 2. Find the line just before the "end" of that method
# 3. Copy and paste these lines BEFORE the "end":
#
# ---START COPY HERE---
      # Save chargen-required inklings
      Inklings.chargen_required_types.each do |kind|
        title_key = "inkling_#{kind}_title".to_sym
        text_key = "inkling_#{kind}_text".to_sym
        save_inkling_from_args(char, char, kind, args[title_key], args[text_key])
      end
# ---END COPY---

# ============================================================================
# STEP 6: Add the helper methods
# ============================================================================
#
# FILE: ares/plugins/profile/custom_char_fields.rb
# LOCATION: At the end of the CustomCharFields class (before the final "end")
#
# 1. Go to the end of the CustomCharFields class/module definition
# 2. Find the final "end" that closes it
# 3. Copy and paste these entire methods BEFORE that final "end":
#
# ---START COPY HERE---
    def self.build_inkling_fields(char, viewer, for_editing: false)
      fields = {}
      Inklings.chargen_required_types.each do |kind|
        inkling = Inkling.find(character_id: char.id, kind: kind).first
        title_key = "inkling_#{kind}_title".to_sym
        text_key = "inkling_#{kind}_text".to_sym

        if for_editing
          fields[title_key] = inkling&.title
          fields[text_key] = inkling&.messages&.to_a&.first&.text
        else
          fields[title_key] = inkling&.title
          fields[text_key] = inkling ? Website.format_markdown_for_html(inkling.messages.to_a.first&.text) : nil
        end
      end
      fields
    end

    def self.save_inkling_from_args(char, viewer, kind, title, text)
      return if title.to_s.blank? && text.to_s.blank?

      existing = Inkling.find(character_id: char.id, kind: kind).first
      if existing
        Inklings::InklingApi.reply_to_inkling(char.id, existing.id, viewer.id, text)
      else
        Inklings::InklingApi.create_inkling(char.id, viewer.id, kind, text, title)
      end
    end
# ---END COPY---

# ============================================================================
# DONE!
# ============================================================================
#
# You have successfully integrated chargen-required inkling types into:
# - Character profile viewing (read-only display)
# - Character profile editing (editable fields)
# - Character generation (required chargen fields)
#
# Players can now create and edit their chargen-required inklings (secret, goal, etc.)
# through both the chargen process and their character profile page.
#
# FOR VIEWING ALL INKLINGS:
# Also integrate profile-custom.snippet.hbs which includes the {{inklings-tab}} component.
# This shows the full Inklings browser with all inkling types and all features.
# The {{inklings-tab}} is visible only to the logged-in player and staff on their profile.
