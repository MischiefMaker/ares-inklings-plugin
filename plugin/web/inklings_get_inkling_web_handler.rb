module AresMUSH
  module Inklings
    # cmd "inklings_get_inkling" - fetches one inkling's full detail.
    class InklingsGetInklingWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.get_inkling(
          request.args["char_id"],
          request.args["inkling_id"],
          request.enactor)
      end
    end
  end
end
