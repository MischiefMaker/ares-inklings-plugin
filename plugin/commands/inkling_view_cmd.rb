module AresMUSH
  module Inklings
    # +inkling <id>
    class InklingViewCmd
      include CommandHandler

      attr_accessor :id

      def parse_args
        args = cmd.parse_args(/(?<id>.+)/)
        self.id = trim_arg(args.id)
      end

      def required_args
        [self.id]
      end

      # Memoized so check_valid_inkling, check_can_view, and handle
      # don't each independently re-fetch the same record.
      def inkling
        @inkling ||= Inklings.find_inkling(self.id)
      end

      def check_approved
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if inkling && inkling.character == enactor
        return t('inklings.char_not_approved') unless enactor.is_approved?
        nil
      end

      def check_valid_inkling
        return t('inklings.invalid_id') if !inkling
        return nil
      end

      def check_can_view
        return nil if Inklings.can_view_or_reply?(inkling, enactor)
        t('dispatcher.not_allowed')
      end

      def handle
        Inklings.show_inkling(inkling, enactor, client)
      end
    end
  end
end
