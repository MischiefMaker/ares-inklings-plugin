# CUSTOM CHARACTER FIELDS - INKLINGS TAB
#
# FILE: aresmush/plugins/profile/custom_char_fields.rb (in aresmush, not the plugin folder)
#
# INSTALLATION:
# 1. Open aresmush/plugins/profile/custom_char_fields.rb
# 2. Find the get_fields_for_viewing method
# 3. Add these 2 lines before the final "fields" line:

fields[:inkling_types] = Inklings::InklingApi.creatable_type_options(viewer)
fields[:can_manage_inklings] = Inklings.can_manage_inklings?(viewer)

# 4. Save and restart the game
