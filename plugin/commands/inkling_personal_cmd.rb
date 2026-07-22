module AresMUSH
  module Inklings
    # +inkling/personal <id>=<text>
    # Add a personal (author-only) entry to an inkling thread.
    class InklingPersonalCmd
      include CommandHandler

      attr_accessor :id, :text

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.id = args.arg1
        self.text = args.arg2
      end

      # No required_args - see v4 Bug 001 audit; points at the real
      # `help inklings` topic instead of a nonexistent per-switch one.
      def check_valid_format
        return t('dispatcher.invalid_syntax', :cmd => 'inklings') if self.id.blank? || self.text.blank?
        nil
      end

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

      def handle
        is_staff = Inklings.can_manage_inklings?(enactor)

        InklingMessage.create(
          inkling: inkling,
          author: enactor,
          text: self.text,
          created_at: Time.now,
          seq: Inklings.next_event_seq(inkling),
          is_staff: is_staff ? "true" : "false",
          is_private: "false",
          is_gm_note: "false",
          is_personal: "true",
          private_recipient_ids: "")

        unless is_staff
          Inklings.update_inkling(inkling, player_unread: "false")
        end

        notice = t('inklings.personal_entry_added')
        notice << " #{t('inklings.not_yet_submitted_notice', :id => inkling.id)}" unless is_staff
        client.emit_success notice
        client.emit t('inklings.personal_entry_warning')
      end
    end
  end
end
