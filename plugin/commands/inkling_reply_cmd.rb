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

      # Memoized so check_valid_inkling, check_can_reply,
      # check_not_closed, and handle don't each independently re-fetch
      # the same record.
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

      def check_can_reply
        return nil if Inklings.can_view_or_reply?(inkling, enactor)
        t('dispatcher.not_allowed')
      end

      def check_not_closed
        return t('inklings.thread_is_closed') if Inklings.closed?(inkling)
        nil
      end

      def check_not_locked
        # Checks run in alphabetical order by method name, not
        # declaration order, so check_valid_inkling may not have run
        # yet. Staff always bypass the lock - it's their reply that
        # clears it in the first place.
        return nil if !inkling
        return nil if Inklings.can_manage_inklings?(enactor)
        return t('inklings.thread_is_locked') if inkling.locked == "true"
        nil
      end

      def handle
        is_staff = Inklings.can_manage_inklings?(enactor)

        # Auto-private: if staff are replying and the last message in the
        # thread is private, inherit its privacy and recipients automatically.
        auto_private = false
        auto_recipients = ""
        if is_staff
          last_msg = inkling.messages.to_a.sort_by { |m| Inklings.time_value(m.created_at) }.last
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
          seq: Inklings.next_event_seq(inkling),
          is_staff: is_staff ? "true" : "false",
          is_private: auto_private ? "true" : "false",
          is_gm_note: "false",
          is_personal: "false",
          private_recipient_ids: auto_recipients)

        if is_staff
          # Ordinary staff replies do not change the lock state.
          # Only +inkling/approve (locks) and +inkling/needschanges (unlocks)
          # change it - a reply is not the same as a decision.
          Inklings.update_inkling(inkling, player_unread: "true")
          Inklings.mirror_to_job(inkling, job_text, enactor)
          Inklings.notify_new_message(inkling.character, inkling)
        end

        notice = auto_private ? t('inklings.advance_added_auto_private') : t('inklings.advance_added')
        notice << " #{t('inklings.not_yet_submitted_notice', :id => inkling.id)}" unless is_staff
        client.emit_success notice
      end
    end
  end
end
