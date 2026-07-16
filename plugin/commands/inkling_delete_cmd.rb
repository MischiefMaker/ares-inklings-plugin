module AresMUSH
  module Inklings
    # +inkling/delete <id>
    #
    # Staff can still delete any thread outright and immediately.
    #
    # Players can no longer delete their own thread directly. Instead,
    # this closes the thread and files a job asking staff to review and
    # approve a permanent deletion. A staff member who approves the
    # request then runs this same command themselves (as staff) to
    # actually carry out the permanent delete.
    class InklingDeleteCmd
      include CommandHandler

      attr_accessor :id

      def parse_args
        self.id = cmd.args
      end

      def required_args
        [self.id]
      end

      # Memoized so check_valid_inkling, check_can_delete, and handle
      # don't each independently re-fetch the same record.
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

      def check_can_delete
        # Checks run in alphabetical order by method name, not
        # declaration order, so check_valid_inkling may not have run
        # yet. Bail out quietly here and let check_valid_inkling report
        # the real "invalid ID" error instead of crashing on nil.
        return nil if !inkling
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if inkling.character == enactor
        return t('dispatcher.not_allowed')
      end

      def handle
        if Inklings.can_manage_inklings?(enactor)
          inkling.messages.each { |m| m.delete }
          inkling.rolls.each { |r| r.delete }
          InklingParticipant.find(inkling_id: inkling.id).each { |p| p.delete }
          inkling.delete

          client.emit_success t('inklings.inkling_deleted')
          return
        end

        # Player path: close the thread and request staff approval
        # rather than deleting outright.
        inkling.update(status: "closed")

        transcript = inkling.messages.map { |m| "#{m.author ? m.author.name : "?"}: #{m.text}" }.join(" / ")
        Inklings.ensure_job(inkling,
          Inklings.deletion_request_title(enactor, inkling.id),
          t('inklings.deletion_request_body', :text => transcript),
          enactor)

        client.emit_success t('inklings.deletion_requested')
      end
    end
  end
end
