module AresMUSH
  module Inklings
    class InklingApi
      # GET /api/characters/:char_id/inklings
      def self.get_inklings(char_id, viewer_id, status_filter: "open")
        char = Character[char_id]
        return { error: "Character not found" } if !char

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        unless viewer.id == char.id || Inklings.can_manage_inklings?(viewer)
          return { error: "Not authorized" }
        end

        unless Inklings.can_manage_inklings?(viewer) || viewer.is_approved?
          return { error: "Your character must be approved to access inklings." }
        end

        own = char.inklings.to_a
        shared = InklingParticipant.find(character_id: viewer.id).map(&:inkling).compact
        group_matched = Inkling.all.to_a.select { |i| Inklings.is_group_participant?(i, viewer) }
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
          inklings: inklings.sort_by { |i| Inklings.time_value(i.created_at) }.reverse.map { |i| format_inkling_summary(i, viewer) }
        }
      end

      # POST /api/characters/:char_id/inklings
      def self.create_inkling(char_id, viewer_id, kind, text, title = nil)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        unless viewer.id == char.id || Inklings.can_manage_inklings?(viewer)
          return { error: "Not authorized" }
        end

        unless Inklings.can_manage_inklings?(viewer) || viewer.is_approved? || Inklings::CHARGEN_KINDS.include?(kind)
          return { error: "Your character must be approved to create inklings." }
        end

        return { error: "Invalid inkling kind" } if !Inklings::ALL_KINDS.include?(kind)
        if Inklings::STAFF_KINDS.include?(kind) && !Inklings.can_manage_inklings?(viewer)
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
          player_unread: viewer.id == char.id ? "false" : "true")

        InklingMessage.create(
          inkling: inkling,
          author: viewer,
          text: text,
          created_at: Time.now,
          seq: Inklings.next_event_seq(inkling),
          is_staff: Inklings.can_manage_inklings?(viewer) ? "true" : "false",
          is_private: "false",
          is_gm_note: "false",
          private_recipient_ids: "")

        if viewer.id == char.id
          Inklings.ensure_job(inkling, "#{viewer.name} - #{title}", text, viewer)
        else
          Inklings.notify_player(char, "<inklings> You have a new inkling.")
        end

        { inkling: format_inkling_detail(inkling, viewer) }
      end

      # GET /api/characters/:char_id/inklings/:inkling_id
      def self.get_inkling(char_id, inkling_id, viewer_id)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        return { error: "Not authorized" } if !in_context?(inkling, char, viewer)
        return { error: "Not authorized" } if !can_view_inkling?(inkling, viewer)

        Inklings.sync_job_replies(inkling)
        inkling.update(player_unread: "false") if inkling.character == viewer

        { inkling: format_inkling_detail(inkling, viewer) }
      end

      # POST /api/characters/:char_id/inklings/:inkling_id/reply
      def self.reply_to_inkling(char_id, inkling_id, viewer_id, text, is_private: false)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        return { error: "Not authorized" } if !in_context?(inkling, char, viewer)
        return { error: "Not authorized" } if !can_view_inkling?(inkling, viewer)
        return { error: "Your character must be approved to reply to inklings." } if !Inklings.can_manage_inklings?(viewer) && !viewer.is_approved?
        return { error: "This inkling is closed" } if inkling.status == "closed"
        return { error: "Reply text cannot be empty" } if text.to_s.blank?

        is_staff = Inklings.can_manage_inklings?(viewer)

        if is_staff && !is_private
          last_msg = inkling.messages.to_a.sort_by { |m| Inklings.time_value(m.created_at) }.last
          is_private = true if last_msg && last_msg.is_private.to_s == "true"
        end

        recipient_ids = ""
        if is_private && is_staff
          last_msg = inkling.messages.to_a.sort_by { |m| Inklings.time_value(m.created_at) }.last
          recipient_ids = last_msg&.private_recipient_ids.to_s.presence ||
            (last_msg&.author ? last_msg.author.id : inkling.character.id)
        end

        message = InklingMessage.create(
          inkling: inkling,
          author: viewer,
          text: text,
          created_at: Time.now,
          seq: Inklings.next_event_seq(inkling),
          is_staff: is_staff ? "true" : "false",
          is_private: is_private ? "true" : "false",
          is_gm_note: "false",
          private_recipient_ids: recipient_ids)

        job_text = is_private ? "[Private] #{text}" : text
        if is_staff
          inkling.update(player_unread: "true")
          Inklings.mirror_to_job(inkling, job_text, viewer)
          recipients = recipient_ids.to_s.split(",").map(&:strip).reject(&:empty?)
          notify_target = recipients.first ? Character[recipients.first] : inkling.character
          Inklings.notify_player(notify_target || inkling.character, "<inklings> You have a new inkling message. Use +inklings to view it.")
        else
          Inklings.ensure_job(inkling, "#{viewer.name} advanced #{inkling.title}", job_text, viewer)
        end

        { message: format_message(message) }
      end

      # PUT /api/characters/:char_id/inklings/:inkling_id/close
      def self.close_inkling(char_id, inkling_id, viewer_id)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        return { error: "Not authorized" } if !in_context?(inkling, char, viewer)
        return { error: "Not authorized" } if !can_manage_thread?(inkling, viewer)
        return { error: "Your character must be approved to close inklings." } if !Inklings.can_manage_inklings?(viewer) && !viewer.is_approved?

        inkling.update(status: "closed")
        Jobs.close_job(viewer, inkling.job, "Inkling closed from web portal") if inkling.job

        { inkling: format_inkling_summary(inkling, viewer) }
      end

      # DELETE /api/characters/:char_id/inklings/:inkling_id
      def self.delete_inkling(char_id, inkling_id, viewer_id)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        return { error: "Not authorized" } if !in_context?(inkling, char, viewer)
        return { error: "Not authorized" } if !can_manage_thread?(inkling, viewer)
        return { error: "Your character must be approved to delete inklings." } if !Inklings.can_manage_inklings?(viewer) && !viewer.is_approved?

        unless Inklings.can_manage_inklings?(viewer)
          transcript = inkling.messages.map { |m| "#{m.author ? m.author.name : "?"}: #{m.text}" }.join(" / ")
          Inklings.ensure_job(inkling, "#{viewer.name} deleted #{inkling.title}", "The player deleted this inkling. Its contents were: #{transcript}", viewer)
        end

        inkling.messages.each { |m| m.delete }
        inkling.rolls.each { |r| r.delete }
        InklingParticipant.find(inkling_id: inkling.id).each { |p| p.delete }
        inkling.delete

        { success: true }
      end

      # POST /api/characters/:char_id/inklings/:inkling_id/share
      def self.share_inkling(char_id, inkling_id, viewer_id, target_name)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

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

      def self.format_inkling_summary(inkling, viewer = nil)
        visible_messages = viewer ? visible_messages_for(inkling, viewer) : inkling.messages.to_a
        visible_rolls = viewer ? visible_rolls_for(inkling, viewer) : inkling.rolls.to_a

        {
          id: inkling.id,
          kind: inkling.kind,
          title: inkling.title,
          status: inkling.status,
          created_at: inkling.created_at,
          character_id: inkling.character ? inkling.character.id : nil,
          character_name: inkling.character ? inkling.character.name : nil,
          message_count: visible_messages.size,
          roll_count: visible_rolls.size,
          player_unread: viewer && inkling.character != viewer ? false : inkling.player_unread == "true",
          linked_job: inkling.job ? { id: inkling.job.id, status: inkling.job.status } : nil
        }
      end

      def self.format_inkling_detail(inkling, viewer = nil)
        messages = viewer ? visible_messages_for(inkling, viewer) : inkling.messages.to_a.sort_by { |m| Inklings.time_value(m.created_at) }
        rolls = viewer ? visible_rolls_for(inkling, viewer) : inkling.rolls.to_a.sort_by { |r| Inklings.time_value(r.created_at) }

        format_inkling_summary(inkling, viewer).merge(
          messages: messages.map { |m| format_message(m) },
          rolls: rolls.map { |r| format_roll(r) },
          shared_with: format_shared_with(inkling)
        )
      end

      def self.format_shared_with(inkling)
        {
          players: Inklings.shared_with_names(inkling),
          groups: Inklings.shared_group_list(inkling)
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
          private_recipient_ids: message.is_private == "true" ? message.private_recipient_ids.to_s.split(",").map(&:strip).reject(&:empty?) : [],
          private_recipient_names: message.is_private == "true" ? Inklings.private_recipient_names(message) : []
        }
      end

      def self.format_roll(roll)
        {
          id: roll.id,
          ref: Inklings.event_ref(roll.inkling, roll.seq),
          roll_type: roll.roll_type,
          roll_spec: roll.roll_spec,
          result: roll.result,
          result_value: roll.result_value,
          character: roll.character ? roll.character.name : nil,
          character_id: roll.character ? roll.character.id : nil,
          target_character: roll.target_character ? roll.target_character.name : nil,
          target_character_id: roll.target_character ? roll.target_character.id : nil,
          creator: roll.creator ? roll.creator.name : "Unknown",
          creator_id: roll.creator ? roll.creator.id : nil,
          private: roll.private == "true",
          reroll_count: roll.reroll_count.to_i,
          luck_cost: roll.luck_cost.to_i,
          created_at: roll.created_at,
          rolled_at: roll.rolled_at
        }
      end
    end
  end
end
