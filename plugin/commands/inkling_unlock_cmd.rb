module AresMUSH
  module Inklings
    # +inkling/unlock <id>
    # Staff-only. Unlocks a completed inkling, setting it back to needs_changes
    # so the player can edit it again.
    class InklingUnlockCmd
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

      def check_is_completed
        return nil if !inkling
        return t('inklings.inkling_not_completed') unless inkling.approval_state == "approved"
        nil
      end

      def check_is_locked
        return nil if !inkling
        return t('inklings.inkling_not_locked') unless inkling.locked == "true"
        nil
      end

      def handle
        Inklings.unlock_inkling(inkling, enactor)
        client.emit_success t('inklings.unlock_success')
      end
    end
  end
end
