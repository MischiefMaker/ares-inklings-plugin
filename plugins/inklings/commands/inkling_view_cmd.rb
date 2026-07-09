module AresMUSH
  module Inklings
    # +inkling <id>
    class InklingViewCmd
      include CommandHandler

      attr_accessor :id

      def parse_args
        args = cmd.parse_args(/(?<id>.+)/)
        self.id = trim_arg(args.id)
      end

      def required_args
        [self.id]
      end

      def check_approved
        return nil if Inklings.can_manage_inklings?(enactor)
        return t('inklings.char_not_approved') unless enactor.is_approved?
        nil
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

        events = []

        inkling.messages.to_a.sort_by { |m| Inklings.time_value(m.created_at) }
          .select { |m| Inklings.can_see_message?(m, enactor) }
          .each do |m|
            who = m.author ? m.author.name : "?"
            tags = []
            tags << "gm" if m.is_gm_note == "true"
            tags << "private" if m.is_private == "true"
            tag_text = tags.empty? ? "" : " [#{tags.join(", ")}]"
            events << [Inklings.time_value(m.created_at), "#{Inklings.format_time(m.created_at, '%m/%d %H:%M')} #{who}#{tag_text}: #{m.text}"]
          end

        inkling.rolls.to_a.sort_by { |r| Inklings.time_value(r.created_at) }.each do |roll|
          next if !Inklings.can_see_roll?(roll, enactor)

          who = roll.creator ? roll.creator.name : "?"
          private_tag = roll.private == "true" ? " [private]" : ""
          events << [Inklings.time_value(roll.created_at), "#{Inklings.format_time(roll.created_at, '%m/%d %H:%M')} #{who} rolled #{roll.roll_spec}#{private_tag}: #{roll.result}"]
        end

        lines = events.sort_by { |time, _line| time }.map(&:last)

        job_line = inkling.job ? "\n\n(Linked job ##{inkling.job.id}, status #{inkling.job.status})" : ""
        header_title = inkling.title.to_s.blank? ? t("inklings.kind_#{inkling.kind}") : inkling.title
        title = "##{inkling.id} [#{inkling.kind.upcase}] #{header_title} (#{inkling.status})"

        template = BorderedDisplayTemplate.new lines.join("\n") + job_line, title
        client.emit template.render

        if inkling.character == enactor
          inkling.update(player_unread: "false")
        end
      end
    end
  end
end
