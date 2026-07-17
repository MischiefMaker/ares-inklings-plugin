module AresMUSH
  module Inklings
    # +inkling/approve <id>
    # +inkling/approve <id>=<message>
    #
    # Staff-only. The single source of truth for approval: staff
    # approve the INKLING, which closes the linked job as a
    # consequence (via the same Jobs.close_job API +inkling/close
    # already uses). There is no separate "approve the job" action
    # for staff to keep in sync with this one - see
    # Inklings.approve_inkling.
    class InklingApproveCmd
      include CommandHandler

      attr_accessor :id, :message

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.id = args.arg1
        self.message = trim_arg(args.arg2)
      end

      def required_args
        [self.id]
      end

      # Memoized so the checks below and handle don't each
      # independently re-fetch the same record.
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
        Inklings.approve_inkling(inkling, enactor, self.message)
        client.emit_success t('inklings.approved_success')
      end
    end
  end
end
