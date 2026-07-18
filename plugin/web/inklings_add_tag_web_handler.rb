module AresMUSH
  module Inklings
    class InklingsAddTagWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.add_tag(
          request.args["char_id"],
          request.args["inkling_id"],
          request.enactor,
          request.args["tag"])
      end
    end
  end
end
