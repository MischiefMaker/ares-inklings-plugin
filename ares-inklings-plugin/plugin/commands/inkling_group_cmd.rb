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

      def check_approved
        return nil if Inklings.can_manage_inklings?(enactor)
        return t('inklings.char_not_approved') unless enactor.is_approved?
        nil
      end

      def check_valid_inkling
        return t('inklings.invalid_id') if !Inklings.find_inkling(self.id)
        nil
      end

      def check_can_share
        inkling = Inklings.find_inkling(self.id)
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
        inkling = Inklings.find_inkling(self.id)
        return nil if !inkling
        return t('inklings.thread_is_closed') if inkling.status == "closed"
        nil
      end

      def check_groups_provided
        return t('inklings.group_none_given') if self.group_names.empty?
        nil
      end

      def handle
        inkling = Inklings.find_inkling(self.id)

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
        inkling.update(shared_groups: combined)

        # Notify currently-approved characters who match the new specs.
        notified = []
        new_specs.each do |spec|
          Character.all.to_a.select { |c|
            c.is_approved? &&
              c.id != enactor.id &&
              !Inklings.is_participant_explicit?(inkling, c) &&
              Inklings.char_matches_group_spec?(c, spec)
          }.each do |char|
            Inklings.notify_player(char,
              "<inklings> #{enactor.name} has shared an inkling with your group. Use +inkling #{inkling.id} to view it.")
            notified << char.name
          end
        end

        notice = t('inklings.group_spec_stored', :names => new_specs.join(", "))
        notice << " " + t('inklings.group_notified', :names => notified.uniq.sort.join(", ")) if notified.any?
        client.emit_success notice
      end
    end
  end
end
