module AresMUSH
  module Inklings
    # +inkling/reply <id>=<text>
    class InklingReplyCmd
      include CommandHandler

      attr_accessor :id, :text

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.id = args.arg1
        self.text = args.arg2
      end

      def required_args
        [self.id, self.text]
      end

      def check_valid_inkling
        return t('inklings.invalid_id') if !Inklings.find_inkling(self.id)
        return nil
      end

      def check_can_reply
        inkling = Inklings.find_inkling(self.id)
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if Inklings.is_participant?(inkling, enactor)
        return t('dispatcher.not_allowed')
      end

      def check_not_closed
        inkling = Inklings.find_inkling(self.id)
        return t('inklings.thread_is_closed') if inkling.status == "closed"
        return nil
      end

      def handle
        inkling = Inklings.find_inkling(self.id)
        is_staff = Inklings.can_manage_inklings?(enactor)

        InklingMessage.create(
          inkling: inkling,
          author: enactor,
          text: self.text,
          created_at: Time.now,
          is_staff: is_staff ? "true" : "false")

        if is_staff
          inkling.update(player_unread: "true")
          # Only mirrors if a job already exists - a staff reply on a
          # thread that's never needed staff attention shouldn't spawn one.
          Inklings.mirror_to_job(inkling, self.text, enactor)
          Inklings.notify_player(inkling.character, t('inklings.new_message_notice'))
        else
          # Player replied - staff need to know, creating a job if this
          # thread doesn't already have one.
          Inklings.ensure_job(inkling,
            "#{enactor.name} replied - #{t("inklings.kind_#{inkling.kind}")}",
            self.text, enactor)
        end

        client.emit_success t('inklings.reply_added')
      end
    end
  end
end
