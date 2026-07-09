module AresMUSH
  module Inklings
    # +inkling/advance <id>=<text>
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

      def check_approved
        return nil if Inklings.can_manage_inklings?(enactor)
        return t('inklings.char_not_approved') unless enactor.is_approved?
        nil
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

        # Auto-private: if staff are replying and the last message in the
        # thread is private, inherit its privacy and recipients automatically.
        auto_private = false
        auto_recipients = ""
        if is_staff
          last_msg = inkling.messages.to_a.sort_by { |m| m.created_at }.last
          if last_msg && last_msg.is_private.to_s == "true"
            auto_private = true
            auto_recipients = last_msg.private_recipient_ids.to_s.presence ||
              (last_msg.author ? last_msg.author.id : inkling.character.id)
          end
        end

        job_text = auto_private ? "[Private] #{self.text}" : self.text

        InklingMessage.create(
          inkling: inkling,
          author: enactor,
          text: self.text,
          created_at: Time.now,
          is_staff: is_staff ? "true" : "false",
          is_private: auto_private ? "true" : "false",
          is_gm_note: "false",
          private_recipient_ids: auto_recipients)

        if is_staff
          inkling.update(player_unread: "true")
          Inklings.mirror_to_job(inkling, job_text, enactor)
          Inklings.notify_player(inkling.character, t('inklings.new_message_notice'))
        else
          Inklings.ensure_job(inkling,
            "#{enactor.name} replied - #{t("inklings.kind_#{inkling.kind}")}",
            self.text, enactor)
        end

        notice = auto_private ? t('inklings.advance_added_auto_private') : t('inklings.advance_added')
        client.emit_success notice
      end
    end
  end
end
