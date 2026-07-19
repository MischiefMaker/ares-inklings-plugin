# CUSTOM APP REVIEW SNIPPET
#
# Adds chargen Secrets & Goals validation to the character app review screen.
#
# FILE: aresmush/plugins/chargen/custom_app_review.rb
#
# NOTE: This is a SHARED HOOK FILE. On a stock Ares install, the
# custom_app_review method is present but returns []. You are MERGING
# the lines below into the existing method. If other plugins already
# added code to this method, KEEP their lines and add yours.
#
# ===========================================================================
# COPY ONLY THIS METHOD BODY (not the comment block above):
# ===========================================================================
#
# ---START COPY HERE---
#
# def self.custom_app_review(char)
#   messages = []
#   # Inklings chargen integration - validates Secret and Goal drafts
#   # if chargen is enabled and required for approval
#   inkling_review = Inklings.get_app_review_issues(char)
#   messages << inkling_review unless inkling_review.blank?
#   return messages.join("\n")
# end
#
# ---END COPY---
#
# ===========================================================================
# WHAT THIS DOES
# ===========================================================================
#
# When chargen is ENABLED:
#   • If chargen is REQUIRED (default) and any configured field (Secret/Goal) is blank:
#     Shows a RED error that blocks approval. Player must fill in the field.
#   • If chargen is OPTIONAL and any configured field is blank:
#     Shows a YELLOW warning that doesn't block approval, but alerts staff.
#   • If all configured fields are filled in:
#     Shows GREEN OK and the check passes silently.
#
# When chargen is DISABLED:
#   • No review line appears at all.
#
# ===========================================================================
# ⚠️  CRITICAL: DO NOT PASTE ONLY THE ONE-LINE INTEGRATION ⚠️
# ===========================================================================
#
# If you choose to merge into an existing method (Step 3, second option),
# you MUST keep the full method structure including:
#   - def self.custom_app_review(char)
#   - messages = []
#   - messages (at the end)
#
# Pasting ONLY "messages.concat(...)" without these lines will cause the
# error: "undefined local variable or method `messages'"
#
# ===========================================================================
# INTEGRATION STEPS
# ===========================================================================
#
# STEP 1: Open aresmush/plugins/chargen/custom_app_review.rb in your game folder
#         (not the plugin folder, and not ares-webportal)
#
# STEP 2: Find the custom_app_review method. It will look like:
#
#         def self.custom_app_review(char)
#           messages = []
#           # ... possibly other checks from other plugins ...
#           messages
#         end
#
# STEP 3: Choose your approach based on the current state:
#
#   IF THE METHOD BODY IS EMPTY OR ONLY HAS "messages = []" and "messages":
#     Replace the ENTIRE method definition (including def/end) with the
#     code in the COPY section above.
#
#   IF THE METHOD ALREADY HAS OTHER CHECKS (from this or other plugins):
#     Keep the entire method structure. Add ONLY this line:
#
#       inkling_review = Inklings.get_app_review_issues(char)
#       messages << inkling_review unless inkling_review.blank?
#
#     Add it BEFORE the final "return messages.join("\n")" statement, but AFTER
#     the "messages = []" initialization. Do NOT move or remove any
#     existing code.
#
#   IMPORTANT: Make sure the method ends with:
#     return messages.join("\n")
#
#     NOT just:
#     messages
#
# STEP 4: Restart the game for the changes to take effect.
#
# ===========================================================================
# EXAMPLE: Adding to a game that already has other checks
# ===========================================================================
#
# def self.custom_app_review(char)
#   messages = []
#   # Some other plugin's check
#   inkling_review = Inklings.get_app_review_issues(char)
#   messages << inkling_review unless inkling_review.blank?
#   # ... other checks ...
#   return messages.join("\n")
# end
#
# ===========================================================================
# CONFIGURATION
# ===========================================================================
#
# The behavior is controlled by these settings in game/config/inklings.yml:
#
#   chargen_enabled: true/false
#     Controls whether chargen integration is on or off. When false, no
#     Secrets & Goals review line appears.
#
#   chargen_required: true/false
#     Controls whether incomplete fields block approval (true = red error,
#     false = yellow warning). Defaults to true (required).
#
# ===========================================================================
# VERIFICATION
# ===========================================================================
#
# After pasting, restart the game and visit a character's app review screen
# (+char/app <charname>). You should see:
#
#   • Nothing, if chargen is disabled
#   • A red error "Secrets & Goals inkling is missing" if required and blank
#   • A yellow warning "Are you sure? Secrets & Goals..." if optional and blank
#   • A green checkmark if all fields are filled in
#
# The exact text comes from the Ares locale files (chargen.oops_missing,
# chargen.are_you_sure, chargen.ok), so it will be translated according to
# your game's language settings.
