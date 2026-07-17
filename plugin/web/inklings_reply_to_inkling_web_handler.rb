module AresMUSH
  module Inklings
    # cmd "inklings_reply_to_inkling" - adds a message to a thread.
    class InklingsReplyToInklingWebHandler
      def handle(request)
        InklingApi.reply_to_inkling(
          request.args["char_id"],
          request.args["inkling_id"],
          request.args["viewer_id"],
          request.args["text"],
          is_private: request.args["is_private"] ? true : false)
      end
    end
  end
end
