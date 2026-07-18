module AresMUSH
  module Inklings
    # cmd "inklings_reroll_with_luck" - spends luck to reroll an
    # existing roll. See RollsApi.reroll_with_luck.
    #
    # NOTE: this plugin doesn't compute the actual reroll result
    # itself - that's expected to come from your game's own FS3/luck
    # roll endpoint (the web portal's inklings-tab component calls its
    # own character roll action for that first, then passes the
    # result here). This handler just persists whatever result it's
    # given and deducts the character's luck.
    class InklingsRerollWithLuckWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        RollsApi.reroll_with_luck(
          request.args["inkling_id"],
          request.args["roll_id"],
          request.enactor,
          request.args["new_result"],
          request.args["new_result_value"],
          request.args["luck_cost"])
      end
    end
  end
end
