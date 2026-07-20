module AresMUSH
  module Inklings
    # cmd "inklings_unlock_inkling" - staff reopens a completed inkling
    # for further editing. See InklingApi.unlock_inkling.
    class InklingsUnlockInklingWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.unlock_inkling(
          request.args["inkling_id"],
          request.enactor)
      end
    end
  end
end
