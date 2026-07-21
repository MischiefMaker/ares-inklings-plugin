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
# 1. Find the get_fields_for_viewing method. It will look something like this:
#
#      def self.get_fields_for_viewing(char, viewer)
#        fields = {}
#        return fields
#      end
#
# 2. Add the 3 lines below INSIDE the method, AFTER "fields = {}" and
#    BEFORE the "return fields" line. Your method should now look exactly
#    like this:

def self.get_fields_for_viewing(char, viewer)
  fields = {}
  fields[:inkling_types] = Inklings::InklingApi.creatable_type_options(viewer)
  fields[:can_manage_inklings] = Inklings.can_manage_inklings?(viewer)
  return fields
end

# METHOD 2: get_fields_for_chargen
# ---------
# 1. Find the get_fields_for_chargen method. It will look something like this:
#
#      def self.get_fields_for_chargen(char)
#        fields = {}
#        return fields
#      end
#
# 2. Replace the ENTIRE method with the code below:

def self.get_fields_for_chargen(char)
  fields = {}
  fields[:inkling_secret_title] = Website.format_input_for_html(char.inkling_secret_title.to_s)
  fields[:inkling_secret_text] = Website.format_input_for_html(char.inkling_secret_text.to_s)
  fields[:inkling_goal_title] = Website.format_input_for_html(char.inkling_goal_title.to_s)
  fields[:inkling_goal_text] = Website.format_input_for_html(char.inkling_goal_text.to_s)
  return fields
end

# METHOD 3: save_fields_from_chargen
# ---------
# 1. Find the save_fields_from_chargen method. It will look something like this:
#
#      def self.save_fields_from_chargen(char, chargen_data)
#        return []
#      end
#
# 2. Replace the ENTIRE method with the code below:

def self.save_fields_from_chargen(char, chargen_data)
  data = chargen_data['custom'] || {}
  char.update(inkling_secret_title: Website.format_input_for_mush(data['inkling_secret_title'].to_s))
  char.update(inkling_secret_text: Website.format_input_for_mush(data['inkling_secret_text'].to_s))
  char.update(inkling_goal_title: Website.format_input_for_mush(data['inkling_goal_title'].to_s))
  char.update(inkling_goal_text: Website.format_input_for_mush(data['inkling_goal_text'].to_s))
  return []
end

# ===========================================================================
# DONE
# ===========================================================================
# Save the file and restart the game.
