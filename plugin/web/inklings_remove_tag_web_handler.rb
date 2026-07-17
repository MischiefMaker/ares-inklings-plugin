module AresMUSH
  module Inklings
    class InklingsRemoveTagWebHandler
      def handle(request)
        InklingApi.remove_tag(
          request.args["char_id"],
          request.args["inkling_id"],
          request.args["viewer_id"],
          request.args["tag"])
      end
    end
  end
end
