module AresMUSH
  module Inklings
    # Chargen hook that prompts players to create secret and goal
    # inklings at the final step of character creation.
    class ChargenHook
      # Called during the chargen process. Prompts the player to create
      # a secret and a goal inkling if they haven't already.
      def self.chargen_finalize(char)
        secret = Inkling.find(character_id: char.id, kind: "secret").first
        goal = Inkling.find(character_id: char.id, kind: "goal").first

        unless secret && goal
          if !secret
            Login.emit_ooc_if_logged_in(char, "<inklings> %xh%crCharGen:%xn Please create a secret inkling describing an IC secret your character holds. Use: +inkling/secret <text>")
          end

          if !goal
            Login.emit_ooc_if_logged_in(char, "<inklings> %xh%crCharGen:%xn Please create a goal inkling describing what your character is working toward. Use: +inkling/goal <text>")
          end

          return false  # Return false to indicate chargen is not yet complete
        end

        return true  # Both exist, chargen can proceed
      end
    end
  end
end
