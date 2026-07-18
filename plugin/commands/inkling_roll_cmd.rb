module AresMUSH
  module Inklings
    # +inkling/roll <id>=<roll command>
    class InklingRollCmd
      include CommandHandler

      attr_accessor :id, :roll_command

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.id = args.arg1
        self.roll_command = trim_arg(args.arg2)
      end

      def required_args
        [self.id, self.roll_command]
      end

      # Memoized so check_valid_inkling, check_can_roll,
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

      def check_can_roll
        # Checks run in alphabetical order by method name, not
        # declaration order, so check_valid_inkling may not have run
        # yet. Bail out quietly here and let check_valid_inkling report
        # the real "invalid ID" error instead of crashing on nil.
        return nil if !inkling
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if Inklings.is_participant?(inkling, enactor)
        t('dispatcher.not_allowed')
      end

      def check_not_closed
        return nil if !inkling
        return t('inklings.thread_is_closed') if inkling.status == "closed"
        nil
      end

      def check_not_locked
        # Staff always bypass the lock.
        return nil if !inkling
        return nil if Inklings.can_manage_inklings?(enactor)
        return t('inklings.thread_is_locked') if inkling.locked == "true"
        nil
      end

      def check_roll_system
        return nil if defined?(FS3Skills) && FS3Skills.respond_to?(:parse_and_roll)
        t('inklings.rolls_not_available')
      end

      def handle
        target_name = nil
        roll_str = self.roll_command
        if self.roll_command.include?("/")
          target_name, roll_str = self.roll_command.split("/", 2).map(&:strip)
          target_name = titlecase_arg(target_name)
        end

        target = target_name.blank? ? enactor : Character.find_one_by_name(target_name)
        if !target
          client.emit_failure t('inklings.roll_target_not_found', :name => target_name)
          return
        end

        if !Inklings.can_manage_inklings?(enactor) && target.id != enactor.id
          client.emit_failure t('dispatcher.not_allowed')
          return
        end

        die_result = FS3Skills.parse_and_roll(target, roll_str)
        if !die_result
          client.emit_failure t('inklings.invalid_roll_command')
          return
        end

        success_level = FS3Skills.get_success_level(die_result)
        success_title = FS3Skills.get_success_title(success_level)
        result_text = "#{FS3Skills.print_dice(die_result)} => #{success_title}"

        InklingRoll.create(
          inkling: inkling,
          character: target,
          target_character: target,
          creator: enactor,
          roll_type: "player",
          roll_spec: roll_str,
          result: result_text,
          result_value: success_level,
          seq: Inklings.next_event_seq(inkling),
          private: "false",
          reroll_count: "0",
          luck_cost: "0",
          created_at: Time.now,
          rolled_at: Time.now)

        client.emit_success "#{t('inklings.roll_added')} #{result_text}"
      end
    end
  end
end
