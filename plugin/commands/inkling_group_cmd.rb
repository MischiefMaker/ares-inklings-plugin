module AresMUSH
  module Inklings
    # +inkling/group <id>=<group>,<group>
    # Stores group specs on the inkling so any character whose group membership
    # matches (now or in the future) automatically has access.
    class InklingGroupCmd
      include CommandHandler

      attr_accessor :id, :group_names

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.id = trim_arg(args.arg1)
        self.group_names = Inklings.split_list(args.arg2)
      end

      # No required_args - see v4 Bug 001 audit; points at the real
      # `help inklings` topic instead of a nonexistent per-switch one.
      def check_valid_format
        return t('dispatcher.invalid_syntax', :cmd => 'inklings') if self.id.blank?
        nil
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
        nil
      end

      def check_can_share
        return nil if Inklings.owner_or_staff?(inkling, enactor)
        t('dispatcher.not_allowed')
      end

      def check_not_closed
        return t('inklings.thread_is_closed') if Inklings.closed?(inkling)
        nil
      end

      def check_groups_provided
        return t('inklings.group_none_given') if self.group_names.empty?
        nil
      end

      def handle
        invalid = self.group_names.reject { |g| Inklings.valid_group_spec?(g) }
        if invalid.any?
          client.emit_failure t('inklings.group_invalid', :name => invalid.join(", "))
          return
        end

        result = Inklings.add_group_share(inkling, self.group_names, enactor)
        if result[:new_specs].empty?
          client.emit_failure t('inklings.group_already_set')
          return
        end

        notice = t('inklings.group_spec_stored', :names => result[:new_specs].join(", "))
        notice << " " + t('inklings.group_notified', :names => result[:notified].map { |n| Inklings.color_name(n) }.join(", ")) if result[:notified].any?
        client.emit_success notice
      end
    end
  end
end
