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
# STEP 3: Add this line inside the method:
#
#         Inklings.convert_chargen_drafts(char)
#
#         (If other plugins have already added code here, just add this line
#          alongside their existing code - the order doesn't matter.)
#
# STEP 4: Reload chargen from the MUSH with: load chargen
#
# ===========================================================================
# EXAMPLE
# ===========================================================================
#
# def self.custom_approval(char)
#   Inklings.convert_chargen_drafts(char)
#   # Other approval triggers may be added here
# end
#
# ===========================================================================
# WHAT THIS DOES
# ===========================================================================
#
# When a character is approved (via +char/approve <name> or the web UI):
#
# 1. The chargen plugin calls custom_approval(char) after setting
#    char.is_approved = true
#
# 2. This hook calls Inklings.convert_chargen_drafts(char)
#
# 3. The Inklings plugin then:
#    - Inspects the character's inkling_secret_title/text and
#      inkling_goal_title/text draft fields
#    - For each field with content, creates a real Inkling with that text
#    - Clears the draft field after successful creation
#    - Logs any errors without blocking approval
#
# 4. Staff can view the newly created Inklings in the Jobs system and on
#    the character's Inklings tab
#
# ===========================================================================
# CONFIGURATION
# ===========================================================================
#
# The behavior is controlled by the "chargen_enabled" setting in
# game/config/inklings.yml:
#
#   chargen_enabled: true   - Drafts convert to Inklings on approval (default)
#   chargen_enabled: false  - Chargen is disabled; nothing converts
#
# ===========================================================================
# VERIFICATION
# ===========================================================================
#
# After pasting, restart the game and approve a test character with
# populated Secret and Goal drafts. Within a few seconds, check:
#
#   +inkling/list <character>   - should show the converted Secret and Goal
#   +inklings                   - if your own character, shows your threads
#   Character profile web tab   - Inklings tab should show the new threads
#
# Drafts disappear from the app-review screen and are not shown again
# after approval.
#
