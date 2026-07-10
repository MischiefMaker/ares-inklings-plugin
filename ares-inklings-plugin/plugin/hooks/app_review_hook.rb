module AresMUSH
  module Inklings
    # App review hook that validates players have created a secret and
    # goal inkling as part of character approval.
    class AppReviewHook
      # Called during app review. Checks that the character has both a
      # secret and a goal inkling with non-empty text.
      # Returns an array of issues found, or empty array if all is well.
      def self.app_review_issues(char)
        issues = []

        secret = Inkling.find(character_id: char.id, kind: "secret").first
        unless secret
          issues << "Secret inkling is missing."
        end

        goal = Inkling.find(character_id: char.id, kind: "goal").first
        unless goal
          issues << "Goal inkling is missing."
        end

        # Check that both inklings have actual messages (not empty threads)
        if secret && secret.messages.empty?
          issues << "Secret inkling has no text."
        end

        if goal && goal.messages.empty?
          issues << "Goal inkling has no text."
        end

        return issues
      end
    end
  end
end
