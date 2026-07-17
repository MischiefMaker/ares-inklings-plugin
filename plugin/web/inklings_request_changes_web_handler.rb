module AresMUSH
  module Inklings
    class InklingsRequestChangesWebHandler
      def handle(request)
        InklingApi.request_changes_inkling(
          request.args["inkling_id"],
          request.args["viewer_id"],
          request.args["feedback"])
      end
    end
  end
end
