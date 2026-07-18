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

      def required_args
        [self.id]
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

      def handle
        Inklings.unlock_inkling(inkling, enactor)
        client.emit_success t('inklings.unlock_success')
      end
    end
  end
end
