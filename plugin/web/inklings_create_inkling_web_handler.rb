module AresMUSH
  module Inklings
    # cmd "inklings_create_inkling" - starts a new inkling thread.
    class InklingsCreateInklingWebHandler
      def handle(request)
        InklingApi.create_inkling(
          request.args["char_id"],
          request.args["viewer_id"],
          request.args["kind"],
          request.args["text"],
          request.args["title"])
      end
    end
  end
end
