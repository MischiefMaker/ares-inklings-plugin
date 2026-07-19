module AresMUSH
  module Inklings
    # App review hook that validates players have created required
    # inklings as part of character approval.
    class AppReviewHook
      # Called during app review. Checks that the character has filled in
      # all required chargen draft types (secret and goal - see
      # Inklings.chargen_required_types) with non-empty text. Returns an
      # empty array when chargen is disabled (chargen_enabled: false) or when
      # there are no issues, otherwise a list of the problems found.
      #
      # Checks the DRAFT attributes (char.inkling_<kind>_text), not real
      # Inkling records - unapproved characters never have a real Inkling
      # for these kinds, only draft text that Inklings.character_approved
      # converts once app review actually approves the character.
      def self.app_review_issues(char)
        issues = []
        required_types = Inklings.chargen_required_types
        return issues if required_types.empty?

        required_types.each do |kind|
          label = Inklings.kind_label(kind)
          text = char.respond_to?("inkling_#{kind}_text") ? char.send("inkling_#{kind}_text") : nil

          if text.to_s.blank?
            issues << "#{label} inkling is missing."
          end
        end

        return issues
      end
    end
  end
end
