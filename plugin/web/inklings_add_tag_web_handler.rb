module AresMUSH
  module Inklings
    class InklingsAddTagWebHandler
      def handle(request)
        InklingApi.add_tag(
          request.args["char_id"],
          request.args["inkling_id"],
          request.args["viewer_id"],
          request.args["tag"])
      end
    end
  end
end
