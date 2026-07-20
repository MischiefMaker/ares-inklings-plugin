# CUSTOM APPROVAL SNIPPET - CHARGEN INKLING CONVERSION
#
# FILE: aresmush/plugins/chargen/custom_approval.rb  (in your game folder,
#       NOT the plugin folder, and NOT ares-webportal)
#
# PURPOSE:
# Converts chargen Secrets & Goals draft fields into real Inklings when a
# character is approved. This uses the official AresMUSH approval hook
# (https://www.aresmush.com/tutorials/code/hooks/approval-triggers.html).
#
# NOTE: This is a SHARED HOOK FILE. On a stock Ares install the
# custom_approval method is present but returns nothing. You are MERGING
# the call below into the existing method. If other plugins already
# added code to this method, KEEP their lines and add yours.
#
# ===========================================================================
# INSTALLATION STEPS
# ===========================================================================
#
# STEP 1: Open aresmush/plugins/chargen/custom_approval.rb in your game folder
#         (not the plugin folder, and not ares-webportal)
#
# STEP 2: Find the custom_approval method. It will look like:
#
#         def self.custom_approval(char)
#         end
#
# STEP 3: Add this line INSIDE the method:
#
#         Inklings.convert_chargen_drafts(char)
#
#         (If other plugins have already added code here, just add this line
#          alongside their existing code - the order doesn't matter.)
#
# STEP 4: Reload chargen from the MUSH with: load chargen
#
# ===========================================================================
# COPY THIS LINE INTO THE METHOD
# ===========================================================================

Inklings.convert_chargen_drafts(char)

# ===========================================================================
# EXAMPLE (what your method should look like after adding the line)
# ===========================================================================
#
# def self.custom_approval(char)
#   Inklings.convert_chargen_drafts(char)
#   # Other approval triggers may be added here
# end
#
#
