module AresMUSH
  module Inklings
    # cmd "inklings_create_inkling" - starts a new inkling thread.
    class InklingsCreateInklingWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.create_inkling(
          request.args["char_id"],
          request.enactor,
          request.args["kind"],
          request.args["text"],
          request.args["title"])
      end
    end
  end
end
