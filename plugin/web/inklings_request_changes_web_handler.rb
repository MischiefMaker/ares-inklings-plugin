module AresMUSH
  module Inklings
    class InklingsRequestChangesWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.request_changes_inkling(
          request.args["inkling_id"],
          request.enactor,
          request.args["feedback"])
      end
    end
  end
end
