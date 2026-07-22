module AresMUSH
  module Inklings
    # +inkling/needschanges <id>=<feedback>
    #
    # Staff-only. Sends a submitted inkling back to the player: adds
    # the feedback to the thread history, mirrors it as a job comment,
    # and unlocks the thread so the player can revise and resubmit.
    # Deliberately distinct from an ordinary +inkling/advance reply -
    # see Inklings.request_changes and the comment on
    # Inkling#approval_state for why ordinary replies don't do this.
    class InklingNeedsChangesCmd
      include CommandHandler

      attr_accessor :id, :feedback

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.id = args.arg1
        self.feedback = trim_arg(args.arg2)
      end

      # No required_args - see v4 Bug 001 audit; points at the real
      # `help manage_inklings` topic instead of a nonexistent per-switch one.
      def check_valid_format
        return t('dispatcher.invalid_syntax', :cmd => 'manage_inklings') if self.id.blank? || self.feedback.blank?
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

      def check_is_submitted
        # Checks run in alphabetical order by method name, not
        # declaration order, so check_valid_inkling may not have run
        # yet. Bail out quietly here and let check_valid_inkling
        # report the real "invalid ID" error instead of crashing.
        return nil if !inkling
        return nil if inkling.approval_state == "submitted"
        t('inklings.not_submitted_for_review')
      end

      def handle
        Inklings.request_changes(inkling, enactor, self.feedback)
        client.emit_success t('inklings.needs_changes_success')
      end
    end
  end
end
