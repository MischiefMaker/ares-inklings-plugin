module AresMUSH
  module Inklings
    class AppReviewApi
      # Formats chargen draft status for inclusion in the character's app-review
      # screen. Returns an array of review status lines (one per incomplete field),
      # or an empty array when the feature is disabled or all checks pass.
      #
      # Status logic:
      # - If chargen is disabled: returns [] (no review lines shown)
      # - If chargen is required and a field is incomplete:
      #   returns [RED error line] "Checking for X Inklings. < Oops! Missing X >"
      # - If chargen is optional and a field is incomplete:
      #   returns [YELLOW warning line] "Checking for X Inklings. < Are you sure? X >"
      # - If all configured fields are complete: returns [] (GREEN OK, no lines)
      #
      # Evaluates character's inkling_<kind>_text draft fields (secret and goal by default).
      # Creates one review line per incomplete field. Blank strings, whitespace-only, nil,
      # and missing fields all count as incomplete.
      #
      # Returns: Array of formatted review status line strings (always safe to concat)
      def self.app_review_lines(char)
        return [] unless Inklings.chargen_enabled?
        return [] if Inklings.chargen_required_types.empty?

        chargen_required = Global.read_config("inklings", "chargen_required")
        chargen_required = true if chargen_required.nil?

        message_key = chargen_required ? 'inklings.chargen_oops_missing' : 'inklings.chargen_are_you_sure'

        # Create one review line per incomplete field
        review_lines = []
        Inklings.chargen_required_types.each do |kind|
          next unless char.respond_to?("inkling_#{kind}_text")
          text = char.send("inkling_#{kind}_text")
          next unless text.to_s.blank?

          field_label = Inklings.kind_label(kind)
          check_label = t('inklings.chargen_checking_inklings', types: field_label)
          review_lines << Chargen.format_review_status(check_label, t(message_key, missing: field_label))
        end

        review_lines
      end
    end
  end
end
