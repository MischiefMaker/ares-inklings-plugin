module AresMUSH
  module Inklings
    # Web request handler for the admin "every inkling in the game" list.
    # Registered as cmd "inklings_list_all" - see
    # Inklings.get_web_request_handler in plugin/inklings.rb.
    #
    # manage_inklings authorization happens inside InklingApi.list_all_inklings
    # itself, not here - see the note on InklingsGetInklingsWebHandler for why
    # these handlers stay thin adapters and push authorization into the
    # public/*_api.rb layer (the single source of truth shared with the
    # MUSH command, InklingAdminCmd).
    class InklingsListAllWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.list_all_inklings(
          request.enactor,
          status_filter: request.args["status"] || "open",
          page: request.args["page"] || 1)
      end
    end
  end
end
