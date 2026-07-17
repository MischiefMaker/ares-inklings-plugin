# CUSTOM CHARACTER FIELDS SNIPPET - BACKEND INTEGRATION
#
# FILE: plugins/profile/custom_char_fields.rb
# NOTE: This is a SHARED HOOK FILE used by multiple plugins.
#       You will ADD CODE to existing methods, not replace the whole file.
#
# OVERVIEW:
# This plugin needs to save/display Secret and Goal inklings that players
# create during chargen and can edit from their profile.
#
# Follow the steps below in order. Each step is a separate c&p action.
#
# ============================================================================
# STEP 1: Import the Inklings API at the top of your CustomCharFields module
# ============================================================================
#
# FILE: plugins/profile/custom_char_fields.rb
# LOCATION: Inside the module AresMUSH section, at the very top
#
# INSTRUCTIONS:
# 1. Open plugins/profile/custom_char_fields.rb
# 2. Find the line "module CustomCharFields"
# 3. Right below it, add this line:
#
#    ---START COPY HERE---
require_relative '../../inklings/public/inklings_api'
#    ---END COPY---

# ============================================================================
# STEP 2: Add fields to the profile viewing method
# ============================================================================
#
# FILE: plugins/profile/custom_char_fields.rb
# METHOD: get_fields_for_viewing
# LOCATION: Inside the returned hash { ... }
#
# INSTRUCTIONS:
# 1. Find the method "def self.get_fields_for_viewing(char, viewer)"
# 2. Find the hash that starts with "{"
# 3. Find the end of the hash (before the closing "}")
# 4. Copy and paste these 4 lines BEFORE the closing "}" :
#
#    ---START COPY HERE---
        inkling_secret_title: Inkling.find(character_id: char.id, kind: "secret").first&.title,
        inkling_secret_text: Inkling.find(character_id: char.id, kind: "secret").first ? Website.format_markdown_for_html(Inkling.find(character_id: char.id, kind: "secret").first.messages.to_a.first&.text) : nil,
        inkling_goal_title: Inkling.find(character_id: char.id, kind: "goal").first&.title,
        inkling_goal_text: Inkling.find(character_id: char.id, kind: "goal").first ? Website.format_markdown_for_html(Inkling.find(character_id: char.id, kind: "goal").first.messages.to_a.first&.text) : nil,
#    ---END COPY---

# ============================================================================
# STEP 3: Add fields to the profile editing method
# ============================================================================
#
# FILE: plugins/profile/custom_char_fields.rb
# METHOD: get_fields_for_editing
# LOCATION: Inside the returned hash { ... }
#
# INSTRUCTIONS:
# 1. Find the method "def self.get_fields_for_editing(char, viewer)"
# 2. Find the hash that starts with "{"
# 3. Find the end of the hash (before the closing "}")
# 4. Copy and paste these 4 lines BEFORE the closing "}" :
#
#    ---START COPY HERE---
        inkling_secret_title: Inkling.find(character_id: char.id, kind: "secret").first&.title,
        inkling_secret_text: Inkling.find(character_id: char.id, kind: "secret").first&.messages&.to_a&.first&.text,
        inkling_goal_title: Inkling.find(character_id: char.id, kind: "goal").first&.title,
        inkling_goal_text: Inkling.find(character_id: char.id, kind: "goal").first&.messages&.to_a&.first&.text,
#    ---END COPY---

# ============================================================================
# STEP 4: Add save code to profile edit method
# ============================================================================
#
# FILE: plugins/profile/custom_char_fields.rb
# METHOD: save_fields_from_profile_edit (or save_fields_from_profile_edit2)
# LOCATION: Inside the method body
#
# INSTRUCTIONS:
# 1. Find the method "def self.save_fields_from_profile_edit"
#    (Note: Some versions may call it save_fields_from_profile_edit2)
# 2. Find the last line of that method (usually before the "end")
# 3. Copy and paste these 2 lines BEFORE the "end" :
#
#    ---START COPY HERE---
      Inklings::InklingApi.reply_to_inkling(char.id, Inkling.find(character_id: char.id, kind: "secret").first.id, viewer.id, args[:inkling_secret_text]) if Inkling.find(character_id: char.id, kind: "secret").first && args[:inkling_secret_text].present?
      Inklings::InklingApi.reply_to_inkling(char.id, Inkling.find(character_id: char.id, kind: "goal").first.id, viewer.id, args[:inkling_goal_text]) if Inkling.find(character_id: char.id, kind: "goal").first && args[:inkling_goal_text].present?
#    ---END COPY---

# ============================================================================
# STEP 5: Add save code to chargen method
# ============================================================================
#
# FILE: plugins/profile/custom_char_fields.rb
# METHOD: save_fields_from_chargen
# LOCATION: Inside the method body
#
# INSTRUCTIONS:
# 1. Find the method "def self.save_fields_from_chargen(char, args)"
# 2. Find the last line of that method (usually before the "end")
# 3. Copy and paste these 2 lines BEFORE the "end" :
#
#    ---START COPY HERE---
      Inklings::InklingApi.create_inkling(char.id, char.id, "secret", args[:inkling_secret_text], args[:inkling_secret_title]) if args[:inkling_secret_title].present?
      Inklings::InklingApi.create_inkling(char.id, char.id, "goal", args[:inkling_goal_text], args[:inkling_goal_title]) if args[:inkling_goal_title].present?
#    ---END COPY---

# ============================================================================
# DONE
# ============================================================================
#
# You have successfully integrated the Inklings chargen/profile fields.
# Players can now create and edit their Secret and Goal during chargen
# and from their character profile page.
