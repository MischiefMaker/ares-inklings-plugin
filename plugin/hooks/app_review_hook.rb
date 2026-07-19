module AresMUSH
  module Inklings
    # App review hook that validates players have created required
    # inklings as part of character approval.
    class AppReviewHook
      # Called during app review. Checks that the character has created
      # all required chargen inkling types (secret and goal - see
      # Inklings.chargen_required_types) with non-empty text. Returns an
      # empty array when chargen is disabled (chargen_enabled: false) or when
      # there are no issues, otherwise a list of the problems found.
      def self.app_review_issues(char)
        issues = []
        required_types = Inklings.chargen_required_types
        return issues if required_types.empty?

        required_types.each do |kind|
          inkling = Inkling.find(character_id: char.id, kind: kind).first
          label = Inklings.kind_label(kind)

          unless inkling
            issues << "#{label} inkling is missing."
            next
          end

          if inkling.messages.empty?
            issues << "#{label} inkling has no text."
          end
        end

        return issues
      end
    end
  end
end
