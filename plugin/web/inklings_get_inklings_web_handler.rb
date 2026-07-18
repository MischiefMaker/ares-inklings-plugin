module AresMUSH
  module Inklings
    # Web request handler for listing a character's inklings.
    # Registered as cmd "inklings_get_inklings" - see
    # Inklings.get_web_request_handler in plugin/inklings.rb.
    #
    # NOTE ON THIS FILE'S CONVENTION: AresMUSH plugins expose web
    # functionality via handler classes with a handle(request) method
    # (request.cmd / request.args), registered through
    # get_web_request_handler - the same pattern as get_cmd_handler
    # for in-game commands and get_event_handler for events. See
    # https://www.aresmush.com/tutorials/code/plugins.html and
    # https://www.aresmush.com/tutorials/code/web-debug.html. This is
    # DIFFERENT from the REST-style "/api/characters/:id/..." URLs
    # used in this plugin's earlier web portal iteration - those were
    # never actually reachable without a real handler like this one.
    # All the business logic still lives in InklingApi/RollsApi
    # (plugin/public/) - these handler classes are thin adapters that
    # just unpack request.args and call into it.
    class InklingsGetInklingsWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.get_inklings(
          request.args["char_id"],
          request.enactor,
          status_filter: request.args["status"] || "open")
      end
    end
  end
end
