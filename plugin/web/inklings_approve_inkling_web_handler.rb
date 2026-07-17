module AresMUSH
  module Inklings
    class InklingsApproveInklingWebHandler
      def handle(request)
        InklingApi.approve_inkling(
          request.args["inkling_id"],
          request.args["viewer_id"],
          request.args["message"])
      end
    end
  end
end
