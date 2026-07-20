# CUSTOM APPROVAL SNIPPET - CHARGEN INKLING CONVERSION
#
# FILE: aresmush/plugins/chargen/custom_approval.rb
#       (in your game folder, NOT the plugin folder)
#
# ===========================================================================
# INSTALLATION
# ===========================================================================
#
# 1. Open aresmush/plugins/chargen/custom_approval.rb
# 2. Find the custom_approval method
# 3. Add this line inside the method:

Inklings.convert_chargen_drafts(char)

# 4. Reload chargen: load chargen
#
# ===========================================================================
# EXAMPLE
# ===========================================================================
#
# def self.custom_approval(char)
#   Inklings.convert_chargen_drafts(char)
#   # Other approval triggers may be added here
# end
