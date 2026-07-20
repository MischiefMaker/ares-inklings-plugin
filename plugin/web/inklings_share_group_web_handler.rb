module AresMUSH
  module Inklings
    # cmd "inklings_share_group" - grants access to everyone whose
    # demographics group membership matches a spec (now or in the future).
    class InklingsShareGroupWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.share_group(
          request.args["char_id"],
          request.args["inkling_id"],
          request.enactor,
          request.args["group_spec"])
      end
    end
  end
end
