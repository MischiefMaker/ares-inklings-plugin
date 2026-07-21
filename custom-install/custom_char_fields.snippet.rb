# CUSTOM CHARACTER FIELDS SNIPPET - INKLINGS TAB DATA
#
# FILE: aresmush/plugins/profile/custom_char_fields.rb
#       (in your game's aresmush folder, NOT the plugin folder)
#
# This is a SHARED HOOK FILE. On a stock Ares install, the get_fields_for_viewing
# method is present but returns {}. You are ADDING Inklings data to it.
#
# ===========================================================================
# INSTALLATION
# ===========================================================================
#
# 1. Open aresmush/plugins/profile/custom_char_fields.rb
#
# 2. Find the get_fields_for_viewing method. It looks like:
#
#    def self.get_fields_for_viewing(char, viewer)
#      fields = {}
#      # ... possibly other plugins' code ...
#      fields
#    end
#
# 3. Add the code block below to that method, BEFORE the final "fields" line.
#    If you already have other code there, just add the Inklings lines.
#
# 4. Restart the game.
#
# ===========================================================================
# CODE TO ADD
# ===========================================================================

# Inklings tab data: type picker and staff override flag
fields[:inkling_types] = Inklings::InklingApi.creatable_type_options(viewer)
fields[:can_manage_inklings] = Inklings.can_manage_inklings?(viewer)

# ===========================================================================
# WHAT THIS DOES
# ===========================================================================
#
# - inkling_types: List of inkling types the viewer can create (passed to the
#   web portal's "New Inkling" dropdown so it populates without a separate request)
#
# - can_manage_inklings: Server-side permission check for whether the viewer
#   can manage/approve inklings (passed to show/hide the staff "+ New Inkling"
#   button on the profile page)
