module AresMUSH
  module Inklings
    # +inkling/submit <id>
    #
    # Locks the inkling and sends its full current contents to a
    # single staff job for review. Building up a thread (replies,
    # rolls) does NOT notify staff or create a job by itself - nothing
    # reaches staff until this command is run. See
    # Inklings.submit_inkling for what "locks" and "a single job"
    # actually mean.
    class InklingSubmitCmd
      include CommandHandler

      attr_accessor :id

      def parse_args
        self.id = cmd.args
      end

      # No required_args - see v4 Bug 001 audit; points at the real
      # `help inklings` topic instead of a nonexistent per-switch one.
      def check_valid_format
        return t('dispatcher.invalid_syntax', :cmd => 'inklings') if self.id.blank?
        nil
      end

      # Memoized so the checks below and handle don't each
      # independently re-fetch the same record.
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

      def check_can_submit
        # Checks run in alphabetical order by method name, not
        # declaration order, so check_valid_inkling may not have run
        # yet. Bail out quietly here and let check_valid_inkling report
        # the real "invalid ID" error instead of crashing on nil.
        return nil if !inkling
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if inkling.character == enactor
        return t('dispatcher.not_allowed')
      end

      def check_not_closed
        return t('inklings.thread_is_closed') if Inklings.closed?(inkling)
        nil
      end

      def check_not_already_locked
        return nil if !inkling
        return t('inklings.already_submitted') if inkling.locked == "true"
        nil
      end

      def handle
        result = Inklings.submit_inkling(inkling, enactor)
        if result[:error]
          client.emit_failure result[:error]
          return
        end
        client.emit_success t('inklings.submitted_success')
      end
    end
  end
end
