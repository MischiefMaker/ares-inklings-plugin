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

      def required_args
        [self.id]
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
        # Checks run in alphabetical order by method name, not
        # declaration order, so check_valid_inkling may not have run
        # yet. Bail out quietly here and let check_valid_inkling report
        # the real "invalid ID" error instead of crashing on nil.
        return nil if !inkling
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if inkling.character == enactor
        t('dispatcher.not_allowed')
      end

      def check_not_closed
        return nil if !inkling
        return t('inklings.thread_is_closed') if inkling.status == "closed"
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

        existing_specs = Inklings.split_list(inkling.shared_groups)
        new_specs = self.group_names.reject { |g|
          existing_specs.any? { |e| e.downcase == g.downcase }
        }

        if new_specs.empty?
          client.emit_failure t('inklings.group_already_set')
          return
        end

        combined = (existing_specs + new_specs).uniq.join(",")
        Inklings.update_inkling(inkling, shared_groups: combined)

        # Notify currently-approved characters who match the new specs.
        # char_matches_group_spec? is checked before
        # is_participant_explicit? since it's pure computation with no
        # DB round-trip, letting it eliminate most candidates before
        # the pricier explicit-participant lookup runs.
        notified = []
        new_specs.each do |spec|
          Character.all.to_a.select { |c|
            c.is_approved? &&
              c.id != enactor.id &&
              Inklings.char_matches_group_spec?(c, spec) &&
              !Inklings.is_participant_explicit?(inkling, c)
          }.each do |char|
            Inklings.notify_shared(char, inkling, enactor.name, with_group: true)
            notified << char.name
          end
        end

        notice = t('inklings.group_spec_stored', :names => new_specs.join(", "))
        notice << " " + t('inklings.group_notified', :names => notified.uniq.sort.map { |n| Inklings.color_name(n) }.join(", ")) if notified.any?
        client.emit_success notice
      end
    end
  end
end
