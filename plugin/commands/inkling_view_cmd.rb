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

      # Memoized so check_valid_inkling, check_can_view, and handle
      # don't each independently re-fetch the same record.
      def inkling
        @inkling ||= Inklings.find_inkling(self.id)
      end

      def check_approved
        return nil if Inklings.can_manage_inklings?(enactor)
        return t('inklings.char_not_approved') unless enactor.is_approved?
        nil
      end

      def check_valid_inkling
        return t('inklings.invalid_id') if !inkling
        return nil
      end

      def check_can_view
        # Checks run in alphabetical order by method name, not
        # declaration order, so check_valid_inkling may not have run
        # yet. Bail out quietly here and let check_valid_inkling report
        # the real "invalid ID" error instead of crashing on nil.
        return nil if !inkling
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if Inklings.is_participant?(inkling, enactor)
        return t('dispatcher.not_allowed')
      end

      def handle
        Inklings.sync_job_replies(inkling)

        separator = "-" * 60
        blocks = []

        inkling.messages.to_a.sort_by { |m| Inklings.time_value(m.created_at) }
          .select { |m| Inklings.can_see_message?(m, enactor) }
          .each do |m|
            blocks << [Inklings.time_value(m.created_at), format_message_block(m)]
          end

        inkling.rolls.to_a.sort_by { |r| Inklings.time_value(r.created_at) }.each do |roll|
          next if !Inklings.can_see_roll?(roll, enactor)
          blocks << [Inklings.time_value(roll.created_at), format_roll_block(roll)]
        end

        ordered = blocks.sort_by { |time, _block| time }.map(&:last)
        body = ordered.join("\n#{separator}\n")

        shared_lines = []
        shared_names = Inklings.shared_with_names(inkling)
        shared_lines << t('inklings.shared_with_players', :names => shared_names.map { |n| Inklings.color_name(n) }.join(", ")) if shared_names.any?
        group_list = Inklings.shared_group_list(inkling)
        shared_lines << t('inklings.shared_with_groups', :names => group_list.join(", ")) if group_list.any?
        shared_with_line = shared_lines.any? ? "\n\n[#{t('inklings.shared_with_title')}]\n#{shared_lines.join("\n")}" : ""

        job_line = inkling.job ? "\n\n(Linked job ##{inkling.job.id}, status #{inkling.job.status})" : ""
        header_title = inkling.title.to_s.blank? ? Inklings.kind_label(inkling.kind) : inkling.title
        lock_tag = inkling.locked == "true" ? " %xh%crLOCKED - awaiting staff%xn" : ""
        title = "##{inkling.id} [#{Inklings.color_type(inkling.kind.upcase)}] #{Inklings.color_title(header_title)} (#{inkling.status})#{lock_tag}"

        submit_reminder = (!Inklings.can_manage_inklings?(enactor) && inkling.character == enactor && inkling.locked != "true" && inkling.status != "closed") ?
          "\n\n#{t('inklings.not_yet_submitted_notice', :id => inkling.id)}" : ""

        template = BorderedDisplayTemplate.new body + shared_with_line + job_line + submit_reminder, title
        client.emit template.render

        if inkling.character == enactor
          Inklings.update_inkling(inkling, player_unread: "false")
        end
      end

      private

      # A single message rendered as its own block: a metadata line
      # (reference number, timestamp, author, tags) followed by a blank
      # line and then the message text on its own - since entries can
      # run to multiple paragraphs, keeping the text visually separate
      # from the metadata makes longer threads much easier to read.
      def format_message_block(message)
        who = message.author ? Inklings.color_name(message.author.name) : "?"
        tags = []
        tags << "gm" if message.is_gm_note == "true"
        tags << Inklings.private_tag_label(message) if message.is_private == "true"
        tags << "private to you" if message.is_personal == "true"
        tag_text = tags.empty? ? "" : " [#{tags.join(", ")}]"

        ref = Inklings.event_ref(inkling, message.seq)
        meta = "##{ref} #{Inklings.format_time(message.created_at, '%m/%d %H:%M')} #{who}#{tag_text}"

        "#{meta}\n\n#{message.text}"
      end

      def format_roll_block(roll)
        who = roll.creator ? Inklings.color_name(roll.creator.name) : "?"
        target_name = roll.target_character ? roll.target_character.name : roll.npc_name
        target_text = target_name.to_s.blank? ? "" : " for #{Inklings.color_name(target_name)}"
        private_tag = roll.private == "true" ? " [private]" : ""
        ref = Inklings.event_ref(inkling, roll.seq)
        "##{ref} #{Inklings.format_time(roll.created_at, '%m/%d %H:%M')} #{who} rolled #{roll.roll_spec}#{target_text}#{private_tag}: #{roll.result}"
      end
    end
  end
end
