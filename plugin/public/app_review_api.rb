module AresMUSH
  module Inklings
    class AppReviewApi
      # Formats chargen draft status for inclusion in the character's app-review
      # screen. Returns one status line per configured chargen field.
      #
      # Status logic:
      # - If chargen is disabled: returns [] (no review lines shown)
      # - For each configured field:
      #   - If incomplete and required: [RED error line] "Checking for X Inklings. < Oops! Missing X >"
      #   - If incomplete and optional: [YELLOW warning line] "Checking for X Inklings. < Are you sure? Missing X >"
      #   - If complete: [GREEN OK line] "Checking for X Inklings. < OK! >"
      #
      # Evaluates character's inkling_<kind>_text draft fields (secret and goal by default).
      # Creates one review line per field (incomplete or complete). Blank strings, whitespace-only, nil,
      # and missing fields all count as incomplete.
      #
      # Returns: Array of formatted review status line strings (always safe to concat)
      def self.app_review_lines(char)
        return [] unless Inklings.chargen_enabled?
        return [] if Inklings.chargen_required_types.empty?

        chargen_required = Global.read_config("inklings", "chargen_required")
        chargen_required = true if chargen_required.nil?

        message_key = chargen_required ? 'inklings.chargen_oops_missing' : 'inklings.chargen_are_you_sure'

        review_lines = []
        Inklings.chargen_required_types.each do |kind|
          next unless char.respond_to?("inkling_#{kind}_text")
          text = char.send("inkling_#{kind}_text")
          # A title is also required (see Inklings.convert_chargen_drafts,
          # which needs both to actually create the Inkling on approval) -
          # text-only was previously treated as complete here, which let a
          # blank-titled draft show a green "OK!" and pass review, only to
          # silently fail to convert into a real Inkling later.
          title = char.respond_to?("inkling_#{kind}_title") ? char.send("inkling_#{kind}_title") : nil

          field_label = Inklings.kind_label(kind)
          check_label = t('inklings.chargen_checking_inklings', types: field_label)

          if text.to_s.blank? || title.to_s.blank?
            review_lines << Chargen.format_review_status(check_label, t(message_key, missing: field_label))
          else
            review_lines << Chargen.format_review_status(check_label, t('chargen.ok'))
          end
        end

        review_lines
      end
    end
  end
end
