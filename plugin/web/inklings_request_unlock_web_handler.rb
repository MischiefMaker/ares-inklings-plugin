module AresMUSH
  module Inklings
    # cmd "inklings_request_unlock" - player asks staff to reopen a
    # completed inkling. Does not unlock it - see InklingApi.request_unlock_inkling.
    class InklingsRequestUnlockWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.request_unlock_inkling(
          request.args["char_id"],
          request.args["inkling_id"],
          request.enactor,
          request.args["reason"])
      end
    end
  end
end
