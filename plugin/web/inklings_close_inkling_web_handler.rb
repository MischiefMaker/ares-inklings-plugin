module AresMUSH
  module Inklings
    # cmd "inklings_close_inkling" - closes a thread.
    class InklingsCloseInklingWebHandler
      def handle(request)
        InklingApi.close_inkling(
          request.args["char_id"],
          request.args["inkling_id"],
          request.args["viewer_id"])
      end
    end
  end
end
