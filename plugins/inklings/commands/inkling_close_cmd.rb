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

      def check_valid_inkling
        return t('inklings.invalid_id') if !Inklings.find_inkling(self.id)
        return nil
      end

      def check_can_close
        inkling = Inklings.find_inkling(self.id)
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if inkling.character == enactor
        return t('dispatcher.not_allowed')
      end

      def handle
        inkling = Inklings.find_inkling(self.id)
        inkling.update(status: "closed")

        if inkling.job
          Jobs.close_job(enactor, inkling.job, t('inklings.closed_via_inkling'))
        end

        client.emit_success t('inklings.thread_closed_msg')
      end
    end
  end
end
