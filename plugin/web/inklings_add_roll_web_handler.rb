module AresMUSH
  module Inklings
    # cmd "inklings_add_roll" - attaches a roll to a thread. See
    # RollsApi.add_roll for the roll_type/npc_name/etc. semantics.
    class InklingsAddRollWebHandler
      def handle(request)
        RollsApi.add_roll(
          request.args["inkling_id"],
          request.args["viewer_id"],
          request.args["roll_type"],
          request.args["roll_spec"],
          request.args["result"],
          request.args["result_value"],
          npc_char_id: request.args["npc_char_id"],
          npc_name: request.args["npc_name"],
          is_private: request.args["is_private"] ? true : false)
      end
    end
  end
end
