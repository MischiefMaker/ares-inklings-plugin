module AresMUSH
  module Inklings
    class InklingApi
      # Type list for the web portal's "New Inkling" picker, filtered
      # to what this viewer may create (see Inklings.creatable_kinds).
      # Embedded directly on the character payload via the
      # get_fields_for_viewing custom-fields hook (see
      # custom-install/custom_char_fields.snippet.rb) rather than
      # fetched by a separate web request - the inklings-tab component
      # needs this synchronously, before the player has done anything,
      # so there's no good moment to background-load it without
      # racing the player opening the "New Inkling" form.
      def self.creatable_type_options(viewer)
        Inklings.creatable_kinds(viewer).sort.map do |kind|
          config = Inklings.type_config[kind] || {}
          { kind: kind, name: Inklings.kind_label(kind), color: config["color"] || "secondary" }
        end
      end

      # Web endpoint: get_inklings
      # viewer is already authenticated (passed by web handler)
      # No approval gate here - the tab should always render. Permission checks
      # are applied at creation time (via creatable_kinds) and at visibility
      # (shared, group, etc). See Inklings.can_view_inkling for detail-level access.
      def self.get_inklings(char_id, viewer, status_filter: "open")
        char = Character[char_id]
        return { error: "Character not found" } if !char

        unless viewer.id == char.id || Inklings.can_manage_inklings?(viewer)
          return { error: "Not authorized" }
        end

        # Query explicitly by character_id rather than char.inklings
        # (a reverse-collection macro) - see the note in
        # InklingListCmd for why this is safer.
        #
        # shared/group_matched key off char.id (whose tab this is), not
        # viewer.id (who's looking at it) - those only coincide for a
        # self-view. When staff open someone else's tab, keying off
        # viewer.id pulled in inklings shared with the STAFF MEMBER's
        # own character and mixed them into the target's list.
        own = Inkling.find(character_id: char.id).to_a
        shared = InklingParticipant.find(character_id: char.id).map(&:inkling).compact
        group_matched = Inkling.all.to_a.select { |i| Inklings.is_group_participant?(i, char) }
        inklings = (own + shared + group_matched).uniq(&:id)

        inklings = case status_filter
        when "closed"
          inklings.select { |i| i.status == "closed" }
        when "all"
          inklings
        else
          inklings.select { |i| i.status == "open" }
        end

        {
          inklings: inklings.sort_by { |i| Inklings.time_value(i.created_at) }.reverse.map { |i| format_inkling_summary(i, viewer) },
          # Only ever non-empty for an unapproved character, which (given the
          # approval check above) means only staff ever actually receive
          # this - see Inklings.chargen_drafts.
          chargen_drafts: Inklings.chargen_drafts(char)
        }
      end

      # Default page size for the admin list. Mirrors the MUSH admin
      # command's own per-page (see InklingAdminCmd), which is in turn
      # the same 25 every other paginated inkling list in this plugin
      # uses (InklingsCmd, InklingListCmd via BorderedPagedListTemplate).
      ADMIN_PAGE_SIZE = 25

      # Web endpoint: list_all_inklings (admin)
      # Every inkling in the game, regardless of owner/participant/group
      # access - the admin management view. manage_inklings-gated here,
      # not just hidden client-side; the MUSH equivalent (InklingAdminCmd)
      # enforces the same check via Inklings.can_manage_inklings?, and both
      # share Inklings.all_inklings_query for the underlying list so
      # ordering/filtering can't drift between them.
      def self.list_all_inklings(viewer, status_filter: "open", page: 1)
        return { error: "Not authorized" } unless Inklings.can_manage_inklings?(viewer)

        page = page.to_i
        page = 1 if page < 1

        inklings = Inklings.all_inklings_query(status_filter: status_filter)
        total_pages = [(inklings.size.to_f / ADMIN_PAGE_SIZE).ceil, 1].max
        page = total_pages if page > total_pages

        page_slice = inklings.each_slice(ADMIN_PAGE_SIZE).to_a[page - 1] || []

        {
          inklings: page_slice.map { |i| format_inkling_summary(i, viewer, include_access: true) },
          # Reuses creatable_type_options as-is - for a manage_inklings
          # viewer, Inklings.creatable_kinds already returns every
          # configured kind (see the can_manage_inklings? short-circuit at
          # the top of that method), so this needs no admin-specific
          # variant. Sent alongside the list (rather than a separate
          # request) so the Add Inkling form's type picker is ready
          # immediately, the same reasoning as the profile tab's typeInfo.
          type_options: creatable_type_options(viewer),
          page: page,
          total_pages: total_pages,
          total_count: inklings.size
        }
      end

      # POST /api/characters/:char_id/inklings
      def self.create_inkling(char_id, viewer, kind, text, title = nil)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        unless viewer.id == char.id || Inklings.can_manage_inklings?(viewer)
          return { error: "Not authorized" }
        end

        # Permission: staff can always create; non-staff can only create for
        # their own approved character.
        unless Inklings.can_manage_inklings?(viewer) || (viewer.id == char.id && char.is_approved?)
          return { error: "Your character must be approved to create inklings." }
        end

        return { error: "Invalid inkling kind" } if !Inklings.valid_kind?(kind)
        if Inklings.staff_kinds.include?(kind) && !Inklings.can_manage_inklings?(viewer)
          return { error: "Not authorized" }
        end

        return { error: "Inkling title cannot be empty" } if title.to_s.blank?
        return { error: "Inkling text cannot be empty" } if text.to_s.blank?

        inkling = Inkling.create(
          kind: kind,
          title: title,
          status: "open",
          character: char,
          creator: viewer,
          created_at: Time.now,
          player_unread: viewer.id == char.id ? "false" : "true",
          locked: "false",
          approval_state: "draft",
          tags: "")

        InklingMessage.create(
          inkling: inkling,
          author: viewer,
          text: text,
          created_at: Time.now,
          seq: Inklings.next_event_seq(inkling),
          is_staff: Inklings.can_manage_inklings?(viewer) ? "true" : "false",
          is_private: "false",
          is_gm_note: "false",
          is_personal: "false",
          private_recipient_ids: "")

        if viewer.id != char.id
          Inklings.notify_player(char, "<inklings> You have a new inkling.")
        end

        Inklings.dispatch_inkling_created(inkling)

        { inkling: format_inkling_detail(inkling, viewer) }
      end

      # Web endpoint: create_inkling_by_name (admin page only)
      # The admin page has no single "current character" to default the
      # owner to - the operator picks one by name. This is a thin wrapper
      # around create_inkling/share_inkling, not a parallel creation path:
      # it resolves owner_name to a char_id and delegates, then (if
      # shared_with is present) delegates again to the exact same
      # share_inkling used by the "Share" button on every other inkling.
      # No creation/sharing logic is duplicated here.
      def self.create_inkling_by_name(owner_name, viewer, kind, text, title, shared_with: nil)
        return { error: "Not authorized" } unless Inklings.can_manage_inklings?(viewer)

        owner = Character.find_one_by_name(owner_name.to_s.strip)
        return { error: "Character not found: #{owner_name}" } if !owner

        result = create_inkling(owner.id, viewer, kind, text, title)
        return result if result[:error]

        if shared_with.to_s.present?
          share_result = share_inkling(owner.id, result[:inkling][:id], viewer, shared_with)
          result[:share_warning] = share_result[:error] if share_result && share_result[:error]
        end

        result
      end

      # Web endpoint: get_inkling
      def self.get_inkling(char_id, inkling_id, viewer)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        return { error: "Not authorized" } if !in_context?(inkling, char, viewer)
        return { error: "Not authorized" } if !can_view_inkling?(inkling, viewer)

        Inklings.sync_job_replies(inkling)
        Inklings.update_inkling(inkling, player_unread: "false") if inkling.character == viewer

        { inkling: format_inkling_detail(inkling, viewer) }
      end

      # Web endpoint: reply_to_inkling
      def self.reply_to_inkling(char_id, inkling_id, viewer, text, is_private: false, is_personal: false)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        return { error: "Not authorized" } if !in_context?(inkling, char, viewer)
        return { error: "Not authorized" } if !can_view_inkling?(inkling, viewer)
        return { error: "Your character must be approved to reply to inklings." } if !Inklings.can_manage_inklings?(viewer) && !viewer.is_approved?
        return { error: "This inkling is closed" } if inkling.status == "closed"
        return { error: "This inkling has been submitted and is locked until staff respond." } if inkling.locked == "true" && !Inklings.can_manage_inklings?(viewer) && !is_personal
        return { error: "Reply text cannot be empty" } if text.to_s.blank?

        is_staff = Inklings.can_manage_inklings?(viewer)

        if is_staff && !is_private && !is_personal
          last_msg = inkling.messages.to_a.sort_by { |m| Inklings.time_value(m.created_at) }.last
          is_private = true if last_msg && last_msg.is_private.to_s == "true"
        end

        recipient_ids = ""
        # Only staff can set explicit recipients for private messages.
        # For staff, inherit from the previous message or default to the inkling creator.
        # For players, private messages are always staff-only (recipient_ids stays empty) -
        # this ensures players cannot inadvertently share their private messages with the creator.
        if is_private && is_staff
          last_msg = inkling.messages.to_a.sort_by { |m| Inklings.time_value(m.created_at) }.last
          recipient_ids = last_msg&.private_recipient_ids.to_s.presence ||
            (last_msg&.author ? last_msg.author.id : inkling.character.id)
        elsif is_private && !is_staff
          # Double-check: non-staff players can never have recipient IDs for private messages
          recipient_ids = ""
        end

        message = InklingMessage.create(
          inkling: inkling,
          author: viewer,
          text: text,
          created_at: Time.now,
          seq: Inklings.next_event_seq(inkling),
          is_staff: is_staff ? "true" : "false",
          is_private: is_personal ? "false" : (is_private ? "true" : "false"),
          is_gm_note: "false",
          is_personal: is_personal ? "true" : "false",
          private_recipient_ids: recipient_ids)

        job_text = is_private ? "[Private] #{text}" : text
        if is_staff && !is_personal
          # A staff reply is what unlocks a submitted thread.
          Inklings.update_inkling(inkling, player_unread: "true", locked: "false")
          Inklings.mirror_to_job(inkling, job_text, viewer)
          recipients = recipient_ids.to_s.split(",").map(&:strip).reject(&:empty?)
          notify_target = recipients.first ? Character[recipients.first] : inkling.character
          Inklings.notify_player(notify_target || inkling.character, "<inklings> You have a new inkling message. Use +inklings to view it.")
        end

        { message: format_message(message) }
      end

      # PUT /api/characters/:char_id/inklings/:inkling_id/close
      def self.close_inkling(char_id, inkling_id, viewer)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        
        return { error: "Not authorized" } if !in_context?(inkling, char, viewer)
        return { error: "Not authorized" } if !can_manage_thread?(inkling, viewer)
        return { error: "Your character must be approved to close inklings." } if !Inklings.can_manage_inklings?(viewer) && !viewer.is_approved?

        Inklings.update_inkling(inkling, status: "closed")
        Jobs.close_job(viewer, inkling.job, "Inkling closed from web portal") if inkling.job

        { inkling: format_inkling_summary(inkling, viewer) }
      end

      # POST /api/characters/:char_id/inklings/:inkling_id/submit
      # Locks the thread and sends its full contents to a single staff
      # job - see Inklings.submit_inkling. Building up a thread does
      # NOT notify staff by itself; nothing reaches staff until this
      # is called (in-game: +inkling/submit).
      def self.submit_inkling(char_id, inkling_id, viewer)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        
        return { error: "Not authorized" } if !in_context?(inkling, char, viewer)
        return { error: "Not authorized" } if !can_manage_thread?(inkling, viewer)
        return { error: "Your character must be approved to submit inklings." } if !Inklings.can_manage_inklings?(viewer) && !viewer.is_approved?
        return { error: "This inkling is closed" } if inkling.status == "closed"
        return { error: "This inkling has already been submitted and is awaiting a staff response." } if inkling.locked == "true"

        Inklings.submit_inkling(inkling, viewer)

        { inkling: format_inkling_summary(inkling, viewer) }
      end

      # DELETE /api/characters/:char_id/inklings/:inkling_id
      # Staff delete the thread outright and immediately. Players can
      # no longer delete their own thread directly - this closes it and
      # files a job asking staff to review and approve a permanent
      # deletion (a staff member then carries that out themselves,
      # either here or via +inkling/delete in-game).
      def self.delete_inkling(char_id, inkling_id, viewer)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        
        return { error: "Not authorized" } if !in_context?(inkling, char, viewer)
        return { error: "Not authorized" } if !can_manage_thread?(inkling, viewer)
        return { error: "Your character must be approved to delete inklings." } if !Inklings.can_manage_inklings?(viewer) && !viewer.is_approved?

        if Inklings.can_manage_inklings?(viewer)
          inkling.messages.each { |m| m.delete }
          inkling.rolls.each { |r| r.delete }
          InklingParticipant.find(inkling_id: inkling.id).each { |p| p.delete }
          inkling.delete

          return { success: true, deleted: true }
        end

        Inklings.update_inkling(inkling, status: "closed")
        transcript = inkling.messages.map { |m| "#{m.author ? m.author.name : "?"}: #{m.text}" }.join(" / ")
        Inklings.ensure_job(inkling,
          Inklings.deletion_request_title(viewer, inkling.id),
          "The player has requested this inkling be permanently deleted. Current contents: #{transcript}",
          viewer)

        { success: true, deleted: false, inkling: format_inkling_summary(inkling, viewer) }
      end

      # POST /api/characters/:char_id/inklings/:inkling_id/share
      def self.share_inkling(char_id, inkling_id, viewer, target_name)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        
        return { error: "Not authorized" } if !in_context?(inkling, char, viewer)
        return { error: "Not authorized" } if !can_manage_thread?(inkling, viewer)
        return { error: "Your character must be approved to share inklings." } if !Inklings.can_manage_inklings?(viewer) && !viewer.is_approved?
        return { error: "Cannot share a closed inkling" } if inkling.status == "closed"

        names = Inklings.split_list(target_name)
        added = []
        missing = []

        names.each do |name|
          target = Character.find_one_by_name(name)
          if !target
            missing << name
            next
          end

          next if Inklings.is_participant?(inkling, target)

          InklingParticipant.create(
            inkling: inkling,
            character: target,
            added_at: Time.now)

          Inklings.notify_player(target,
            "<inklings> #{viewer.name} has shared an inkling with you. Use +inkling #{inkling.id} to view it.")
          added << target.name

          Inklings.dispatch_inkling_shared(inkling, target)
        end

        if added.empty?
          return { error: "Can't find: #{missing.join(', ')}." } if missing.any?
          return { error: "No new characters were added." }
        end

        {
          success: true,
          target_names: added,
          missing_names: missing
        }
      end

      private

      def self.in_context?(inkling, char, viewer)
        return true if inkling.character == char
        viewer.id == char.id && Inklings.is_participant?(inkling, viewer)
      end

      def self.can_view_inkling?(inkling, viewer)
        Inklings.can_manage_inklings?(viewer) || Inklings.is_participant?(inkling, viewer)
      end

      def self.can_manage_thread?(inkling, viewer)
        Inklings.can_manage_inklings?(viewer) || inkling.character == viewer
      end

      def self.visible_messages_for(inkling, viewer)
        inkling.messages.to_a.sort_by { |m| Inklings.time_value(m.created_at) }.select { |m| Inklings.can_see_message?(m, viewer) }
      end

      def self.visible_rolls_for(inkling, viewer)
        inkling.rolls.to_a.sort_by { |r| Inklings.time_value(r.created_at) }.select { |r| Inklings.can_see_roll?(r, viewer) }
      end

      # visible_messages/visible_rolls can be passed in when the caller
      # (format_inkling_detail) has already computed them, to avoid
      # doing the sort+filter pass over the same records twice.
      #
      # include_access: adds the same shared_with shape format_inkling_detail
      # already merges in (owner + participants + shared groups - see
      # Inklings.shared_with_names/shared_group_list). Off by default since
      # the per-character list views (profile tab, +inklings) don't need it
      # and it's an extra query per row; the admin list view (which shows
      # every inkling regardless of the viewer's own access) turns it on.
      def self.format_inkling_summary(inkling, viewer = nil, visible_messages: nil, visible_rolls: nil, include_access: false)
        visible_messages ||= viewer ? visible_messages_for(inkling, viewer) : inkling.messages.to_a
        visible_rolls ||= viewer ? visible_rolls_for(inkling, viewer) : inkling.rolls.to_a

        tags = inkling.tags.to_s.split(",").map(&:strip).reject(&:empty?)
        kind_color = (Inklings.type_config[inkling.kind] || {})["color"] || "secondary"

        summary = {
          id: inkling.id,
          kind: inkling.kind,
          kind_label: Inklings.kind_label(inkling.kind),
          kind_color: kind_color,
          title: inkling.title,
          status: inkling.status,
          created_at: inkling.created_at,
          character_id: inkling.character ? inkling.character.id : nil,
          character_name: inkling.character ? inkling.character.name : nil,
          message_count: visible_messages.size,
          roll_count: visible_rolls.size,
          player_unread: viewer && inkling.character != viewer ? false : inkling.player_unread == "true",
          locked: inkling.locked == "true",
          tags: tags,
          tags_label: tags.join(", "),
          linked_job: inkling.job ? { id: inkling.job.id, status: inkling.job.status } : nil
        }
        summary[:shared_with] = format_shared_with(inkling) if include_access
        summary
      end

      def self.format_inkling_detail(inkling, viewer = nil)
        messages = viewer ? visible_messages_for(inkling, viewer) : inkling.messages.to_a.sort_by { |m| Inklings.time_value(m.created_at) }
        rolls = viewer ? visible_rolls_for(inkling, viewer) : inkling.rolls.to_a.sort_by { |r| Inklings.time_value(r.created_at) }

        format_inkling_summary(inkling, viewer, visible_messages: messages, visible_rolls: rolls).merge(
          messages: messages.map { |m| format_message(m) },
          rolls: rolls.map { |r| format_roll(r) },
          shared_with: format_shared_with(inkling)
        )
      end

      def self.format_shared_with(inkling)
        {
          players: Inklings.shared_with_names(inkling).join(", "),
          groups: Inklings.shared_group_list(inkling).join(", ")
        }
      end

      def self.format_message(message)
        {
          id: message.id,
          ref: Inklings.event_ref(message.inkling, message.seq),
          author: message.author ? message.author.name : "Unknown",
          author_id: message.author ? message.author.id : nil,
          text: message.text,
          created_at: message.created_at,
          is_staff: message.is_staff == "true",
          is_private: message.is_private == "true",
          is_gm_note: message.is_gm_note == "true",
          is_personal: message.is_personal == "true",
          private_recipient_ids: message.is_private == "true" ? message.private_recipient_ids.to_s.split(",").map(&:strip).reject(&:empty?) : [],
          private_recipient_names: message.is_private == "true" ? Inklings.private_recipient_names(message) : [],
          private_recipient_label: message.is_private == "true" ? Inklings.private_recipient_names(message).join(", ") : ""
        }
      end

      def self.format_roll(roll)
        Inklings.format_roll_json(roll)
      end

      # POST - Add a tag to an inkling
      def self.add_tag(char_id, inkling_id, viewer, tag)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        
        return { error: "Not authorized" } if !in_context?(inkling, char, viewer)
        return { error: "Not authorized" } if !can_view_inkling?(inkling, viewer)
        return { error: "Not authorized to manage tags" } if inkling.character != viewer && !Inklings.can_manage_inklings?(viewer)

        tag = tag.to_s.strip.downcase
        return { error: "Invalid tag" } if tag.blank?
        return { error: "Tag too long" } if tag.length > 30

        existing_tags = Inklings.get_tags(inkling)
        return { error: "Tag already exists" } if existing_tags.include?(tag)

        Inklings.add_tag(inkling, tag)

        { inkling: format_inkling_detail(inkling, viewer) }
      end

      # POST - Remove a tag from an inkling
      def self.remove_tag(char_id, inkling_id, viewer, tag)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        
        return { error: "Not authorized" } if !in_context?(inkling, char, viewer)
        return { error: "Not authorized" } if !can_view_inkling?(inkling, viewer)
        return { error: "Not authorized to manage tags" } if inkling.character != viewer && !Inklings.can_manage_inklings?(viewer)

        tag = tag.to_s.strip.downcase
        return { error: "Invalid tag" } if tag.blank?

        existing_tags = Inklings.get_tags(inkling)
        return { error: "Tag not found" } unless existing_tags.include?(tag)

        Inklings.remove_tag(inkling, tag)

        { inkling: format_inkling_detail(inkling, viewer) }
      end

      # POST - Add a GM note to an inkling (staff only)
      def self.add_gm_note(char_id, inkling_id, viewer, text)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        
        return { error: "Not authorized" } if !Inklings.can_manage_inklings?(viewer)
        return { error: "Text cannot be empty" } if text.to_s.blank?

        InklingMessage.create(
          inkling: inkling,
          author: viewer,
          text: text,
          created_at: Time.now,
          seq: Inklings.next_event_seq(inkling),
          is_staff: "true",
          is_private: "false",
          is_gm_note: "true",
          is_personal: "false",
          private_recipient_ids: "")

        Inklings.mirror_to_job(inkling, "[GM] #{text}", viewer, true)

        { inkling: format_inkling_detail(inkling, viewer) }
      end

      # POST - Approve a submitted inkling (staff only)
      def self.approve_inkling(inkling_id, viewer, message = nil)
        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        
        return { error: "Not authorized" } if !Inklings.can_manage_inklings?(viewer)
        return { error: "Inkling not submitted for review" } if inkling.approval_state != "submitted"

        Inklings.approve_inkling(inkling, viewer, message)

        { inkling: format_inkling_detail(inkling, viewer) }
      end

      # POST - Request changes to a submitted inkling (staff only)
      def self.request_changes_inkling(inkling_id, viewer, feedback)
        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        
        return { error: "Not authorized" } if !Inklings.can_manage_inklings?(viewer)
        return { error: "Inkling not submitted for review" } if inkling.approval_state != "submitted"
        return { error: "Feedback cannot be empty" } if feedback.to_s.blank?

        Inklings.request_changes(inkling, viewer, feedback)

        { inkling: format_inkling_detail(inkling, viewer) }
      end

      # POST - Grant a reward to an inkling character (staff only)
      def self.grant_inkling_reward(inkling_id, viewer, reward_type, reward_key, amount)
        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        
        return { error: "Not authorized" } if !Inklings.can_manage_inklings?(viewer)
        return { error: "Reward type cannot be empty" } if reward_type.to_s.blank?
        return { error: "Amount cannot be empty" } if amount.to_s.blank?

        Inklings.grant_reward(inkling, inkling.character, viewer, reward_type, reward_key, amount)

        { inkling: format_inkling_detail(inkling, viewer) }
      end
    end
  end
end
