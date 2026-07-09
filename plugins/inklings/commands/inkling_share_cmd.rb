module AresMUSH
  module Inklings
    # +inkling/share <id>=<char>
    # Share an inkling with another player, granting them read and reply
    # access. Only the owning character or staff can share a thread.
    # Particularly useful for secret inklings — e.g. sharing an IC
    # secret with the other party in the secret.
    class InklingShareCmd
      include CommandHandler

      attr_accessor :id, :target_name

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.id = args.arg1
        self.target_name = titlecase_arg(args.arg2)
      end

      def required_args
        [self.id, self.target_name]
      end

      def check_approved
        return nil if Inklings.can_manage_inklings?(enactor)
        return t('inklings.char_not_approved') unless enactor.is_approved?
        nil
      end

      def check_valid_inkling
        return t('inklings.invalid_id') if !Inklings.find_inkling(self.id)
        return nil
      end

      def check_can_share
        inkling = Inklings.find_inkling(self.id)
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if inkling.character == enactor
        return t('dispatcher.not_allowed')
      end

      def check_not_closed
        inkling = Inklings.find_inkling(self.id)
        return t('inklings.thread_is_closed') if inkling.status == "closed"
        return nil
      end

      def handle
        inkling = Inklings.find_inkling(self.id)
        ClassTargetFinder.with_a_character(self.target_name, client, enactor) do |target|
          if Inklings.is_participant?(inkling, target)
            client.emit_failure t('inklings.already_shared')
            next
          end

          InklingParticipant.create(
            inkling: inkling,
            character: target,
            added_at: Time.now)

          client.emit_success t('inklings.inkling_shared', :name => target.name)
          Inklings.notify_player(target, t('inklings.shared_notice',
            :name => enactor.name, :id => inkling.id))
        end
      end
    end
  end
end
