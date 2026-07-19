module AresMUSH
  module Inklings
    class AppReviewApi
      # Formats chargen draft status for inclusion in the character's app-review
      # screen. Returns a string suitable for display in Chargen.format_review_status,
      # or an empty string when the feature is disabled.
      #
      # Status logic:
      # - If chargen is disabled: returns empty string (no review line shown)
      # - If chargen is required and any configured field is incomplete: RED error
      # - If chargen is optional and any configured field is incomplete: YELLOW warning
      # - If all configured fields are complete: GREEN OK
      #
      # Evaluates character's inkling_<kind>_text draft fields (secret and goal by default).
      # Blank strings, whitespace-only, nil, and missing fields all count as incomplete.
      #
      # Returns a single formatted review line or empty string.
      def self.app_review_lines(char)
        return [] unless Inklings.chargen_enabled?
        return [] if Inklings.chargen_required_types.empty?

        chargen_required = Global.read_config("inklings", "chargen_required")
        chargen_required = true if chargen_required.nil?

        # Identify incomplete fields
        incomplete_fields = []
        Inklings.chargen_required_types.each do |kind|
          next unless char.respond_to?("inkling_#{kind}_text")
          text = char.send("inkling_#{kind}_text")
          incomplete_fields << kind if text.to_s.blank?
        end

        return [] if incomplete_fields.empty?

        # All required types have incomplete fields - return a single review line
        label = format_field_labels(incomplete_fields)
        severity = chargen_required ? :error : :warning
        message_key = chargen_required ? 'chargen.oops_missing' : 'chargen.are_you_sure'

        [Chargen.format_review_status(severity, t(message_key, missing: label))]
      end

      private

      # Formats the list of incomplete field labels for the review message.
      # E.g., ["secret", "goal"] -> "Secrets & Goals"
      def self.format_field_labels(kinds)
        labels = kinds.map { |k| Inklings.kind_label(k) }

        case labels.length
        when 1
          labels.first
        when 2
          "#{labels[0]} & #{labels[1]}"
        else
          "#{labels[0..-2].join(', ')} & #{labels[-1]}"
        end
      end
    end
  end
end
