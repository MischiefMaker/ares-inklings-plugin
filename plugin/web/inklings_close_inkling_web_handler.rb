module AresMUSH
  module Inklings
    # cmd "inklings_close_inkling" - closes a thread.
    class InklingsCloseInklingWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.close_inkling(
          request.args["char_id"],
          request.args["inkling_id"],
          request.enactor)
      end
    end
  end
end
