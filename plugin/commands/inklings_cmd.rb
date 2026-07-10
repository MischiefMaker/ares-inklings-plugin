module AresMUSH
  module Inklings
    # +inklings           - open threads (default)
    # +inklings/closed    - closed threads
    # +inklings/all       - everything
    class InklingsCmd
      include CommandHandler

      def check_approved
        return nil if Inklings.can_manage_inklings?(enactor)
        return t('inklings.char_not_approved') unless enactor.is_approved?
        nil
      end

      def handle
        own_inklings = enactor.inklings.to_a
        shared_inklings = InklingParticipant.find(character_id: enactor.id)
          .map(&:inkling).compact
        group_inklings = Inkling.all.to_a.select { |i| Inklings.is_group_participant?(i, enactor) }

        inklings = (own_inklings + shared_inklings + group_inklings).uniq(&:id)
        inklings.each { |i| Inklings.sync_job_replies(i) }

        if cmd.switch_is?("closed")
          inklings = inklings.select { |i| i.status == "closed" }
        elsif cmd.switch_is?("all")
          # no filter
        else
          inklings = inklings.select { |i| i.status == "open" }
        end

        inklings = inklings.sort_by { |i| Inklings.time_value(i.created_at) }.reverse

        if inklings.empty?
          client.emit_success t('inklings.no_inklings')
          return
        end

        list = inklings.map do |i|
          unread = i.character == enactor && i.player_unread == "true"
          flag = unread ? "%xh*%xn " : "  "
          title = i.title.to_s.blank? ? t("inklings.kind_#{i.kind}") : i.title
          visible_message_count = i.messages.to_a.count { |m| Inklings.can_see_message?(m, enactor) }
          count_text = "#{visible_message_count} msg(s)#{unread ? "%xh*%xn" : ""}"
          "#{flag}##{i.id} [#{i.kind.upcase}] #{title} (#{i.status}) #{Inklings.format_time(i.created_at, '%m/%d')} - #{count_text}"
        end

        template = BorderedPagedListTemplate.new list, cmd.page, 25, t('inklings.inklings_title')
        client.emit template.render
      end
    end
  end
end
