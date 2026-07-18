module AresMUSH
  module Inklings
    class InklingsApproveInklingWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.approve_inkling(
          request.args["inkling_id"],
          request.enactor,
          request.args["message"])
      end
    end
  end
end
