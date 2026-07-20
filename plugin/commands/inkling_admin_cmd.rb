module AresMUSH
  module Inklings
    # +inkling/admin           - open threads, every character (default)
    # +inkling/admin/closed    - closed threads, every character
    # +inkling/admin/all       - every status, every character
    #
    # The admin/management equivalent of +inklings: instead of the
    # enactor's own threads (own + shared + group), this shows every
    # inkling in the game regardless of owner, status, or visibility -
    # the MUSH counterpart to the web admin page (see
    # webportal/routes/admin-inklings.js). Query/ordering is shared with
    # that web endpoint via Inklings.all_inklings_query so the two can't
    # drift out of sync; each side still does its own native pagination
    # (BorderedPagedListTemplate here, a manual slice there).
    #
    # NOT "+inklings/all" - that switch is already taken on InklingsCmd,
    # where it means "no status filter on MY OWN list". A second,
    # differently-scoped meaning on the same switch name would be
    # actively confusing, so this is its own command/switch instead.
    class InklingAdminCmd
      include CommandHandler

      def check_permission
        return nil if Inklings.can_manage_inklings?(enactor)
        t('dispatcher.not_allowed')
      end

      def handle
        status_filter = if cmd.switch_is?("closed")
          "closed"
        elsif cmd.switch_is?("all")
          "all"
        else
          "open"
        end

        inklings = Inklings.all_inklings_query(status_filter: status_filter)

        if inklings.empty?
          client.emit_success t('inklings.no_inklings')
          return
        end

        list = []
        inklings.each_with_index do |i, idx|
          title = i.title.to_s.blank? ? Inklings.kind_label(i.kind) : i.title
          owner = i.character ? i.character.name : "?"
          job_text = i.job ? "Job ##{i.job.id}" : t('inklings.no_linked_job')
          access = (Inklings.shared_with_names(i) + Inklings.shared_group_list(i)).join(", ")
          lock_text = i.locked == "true" ? " %xh%crLOCKED%xn" : ""

          line1 = "##{i.id} [#{Inklings.color_type(i.kind.upcase)}] #{Inklings.color_title(title)} (#{i.status}) " \
            "#{Inklings.format_time(i.created_at, '%m/%d')} - #{job_text} - #{i.messages.to_a.size} msg(s)#{lock_text}"
          line2 = "    Owner: #{Inklings.color_name(owner)}  Access: #{access}"
          list << line1
          list << line2
          list << nil unless idx == inklings.length - 1
        end

        # per_page is in raw list-line units, not inkling units, since
        # each inkling contributes the two lines above - 50 lines gives
        # the same 25-inklings-per-page as every other paginated inkling
        # list in this plugin (InklingsCmd, InklingListCmd).
        template = BorderedPagedListTemplate.new list, cmd.page, 50, t('inklings.admin_title')
        client.emit template.render
      end
    end
  end
end
