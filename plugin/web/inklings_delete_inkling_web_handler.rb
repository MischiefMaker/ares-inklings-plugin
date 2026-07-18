module AresMUSH
  module Inklings
    # cmd "inklings_delete_inkling" - staff delete outright, or a
    # player deletion request (see InklingApi.delete_inkling).
    class InklingsDeleteInklingWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.delete_inkling(
          request.args["char_id"],
          request.args["inkling_id"],
          request.enactor)
      end
    end
  end
end
