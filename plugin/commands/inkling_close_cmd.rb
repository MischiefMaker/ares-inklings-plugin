module AresMUSH
  module Inklings
    # +inkling/close <id>
    class InklingCloseCmd
      include CommandHandler

      attr_accessor :id

      def parse_args
        self.id = cmd.args
      end

      def required_args
        [self.id]
      end

      # Memoized so check_valid_inkling, check_can_close, and handle
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

      def check_can_close
        return nil if Inklings.owner_or_staff?(inkling, enactor)
        t('dispatcher.not_allowed')
      end

      def handle
        Inklings.update_inkling(inkling, status: "closed")

        if inkling.job
          Jobs.close_job(enactor, inkling.job, t('inklings.closed_via_inkling'))
        end

        client.emit_success t('inklings.thread_closed_msg')
      end
    end
  end
end
