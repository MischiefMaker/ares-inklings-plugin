module AresMUSH
  module Inklings
    class InklingsReopenInklingWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.reopen_inkling(
          request.args["inkling_id"],
          request.enactor)
      end
    end
  end
end
