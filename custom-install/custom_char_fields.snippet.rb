# CUSTOM CHARACTER FIELDS - INKLINGS
#
# FILE: aresmush/plugins/profile/custom_char_fields.rb (in aresmush, not the plugin folder)
#
# ===========================================================================
# INSTALLATION
# ===========================================================================
#
# This file needs three method updates. Find each method and add the
# Inklings code shown below.
#
# METHOD 1 is always required.
# METHODS 2 and 3 are only required if you are using chargen integration
# (chargen_enabled: true in game/config/inklings.yml). If chargen is
# disabled, skip METHODS 2 and 3.
#
# METHOD 1: get_fields_for_viewing
# ---------
# This method populates custom fields visible in the character profile.
#
# CHOOSE ONE OPTION based on your current code:
#
# ===========================================================================
# OPTION A: METHOD IS EMPTY (only has "fields = {}" and "return fields")
# ===========================================================================
#
# Replace the ENTIRE method with this:

def self.get_fields_for_viewing(char, viewer)
  fields = {}
  fields[:inkling_types] = Inklings::InklingApi.creatable_type_options(viewer)
  fields[:can_manage_inklings] = Inklings.can_manage_inklings?(viewer)
  return fields
end

# ===========================================================================
# OPTION B: METHOD ALREADY HAS OTHER CUSTOM FIELDS
# ===========================================================================
#
# If other plugins (or your own code) already added fields to this method,
# add ONLY these 2 lines inside the method, AFTER "fields = {}" and
# BEFORE the "return fields" line:
#
#      fields[:inkling_types] = Inklings::InklingApi.creatable_type_options(viewer)
#      fields[:can_manage_inklings] = Inklings.can_manage_inklings?(viewer)
#
# Your method should then look something like:
#
#      def self.get_fields_for_viewing(char, viewer)
#        fields = {}
#        fields[:some_other_field] = ...
#        fields[:inkling_types] = Inklings::InklingApi.creatable_type_options(viewer)
#        fields[:can_manage_inklings] = Inklings.can_manage_inklings?(viewer)
#        return fields
#      end

# METHOD 2: get_fields_for_chargen
# ---------
# This method populates custom fields during character creation (chargen).
# ONLY REQUIRED IF CHARGEN IS ENABLED (chargen_enabled: true in config).
#
# CHOOSE ONE OPTION based on your current code:
#
# ===========================================================================
# OPTION A: METHOD IS EMPTY (only has "fields = {}" and "return fields")
# ===========================================================================
#
# Replace the ENTIRE method with this:

def self.get_fields_for_chargen(char)
  fields = {}
  fields[:inkling_secret_title] = Website.format_input_for_html(char.inkling_secret_title.to_s)
  fields[:inkling_secret_text] = Website.format_input_for_html(char.inkling_secret_text.to_s)
  fields[:inkling_goal_title] = Website.format_input_for_html(char.inkling_goal_title.to_s)
  fields[:inkling_goal_text] = Website.format_input_for_html(char.inkling_goal_text.to_s)
  return fields
end

# ===========================================================================
# OPTION B: METHOD ALREADY HAS OTHER CUSTOM FIELDS
# ===========================================================================
#
# If other plugins (or your own code) already added fields to this method,
# add ONLY these 4 lines inside the method, AFTER "fields = {}" and
# BEFORE the "return fields" line:
#
#      fields[:inkling_secret_title] = Website.format_input_for_html(char.inkling_secret_title.to_s)
#      fields[:inkling_secret_text] = Website.format_input_for_html(char.inkling_secret_text.to_s)
#      fields[:inkling_goal_title] = Website.format_input_for_html(char.inkling_goal_title.to_s)
#      fields[:inkling_goal_text] = Website.format_input_for_html(char.inkling_goal_text.to_s)
#
# Your method should then look something like:
#
#      def self.get_fields_for_chargen(char)
#        fields = {}
#        fields[:some_other_field] = ...
#        fields[:inkling_secret_title] = Website.format_input_for_html(char.inkling_secret_title.to_s)
#        fields[:inkling_secret_text] = Website.format_input_for_html(char.inkling_secret_text.to_s)
#        fields[:inkling_goal_title] = Website.format_input_for_html(char.inkling_goal_title.to_s)
#        fields[:inkling_goal_text] = Website.format_input_for_html(char.inkling_goal_text.to_s)
#        return fields
#      end

# METHOD 3: save_fields_from_chargen
# ---------
# This method saves custom fields after chargen submission.
# ONLY REQUIRED IF CHARGEN IS ENABLED (chargen_enabled: true in config).
#
# CHOOSE ONE OPTION based on your current code:
#
# ===========================================================================
# OPTION A: METHOD IS EMPTY (only has "return []")
# ===========================================================================
#
# Replace the ENTIRE method with this:

def self.save_fields_from_chargen(char, chargen_data)
  data = chargen_data['custom'] || {}
  char.update(inkling_secret_title: Website.format_input_for_mush(data['inkling_secret_title'].to_s))
  char.update(inkling_secret_text: Website.format_input_for_mush(data['inkling_secret_text'].to_s))
  char.update(inkling_goal_title: Website.format_input_for_mush(data['inkling_goal_title'].to_s))
  char.update(inkling_goal_text: Website.format_input_for_mush(data['inkling_goal_text'].to_s))
  return []
end

# ===========================================================================
# OPTION B: METHOD ALREADY HAS OTHER CUSTOM FIELD SAVING
# ===========================================================================
#
# If other plugins (or your own code) already save fields in this method,
# add ONLY these 5 lines inside the method, AFTER "data = chargen_data['custom'] || {}"
# and BEFORE the "return []" line:
#
#      char.update(inkling_secret_title: Website.format_input_for_mush(data['inkling_secret_title'].to_s))
#      char.update(inkling_secret_text: Website.format_input_for_mush(data['inkling_secret_text'].to_s))
#      char.update(inkling_goal_title: Website.format_input_for_mush(data['inkling_goal_title'].to_s))
#      char.update(inkling_goal_text: Website.format_input_for_mush(data['inkling_goal_text'].to_s))
#
# Your method should then look something like:
#
#      def self.save_fields_from_chargen(char, chargen_data)
#        data = chargen_data['custom'] || {}
#        char.update(some_other_field: ...)
#        char.update(inkling_secret_title: Website.format_input_for_mush(data['inkling_secret_title'].to_s))
#        char.update(inkling_secret_text: Website.format_input_for_mush(data['inkling_secret_text'].to_s))
#        char.update(inkling_goal_title: Website.format_input_for_mush(data['inkling_goal_title'].to_s))
#        char.update(inkling_goal_text: Website.format_input_for_mush(data['inkling_goal_text'].to_s))
#        return []
#      end

# ===========================================================================
# DONE
# ===========================================================================
# Save the file and restart the game.
