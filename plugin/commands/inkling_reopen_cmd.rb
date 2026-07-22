module AresMUSH
  module Inklings
    # +inkling/reopen <id>
    # Staff-only. Restores a closed inkling to "open" - see
    # Inklings.reopen_inkling for what that does and doesn't touch.
    class InklingReopenCmd
      include CommandHandler

      attr_accessor :id

      def parse_args
        self.id = cmd.args
      end

      # No required_args - see v4 Bug 001 audit; points at the real
      # `help manage_inklings` topic instead of a nonexistent per-switch one.
      def check_valid_format
        return t('dispatcher.invalid_syntax', :cmd => 'manage_inklings') if self.id.blank?
        nil
      end

      # Memoized so the checks below and handle don't each independently
      # re-fetch the same record.
      def inkling
        @inkling ||= Inklings.find_inkling(self.id)
      end

      def check_valid_inkling
        return t('inklings.invalid_id') if !inkling
        nil
      end

      def check_permission
        return nil if Inklings.can_manage_inklings?(enactor)
        t('dispatcher.not_allowed')
      end

      def check_is_closed
        return nil if !inkling
        return t('inklings.inkling_not_closed') unless Inklings.closed?(inkling)
        nil
      end

      def handle
        Inklings.reopen_inkling(inkling, enactor)
        client.emit_success t('inklings.reopen_success')
      end
    end
  end
end
