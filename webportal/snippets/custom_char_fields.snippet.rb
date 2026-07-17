# CUSTOM CHARACTER FIELDS SNIPPET - BACKEND INTEGRATION
#
# FILE: plugins/profile/custom_char_fields.rb
# NOTE: This is a SHARED HOOK FILE used by multiple plugins.
#       You will ADD CODE to existing methods, not replace the whole file.
#
# This snippet has 5 steps. Follow them in order. Each step is a separate copy-paste.

# ============================================================================
# STEP 1: Import the Inklings API
# ============================================================================
#
# FILE: plugins/profile/custom_char_fields.rb
# LOCATION: At the top of the module, after "module AresMUSH"
#
# 1. Open plugins/profile/custom_char_fields.rb
# 2. Find the line "module AresMUSH"
# 3. After that line, look for "module CustomCharFields"
# 4. Copy and paste this line right after "module CustomCharFields" opening:
#
# ---START COPY HERE---
  module CustomCharFields
    require_relative '../../inklings/public/inklings_api'
# ---END COPY---
#
# (Just add the require_relative line if the module already exists)

# ============================================================================
# STEP 2: Add fields to get_fields_for_viewing
# ============================================================================
#
# FILE: plugins/profile/custom_char_fields.rb
# METHOD: def self.get_fields_for_viewing(char, viewer)
#
# 1. Find the method "def self.get_fields_for_viewing(char, viewer)"
# 2. Find the line with "return {" or "{"
# 3. Find the closing "}" of that hash
# 4. Copy and paste these 4 lines BEFORE the closing "}":
#
# ---START COPY HERE---
        inkling_secret_title: Inkling.find(character_id: char.id, kind: "secret").first&.title,
        inkling_secret_text: Inkling.find(character_id: char.id, kind: "secret").first ? Website.format_markdown_for_html(Inkling.find(character_id: char.id, kind: "secret").first.messages.to_a.first&.text) : nil,
        inkling_goal_title: Inkling.find(character_id: char.id, kind: "goal").first&.title,
        inkling_goal_text: Inkling.find(character_id: char.id, kind: "goal").first ? Website.format_markdown_for_html(Inkling.find(character_id: char.id, kind: "goal").first.messages.to_a.first&.text) : nil,
# ---END COPY---

# ============================================================================
# STEP 3: Add fields to get_fields_for_editing
# ============================================================================
#
# FILE: plugins/profile/custom_char_fields.rb
# METHOD: def self.get_fields_for_editing(char, viewer)
#
# 1. Find the method "def self.get_fields_for_editing(char, viewer)"
# 2. Find the line with "return {" or "{"
# 3. Find the closing "}" of that hash
# 4. Copy and paste these 4 lines BEFORE the closing "}":
#
# ---START COPY HERE---
        inkling_secret_title: Inkling.find(character_id: char.id, kind: "secret").first&.title,
        inkling_secret_text: Inkling.find(character_id: char.id, kind: "secret").first&.messages&.to_a&.first&.text,
        inkling_goal_title: Inkling.find(character_id: char.id, kind: "goal").first&.title,
        inkling_goal_text: Inkling.find(character_id: char.id, kind: "goal").first&.messages&.to_a&.first&.text,
# ---END COPY---

# ============================================================================
# STEP 4: Add code to save profile edits
# ============================================================================
#
# FILE: plugins/profile/custom_char_fields.rb
# METHOD: def self.save_fields_from_profile_edit (or save_fields_from_profile_edit2)
#
# 1. Find the method "def self.save_fields_from_profile_edit" or "save_fields_from_profile_edit2"
# 2. Find the line just before the "end" of that method
# 3. Copy and paste these 2 lines BEFORE the "end":
#
# ---START COPY HERE---
      save_inkling_from_args(char, viewer, "secret", args[:inkling_secret_title], args[:inkling_secret_text])
      save_inkling_from_args(char, viewer, "goal", args[:inkling_goal_title], args[:inkling_goal_text])
# ---END COPY---

# ============================================================================
# STEP 5: Add code to save chargen data
# ============================================================================
#
# FILE: plugins/profile/custom_char_fields.rb
# METHOD: def self.save_fields_from_chargen(char, args)
#
# 1. Find the method "def self.save_fields_from_chargen(char, args)"
# 2. Find the line just before the "end" of that method
# 3. Copy and paste these 2 lines BEFORE the "end":
#
# ---START COPY HERE---
      save_inkling_from_args(char, char, "secret", args[:inkling_secret_title], args[:inkling_secret_text])
      save_inkling_from_args(char, char, "goal", args[:inkling_goal_title], args[:inkling_goal_text])
# ---END COPY---

# ============================================================================
# STEP 6: Add the helper method
# ============================================================================
#
# FILE: plugins/profile/custom_char_fields.rb
# LOCATION: At the end of the CustomCharFields module (before the final "end")
#
# 1. Go to the end of the CustomCharFields module
# 2. Find the final "end" that closes the module
# 3. Copy and paste this entire method BEFORE that final "end":
#
# ---START COPY HERE---
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
# You have successfully integrated the Secret and Goal inkling fields into:
# - Character profile viewing
# - Character profile editing
# - Character generation
#
# Players can now create and edit their Secret and Goal inklings through
# both the chargen process and their character profile page.
