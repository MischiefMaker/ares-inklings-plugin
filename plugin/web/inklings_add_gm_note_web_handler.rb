module AresMUSH
  module Inklings
    class InklingsAddGmNoteWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.add_gm_note(
          request.args["char_id"],
          request.args["inkling_id"],
          request.enactor,
          request.args["text"])
      end
    end
  end
end
