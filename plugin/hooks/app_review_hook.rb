module AresMUSH
  module Inklings
    # App review hook that validates players have created required
    # inklings as part of character approval.
    class AppReviewHook
      # Called during app review. Checks that the character has filled in
      # chargen draft types (secret and goal) if chargen is enabled.
      # Returns an empty array when chargen is disabled or when there are
      # no issues; otherwise returns a list of warnings with severity.
      #
      # - If chargen is REQUIRED (chargen_required: true, default): missing
      #   drafts throw RED warnings (blocking approval).
      # - If chargen is OPTIONAL (chargen_required: false): missing drafts
      #   throw YELLOW warnings (advisory only).
      #
      # Checks the DRAFT attributes (char.inkling_<kind>_text), not real
      # Inkling records - unapproved characters never have a real Inkling
      # for these kinds, only draft text that Inklings.character_approved
      # converts once app review actually approves the character.
      def self.app_review_issues(char)
        issues = []

        return issues unless Inklings.chargen_enabled?

        required_types = Inklings.chargen_required_types
        return issues if required_types.empty?

        chargen_required = Global.read_config("inklings", "chargen_required")
        # Default to true (required) if config is absent
        chargen_required = true if chargen_required.nil?

        severity = chargen_required ? :red : :yellow

        required_types.each do |kind|
          label = Inklings.kind_label(kind)
          text = char.respond_to?("inkling_#{kind}_text") ? char.send("inkling_#{kind}_text") : nil

          if text.to_s.blank?
            issues << {
              message: "#{label} inkling is missing.",
              severity: severity
            }
          end
        end

        return issues
      end
    end
  end
end
