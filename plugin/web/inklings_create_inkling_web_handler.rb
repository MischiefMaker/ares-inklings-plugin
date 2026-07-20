module AresMUSH
  module Inklings
    # cmd "inklings_create_inkling" - starts a new inkling thread on a profile.
    # Accepts optional shared_with_ids array to share with other characters
    # (web portal only - MUSH commands handle sharing separately via +inkling/share).
    class InklingsCreateInklingWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.create_inkling(
          request.args["char_id"],
          request.enactor,
          request.args["kind"],
          request.args["text"],
          request.args["title"],
          shared_with_ids: request.args["shared_with_ids"])
      end
    end
  end
end
