module AresMUSH
  module Inklings
    # cmd "inklings_share_inkling" - grants a character access.
    class InklingsShareInklingWebHandler
      def handle(request)
        InklingApi.share_inkling(
          request.args["char_id"],
          request.args["inkling_id"],
          request.args["viewer_id"],
          request.args["target_name"])
      end
    end
  end
end
