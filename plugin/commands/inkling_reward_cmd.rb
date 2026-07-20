module AresMUSH
  module Inklings
    # +inkling/reward <id>=<reward_type>:<amount>
    # +inkling/reward <id>=<reward_type>:<reward_key>:<amount>
    # +inkling/reward <id>/all=<reward_spec>  (all = visible to all participants)
    #
    # Staff-only. Grants a reward to the inkling's subject character,
    # recording it in the inkling history and applying it if the system
    # knows how (e.g. XP via FS3Skills). See Inklings.grant_reward.
    class InklingRewardCmd
      include CommandHandler

      attr_accessor :id, :all_visible, :reward_spec

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)

        # Check for /all suffix on ID
        id_parts = args.arg1.split("/")
        self.id = id_parts[0]
        self.all_visible = id_parts.length > 1 && id_parts[1].downcase == "all"

        self.reward_spec = args.arg2
      end

      def required_args
        [self.id, self.reward_spec]
      end

      def inkling
        @inkling ||= Inklings.find_inkling(self.id)
      end

      def check_valid_inkling
        return t('inklings.invalid_id') if !inkling
        nil
      end

      def check_permission
        return nil if Inklings.can_manage_inklings?(enactor)
        t('dispatcher.not_allowed')
      end

      def check_not_closed
        return t('inklings.thread_is_closed') if Inklings.closed?(inkling)
        nil
      end

      def check_valid_reward_spec
        parts = self.reward_spec.split(":")
        return t('inklings.invalid_reward_spec') if parts.length < 2 || parts.length > 3
        nil
      end

      def handle
        parts = self.reward_spec.split(":")

        reward_type = parts[0]
        reward_key = parts.length == 3 ? parts[1] : ""
        amount = parts.length == 3 ? parts[2] : parts[1]

        visibility = self.all_visible ? "all" : "private"

        Inklings.grant_reward(inkling, inkling.character, enactor, reward_type, reward_key, amount, visibility: visibility)

        client.emit_success t('inklings.reward_granted', :type => reward_type, :amount => amount)
      end
    end
  end
end
