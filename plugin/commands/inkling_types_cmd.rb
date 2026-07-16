module AresMUSH
  module Inklings
    # +inkling/types
    #
    # Lists every configured inkling type with its description, read
    # live from game/config/inklings.yml (see the "types" section
    # there). This is the authoritative, always-current listing -
    # since it reads config directly, it can never drift out of sync
    # the way prose in a help file could after a config edit.
    #
    # Available to everyone, including unapproved characters, since
    # it's purely informational and some types (goal, secret) are
    # usable during chargen before a character is approved.
    class InklingTypesCmd
      include CommandHandler

      def handle
        sections = []

        staff_lines = type_lines(Inklings.staff_kinds)
        sections << "%xh#{t('inklings.types_section_staff')}%xn\n#{staff_lines}" if !staff_lines.blank?

        player_lines = type_lines(Inklings.player_kinds)
        sections << "%xh#{t('inklings.types_section_player')}%xn\n#{player_lines}" if !player_lines.blank?

        shared_lines = type_lines(Inklings.shared_kinds)
        sections << "%xh#{t('inklings.types_section_shared')}%xn\n#{shared_lines}" if !shared_lines.blank?

        body = sections.join("\n\n")
        template = BorderedDisplayTemplate.new body, t('inklings.types_title')
        client.emit template.render
      end

      private

      def type_lines(kinds)
        kinds.sort.map { |kind|
          label = Inklings.color_type(Inklings.kind_label(kind).upcase)
          desc = Inklings.kind_description(kind)
          "#{label} - #{desc}"
        }.join("\n")
      end
    end
  end
end
