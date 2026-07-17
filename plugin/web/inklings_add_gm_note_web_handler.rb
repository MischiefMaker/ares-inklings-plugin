module AresMUSH
  module Inklings
    class InklingsAddGmNoteWebHandler
      def handle(request)
        InklingApi.add_gm_note(
          request.args["char_id"],
          request.args["inkling_id"],
          request.args["viewer_id"],
          request.args["text"])
      end
    end
  end
end
