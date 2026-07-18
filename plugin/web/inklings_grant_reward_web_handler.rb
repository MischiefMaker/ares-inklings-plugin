module AresMUSH
  module Inklings
    class InklingsGrantRewardWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.grant_inkling_reward(
          request.args["inkling_id"],
          request.enactor,
          request.args["reward_type"],
          request.args["reward_key"],
          request.args["amount"])
      end
    end
  end
end
