module AresMUSH
  module Inklings
    # +inkling/requestunlock <id>=<reason>
    # Player command. Requests that staff reopen a completed inkling.
    # Does NOT unlock it - just records the request and notifies staff.
    class InklingRequestUnlockCmd
      include CommandHandler

      attr_accessor :id, :reason

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.id = args.arg1
        self.reason = trim_arg(args.arg2)
      end

      # No required_args - see v4 Bug 001 audit; points at the real
      # `help inklings` topic instead of a nonexistent per-switch one.
      def check_valid_format
        return t('dispatcher.invalid_syntax', :cmd => 'inklings') if self.id.blank? || self.reason.blank?
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
        nil
      end

      def check_can_request
        return nil if !inkling
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if inkling.character == enactor
        return t('dispatcher.not_allowed')
      end

      def check_is_completed
        return nil if !inkling
        return t('inklings.inkling_not_completed') unless inkling.approval_state == "approved"
        nil
      end

      def handle
        Inklings.request_unlock(inkling, enactor, self.reason)
        client.emit_success t('inklings.unlock_request_sent')
      end
    end
  end
end
