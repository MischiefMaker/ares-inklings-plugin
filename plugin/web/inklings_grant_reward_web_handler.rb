module AresMUSH
  module Inklings
    class InklingsGrantRewardWebHandler
      def handle(request)
        InklingApi.grant_inkling_reward(
          request.args["inkling_id"],
          request.args["viewer_id"],
          request.args["reward_type"],
          request.args["reward_key"],
          request.args["amount"])
      end
    end
  end
end
