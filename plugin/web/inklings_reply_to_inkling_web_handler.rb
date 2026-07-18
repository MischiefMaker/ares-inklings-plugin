module AresMUSH
  module Inklings
    # cmd "inklings_reply_to_inkling" - adds a message to a thread.
    class InklingsReplyToInklingWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.reply_to_inkling(
          request.args["char_id"],
          request.args["inkling_id"],
          request.enactor,
          request.args["text"],
          is_private: request.args["is_private"] ? true : false,
          is_personal: request.args["is_personal"] ? true : false)
      end
    end
  end
end
