module AresMUSH
  module Inklings
    class InklingsSearchWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.search(
          request.args["query"],
          request.enactor,
          request.args["page"] || 1)
      end
    end
  end
end
