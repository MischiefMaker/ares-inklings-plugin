module AresMUSH
  module Inklings
    # cmd "inklings_submit_inkling" - locks the thread and sends it
    # to staff as a single job (see Inklings.submit_inkling).
    class InklingsSubmitInklingWebHandler
      def handle(request)
        InklingApi.submit_inkling(
          request.args["char_id"],
          request.args["inkling_id"],
          request.args["viewer_id"])
      end
    end
  end
end
