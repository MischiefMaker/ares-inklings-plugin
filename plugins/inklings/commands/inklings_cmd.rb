module AresMUSH
  module Inklings
    # +inklings           - open threads (default)
    # +inklings/closed    - closed threads
    # +inklings/all       - everything
    class InklingsCmd
      include CommandHandler

      def handle
        inklings = enactor.inklings.to_a
        inklings.each { |i| Inklings.sync_job_replies(i) }

        if cmd.switch_is?("closed")
          inklings = inklings.select { |i| i.status == "closed" }
        elsif cmd.switch_is?("all")
          # no filter
        else
          inklings = inklings.select { |i| i.status == "open" }
        end

        inklings = inklings.sort_by { |i| i.created_at }.reverse

        if inklings.empty?
          client.emit_success t('inklings.no_inklings')
          return
        end

        list = inklings.map do |i|
          flag = i.player_unread == "true" ? "%xh*%xn " : "  "
          "#{flag}##{i.id} [#{i.kind.upcase}] (#{i.status}) #{i.created_at.strftime('%m/%d')} - #{i.messages.to_a.size} msg(s)"
        end

        template = BorderedPagedListTemplate.new list, cmd.page, 25, t('inklings.inklings_title')
        client.emit template.render
      end
    end
  end
end
