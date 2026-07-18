module AresMUSH
  module Inklings
    # cmd "inklings_get_types" - the live type list (name,
    # description, category), sourced from game/config/inklings.yml -
    # see InklingApi.get_types.
    class InklingsGetTypesWebHandler
      def handle(request)
        error = AresMUSH::Website.check_login(request)
        return { error: error } if error

        InklingApi.get_types
      end
    end
  end
end
