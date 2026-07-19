module AresMUSH
  module Inklings
    # Chargen hook that prompts players to create secret and goal
    # inklings at the final step of character creation.
    class ChargenHook
      # Called during the chargen process. Prompts the player to create the
      # required chargen inkling types (secret and goal - see
      # Inklings.chargen_required_types) if they haven't already. Does
      # nothing when chargen is disabled (chargen_enabled: false), since the
      # type list is empty then.
      def self.chargen_finalize(char)
        required_types = Inklings.chargen_required_types
        return true if required_types.empty?

        missing_types = []
        required_types.each do |kind|
          existing = Inkling.find(character_id: char.id, kind: kind).first
          missing_types << kind if !existing
        end

        if missing_types.any?
          missing_types.each do |kind|
            label = Inklings.kind_label(kind)
            description = Inklings.kind_description(kind)
            prompt = "Please create a #{label.downcase} inkling"
            prompt << " (#{description})" if description
            prompt << ". Use: +inkling/#{kind} <title>/<text>"
            Login.emit_ooc_if_logged_in(char, "<inklings> %xh%crCharGen:%xn #{prompt}")
          end
          return false  # Return false to indicate chargen is not yet complete
        end

        return true  # All required types exist, chargen can proceed
      end
    end
  end
end
