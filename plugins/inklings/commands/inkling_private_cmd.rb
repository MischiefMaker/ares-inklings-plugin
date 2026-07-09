module AresMUSH
  module Inklings
    # +inkling/private <id>=<text>
    # Adds a private entry to an inkling thread. Private entries are
    # visible only to the author and staff, regardless of who else
    # participates in the thread.
    class InklingPrivateCmd
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
          is_staff: is_staff ? "true" : "false",
          is_private: "true")

        if is_staff
          inkling.update(player_unread: "true")
          Inklings.mirror_to_job(inkling, "[Private] #{self.text}", enactor)
          Inklings.notify_player(inkling.character, t('inklings.new_message_notice'))
        else
          Inklings.ensure_job(inkling,
            "#{enactor.name} private reply - #{t("inklings.kind_#{inkling.kind}")}",
            "[Private] #{self.text}", enactor)
        end

        client.emit_success t('inklings.private_reply_added')
      end
    end
  end
end
