module AresMUSH
  module Inklings
    # cmd "inklings_share_inkling" - grants a character access.
    class InklingsShareInklingWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.share_inkling(
          request.args["char_id"],
          request.args["inkling_id"],
          request.enactor,
          request.args["target_name"])
      end
    end
  end
end
