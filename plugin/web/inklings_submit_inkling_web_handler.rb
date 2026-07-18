module AresMUSH
  module Inklings
    # cmd "inklings_submit_inkling" - locks the thread and sends it
    # to staff as a single job (see Inklings.submit_inkling).
    class InklingsSubmitInklingWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.submit_inkling(
          request.args["char_id"],
          request.args["inkling_id"],
          request.enactor)
      end
    end
  end
end
