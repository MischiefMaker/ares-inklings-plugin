module AresMUSH
  module Inklings
    # +inkling/share <id>=<char>,<char>
    # Share an inkling with another player, granting them read and reply
    # access. Only the owning character or staff can share a thread.
    # Particularly useful for secret inklings — e.g. sharing an IC
    # secret with the other party in the secret.
    class InklingShareCmd
      include CommandHandler

      attr_accessor :id, :target_names

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.id = args.arg1
        self.target_names = Inklings.split_list(args.arg2).map { |n| titlecase_arg(n) }
      end

      def required_args
        [self.id] + self.target_names
      end

      # Memoized so check_valid_inkling, check_can_share,
      # check_not_closed, and handle don't each independently re-fetch
      # the same record.
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

      def check_can_share
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
        return nil if !inkling
        return t('inklings.thread_is_closed') if inkling.status == "closed"
        return nil
      end

      def handle
        added = []
        missing = []
        skipped = []

        self.target_names.each do |target_name|
          target = Character.find_one_by_name(target_name)
          if !target
            missing << target_name
            next
          end

          result = Inklings.add_participant(inkling, target, enactor)
          added << target.name if result == :added
          skipped << target.name if result == :already_shared
        end

        if added.empty?
          if missing.any?
            client.emit_failure t('inklings.character_not_found', :name => missing.join(", "))
          else
            client.emit_failure t('inklings.already_shared')
          end
          return
        end

        colored_names = added.uniq.sort.map { |n| Inklings.color_name(n) }.join(", ")
        notice = t('inklings.inkling_shared_multiple', :names => colored_names)
        notice << " #{t('inklings.character_not_found', :name => missing.join(", "))}" if missing.any?
        notice << " #{t('inklings.already_shared_names', :names => skipped.uniq.sort.map { |n| Inklings.color_name(n) }.join(", "))}" if skipped.any?
        client.emit_success notice
      end
    end
  end
end
