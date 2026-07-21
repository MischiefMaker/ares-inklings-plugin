module AresMUSH
  module Inklings
    # +inkling/search <text>
    # Search across visible inklings by tags, titles, and message text.
    class InklingSearchCmd
      include CommandHandler

      attr_accessor :query

      def parse_args
        self.query = cmd.args
      end

      def required_args
        [self.query]
      end

      def check_approved
        return nil if Inklings.can_manage_inklings?(enactor)
        return t('inklings.char_not_approved') unless enactor.is_approved?
        nil
      end

      def handle
        results = Inklings.search_inklings(self.query, enactor)

        if results.empty?
          client.emit_success t('inklings.no_search_results')
          return
        end

        list = []
        results.each_with_index do |inkling, idx|
          title = inkling.title.to_s.blank? ? Inklings.kind_label(inkling.kind) : inkling.title
          owner = inkling.character ? inkling.character.name : "?"
          count_text = "#{inkling.messages.to_a.size} msg(s)"
          lock_text = inkling.locked == "true" ? " %xh%crLOCKED%xn" : ""

          line1 = "##{inkling.id} [#{Inklings.color_type(inkling.kind.upcase)}] #{Inklings.color_title(title)} (#{inkling.status}) " \
            "#{Inklings.format_time(inkling.created_at, '%m/%d')} - #{count_text}#{lock_text}"
          list << line1
          list << nil unless idx == results.length - 1
        end

        template = BorderedPagedListTemplate.new list, cmd.page, 50,
          t('inklings.search_title', :query => self.query)
        client.emit template.render
      end
    end
  end
end
