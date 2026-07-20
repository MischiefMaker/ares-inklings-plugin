module AresMUSH
  module Inklings
    # Web request handler for the admin page's Add Inkling flow, which
    # picks an owner by character name (matching the core Jobs plugin's
    # own single-select submission convention) and, optionally, an
    # access list by character id (matching Jobs' own multi-select
    # convention) rather than assuming the logged-in player. Registered
    # as cmd "inklings_create_inkling_by_name" - see
    # Inklings.get_web_request_handler in plugin/inklings.rb.
    class InklingsCreateInklingByNameWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.create_inkling_by_name(
          request.args["owner_name"],
          request.enactor,
          request.args["kind"],
          request.args["text"],
          request.args["title"],
          shared_with_ids: request.args["shared_with_ids"])
      end
    end
  end
end
