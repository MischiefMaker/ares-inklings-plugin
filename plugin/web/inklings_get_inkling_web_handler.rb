module AresMUSH
  module Inklings
    # cmd "inklings_get_inkling" - fetches one inkling's full detail.
    class InklingsGetInklingWebHandler
      def handle(request)
        InklingApi.get_inkling(
          request.args["char_id"],
          request.args["inkling_id"],
          request.args["viewer_id"])
      end
    end
  end
end
