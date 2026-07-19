module AresMUSH
  module Inklings
    class CharacterApprovedHandler
      def self.handle(event)
        char = event.char
        return unless char

        # Convert draft chargen-inkling data to actual Inkling records
        Inklings.chargen_required_types.each do |kind|
          title = char.custom_field("inkling_#{kind}_title")
          text = char.custom_field("inkling_#{kind}_text")

          # Only create if draft data exists
          next if title.to_s.blank? && text.to_s.blank?

          # Create the actual inkling
          begin
            InklingApi.create_inkling(char.id, char.id, kind, text, title)
          rescue => e
            AresMUSH::Coder.log_error "Error creating approved inkling for #{char.name} (#{kind}): #{e.message}", e
          end
        end
      end
    end
  end
end

# Register the event handler
AresMUSH::Events.subscribe("character_approved", AresMUSH::Inklings::CharacterApprovedHandler)
