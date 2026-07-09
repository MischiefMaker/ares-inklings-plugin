module AresMUSH
  module Inklings
    # +inkling <id>
    class InklingViewCmd
      include CommandHandler

      attr_accessor :id

      def parse_args
        self.id = cmd.args
      end

      def required_args
        [self.id]
      end

      def check_valid_inkling
        return t('inklings.invalid_id') if !Inklings.find_inkling(self.id)
        return nil
      end

      def check_can_view
        inkling = Inklings.find_inkling(self.id)
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if Inklings.is_participant?(inkling, enactor)
        return t('dispatcher.not_allowed')
      end

      def handle
        inkling = Inklings.find_inkling(self.id)

        Inklings.sync_job_replies(inkling)

        lines = inkling.messages.sort_by { |m| m.created_at }
          .select { |m| Inklings.can_see_message?(m, enactor) }
          .map do |m|
            who = m.author ? m.author.name : "?"
            private_tag = m.is_private == "true" ? " [private]" : ""
            "#{m.created_at.strftime('%m/%d %H:%M')} #{who}#{private_tag}: #{m.text}"
          end

        job_line = inkling.job ? "\n\n(Linked job ##{inkling.job.id}, status #{inkling.job.status})" : ""
        title = "##{inkling.id} [#{inkling.kind.upcase}] (#{inkling.status})"

        template = BorderedDisplayTemplate.new lines.join("\n") + job_line, title
        client.emit template.render

        if inkling.character == enactor
          inkling.update(player_unread: "false")
        end
      end
    end
  end
end
