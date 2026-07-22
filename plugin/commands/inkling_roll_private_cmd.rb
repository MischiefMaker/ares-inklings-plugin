module AresMUSH
  module Inklings
    # +inkling/rollprivate <id>=<roll command>
    #
    # Same as +inkling/roll, but marks the roll private (visible only to
    # staff, the roller, and the inkling's owner - see
    # Inklings.can_see_roll?), the MUSH equivalent of the web portal's
    # "Private" roll checkbox. Delegates to RollsApi.add_roll - the same
    # permission, storage, and roll service the web handler
    # (InklingsAddRollWebHandler) already uses - rather than duplicating
    # that logic here, so the two interfaces can't drift apart.
    class InklingRollPrivateCmd
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

      def check_roll_system
        return nil if defined?(FS3Skills) && FS3Skills.respond_to?(:one_shot_roll)
        t('inklings.rolls_not_available')
      end

      def handle
        result = RollsApi.add_roll(
          self.id,
          enactor,
          "player",
          self.roll_command,
          nil,
          nil,
          is_private: true)

        if result[:error]
          client.emit_failure result[:error]
          return
        end

        client.emit_success "#{t('inklings.roll_added')} #{result[:roll][:result]} (private)"
      end
    end
  end
end
