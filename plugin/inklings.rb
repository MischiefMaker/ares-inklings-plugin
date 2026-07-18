require "time"

module AresMUSH
  module Inklings
    def self.plugin_dir
      File.dirname(__FILE__)
    end

    def self.shortcuts
      Global.read_config("inklings", "shortcuts")
    end

    # Whether this character can manage inklings as staff (send hints,
    # visions, nudges, hooks; audit/delete other people's threads).
    # Permission is configurable via the "manage_permission" setting in
    # game/config/inklings.yml. Defaults to "manage_jobs" so anyone who
    # manages jobs can also manage inklings. Override in config if your
    # game's staff structure differs.
    def self.can_manage_inklings?(enactor)
      return false if !enactor
      permission = Global.read_config("inklings", "manage_permission") || "manage_jobs"
      enactor.has_permission?(permission)
    end

    # Whether this character can run the destructive +inkling/reset
    # command. Deliberately narrower than can_manage_inklings? (which
    # many ordinary Inklings staff have) - this checks the "manage_game"
    # permission directly, per the standard Ares permission system
    # (see https://aresmush.com/tutorials/manage/roles.html). That
    # permission is normally only granted to the Coder role, though
    # Admins implicitly have every permission.
    def self.can_reset_system?(enactor)
      return false if !enactor
      enactor.has_permission?("manage_game")
    end

    # --- Ansi color helpers -------------------------------------------
    # Applied to character/group Names, Inkling Titles, and Inkling
    # Types in text emitted directly to a client (list rows, thread
    # view, warnings, share confirmations). Per
    # https://aresmush.com/tutorials/code/formatting.html, colors are
    # applied with %x<code> and must be closed with %xn.
    #
    # Deliberately NOT used on persisted data like Inkling#title or Job
    # titles - those get read back by other systems (the Jobs web view,
    # this plugin's own web portal) that shouldn't have to deal with
    # raw ansi escape codes showing up in their text.
    def self.color_name(text)
      "%xc#{text}%xn"
    end

    def self.color_title(text)
      "%xg#{text}%xn"
    end

    def self.color_type(text)
      "%xm#{text}%xn"
    end

    # Title used when a player explicitly submits an inkling for staff
    # review (see +inkling/submit / Inklings.submit_inkling).
    # Deliberately short and free of the inkling ID / redundant
    # "submitted by" text that the Jobs plugin's own "New Job!"
    # announcement already includes.
    def self.submission_job_title(char, kind)
      "[ACTION] #{char.name} submitted a #{kind_label(kind)} inkling for review."
    end

    # Title used for the job filed when a player requests their inkling
    # be deleted (see the +inkling/delete deletion-request workflow).
    def self.deletion_request_title(char, inkling_id)
      "#{char.name} is requesting to delete inkling ##{inkling_id}."
    end

    # --- Inkling types (kinds) -----------------------------------------
    # Types live in game config (game/config/inklings.yml, under
    # "types") rather than as hardcoded constants, so game admins can
    # add, remove, rename, or redescribe them without touching code.
    # Read fresh each call (not memoized) so config edits take effect
    # immediately without needing a full plugin reload.
    #
    # NOTE: "update" is intentionally not a type. A player typing
    # "+inkling/update 3=blah" reads as "update thread #3", but since
    # updating an existing thread is what +inkling/advance (or /reply)
    # is for, having a *type* called "update" meant that command
    # instead silently started a brand-new thread with the literal text
    # "3=blah". Removing it avoids that confusion; use +inkling/advance
    # or +inkling/reply to add an update to an existing thread.
    #
    # Rolls are NOT a type - see the note in inklings.yml.
    def self.type_config
      Global.read_config("inklings", "types") || {}
    end

    def self.kinds_in_category(category)
      type_config.select { |_k, v| v["category"] == category.to_s }.keys
    end

    def self.staff_kinds
      kinds_in_category("staff")
    end

    def self.player_kinds
      kinds_in_category("player")
    end

    def self.shared_kinds
      kinds_in_category("shared")
    end

    def self.all_kinds
      type_config.keys
    end

    # Kinds that can be created by unapproved characters (during
    # chargen). All other player commands require an approved character.
    def self.chargen_kinds
      type_config.select { |_k, v| v["chargen"] }.keys
    end

    # Inkling types required during character generation, configured in
    # game/config/inklings.yml under chargen_required_types. If none are
    # configured, returns an empty array (chargen has no inkling requirements).
    def self.chargen_required_types
      Global.read_config("inklings", "chargen_required_types") || []
    end

    def self.valid_kind?(kind)
      type_config.key?(kind.to_s)
    end

    # Display label for a kind, e.g. "Secret" for "secret". Falls back
    # to a capitalized version of the raw kind if it's missing from
    # config entirely - this covers old data using a kind that's since
    # been removed from config (like the legacy "update" kind) so it
    # still renders something reasonable instead of erroring.
    def self.kind_label(kind)
      (type_config[kind.to_s] || {})["name"] || kind.to_s.capitalize
    end

    def self.kind_description(kind)
      (type_config[kind.to_s] || {})["description"]
    end

    def self.find_inkling(id)
      Inkling[id]
    end

    def self.time_value(value)
      return value if value.is_a?(Time)
      return Time.parse(value) if !value.to_s.blank?
      Time.at(0)
    rescue ArgumentError
      Time.at(0)
    end

    def self.format_time(value, format)
      time_value(value).strftime(format)
    end

    def self.staff_target_warning(char, inkling_id = nil)
      return nil if !char
      id_part = inkling_id ? "inkling ##{inkling_id}" : "this inkling"
      name = color_name(char.name)
      return "%xyWarning:%xn #{name} is not approved. You're creating #{id_part} on an unapproved character." if !char.is_approved?
      return "%xyWarning:%xn #{name} can manage staff-side systems. Make sure #{id_part} belongs on a real character, not a staff utility/player record." if Inklings.can_manage_inklings?(char)
      nil
    end

    # Whether char is meaningfully attached to this thread (as its
    # subject, the one who started it, or an explicitly added participant).
    # Staff can always act on any thread regardless of this check.
    # Explicit participant check (owner, creator, or manually added).
    # Does NOT include group membership. Used to avoid double-notifying
    # characters who are already explicit participants when a group share is set.
    def self.is_participant_explicit?(inkling, char)
      return true if inkling.character == char
      return true if inkling.creator == char
      InklingParticipant.find(inkling_id: inkling.id, character_id: char.id).any?
    end

    def self.is_participant?(inkling, char)
      return true if inkling.character == char
      return true if inkling.creator == char
      return true if InklingParticipant.find(inkling_id: inkling.id, character_id: char.id).any?
      return true if is_group_participant?(inkling, char)
      false
    end

    def self.split_list(value)
      value.to_s.split(",").map(&:strip).reject(&:empty?)
    end

    # Returns true if the group spec exists in the demographics config.
    # Accepts "Value" (checks all group keys) or "Key:Value" (checks specific key).
    # Always returns false when Demographics is not loaded.
    def self.valid_group_spec?(spec)
      return false unless defined?(Demographics)
      query = spec.to_s.strip
      return false if query.blank?

      if query.include?(":")
        group_key, group_value = query.split(":", 2).map(&:strip)
        return false if group_key.blank? || group_value.blank?
        group_config = Demographics.get_group(group_key)
        return false unless group_config
        values = (group_config["values"] || {}).keys
        values.any? { |v| v.to_s.downcase == group_value.downcase }
      else
        Demographics.all_groups.values.any? do |group_config|
          values = (group_config["values"] || {}).keys
          values.any? { |v| v.to_s.downcase == query.downcase }
        end
      end
    end

    # Returns true if char's group membership matches a single spec string.
    def self.char_matches_group_spec?(char, spec)
      return false unless char.respond_to?(:group)
      query = spec.to_s.strip
      return false if query.blank?

      if query.include?(":")
        group_key, group_value = query.split(":", 2).map(&:strip)
        return false if group_key.blank? || group_value.blank?
        char.group(group_key).to_s.downcase == group_value.downcase
      else
        group_keys = defined?(Demographics) ? Demographics.all_groups.keys : []
        group_keys.any? { |key| char.group(key).to_s.downcase == query.downcase }
      end
    end

    # Returns true if any of the inkling's stored shared_groups specs match char.
    def self.is_group_participant?(inkling, char)
      specs = split_list(inkling.shared_groups)
      specs.any? { |spec| char_matches_group_spec?(char, spec) }
    end

    def self.add_participant(inkling, target, added_by)
      return :already_shared if Inklings.is_participant?(inkling, target)

      InklingParticipant.create(
        inkling: inkling,
        character: target,
        added_at: Time.now)

      Inklings.notify_player(target,
        "<inklings> #{Inklings.color_name(added_by.name)} has shared an inkling with you. Use +inkling #{inkling.id} to view it.")

      :added
    end

    # Character names shown in the "Shared With" section of a thread:
    # the thread's subject character (unless they're staff) plus anyone
    # explicitly added as a participant, either directly or via a
    # matching group (via +inkling/share or +inkling/group) - excluding
    # any staff members. Staff always have access regardless of
    # sharing, so listing them here would just be noise (and could
    # inadvertently out a staff alt).
    def self.shared_with_names(inkling)
      names = []

      if inkling.character && !can_manage_inklings?(inkling.character)
        names << inkling.character.name
      end

      InklingParticipant.find(inkling_id: inkling.id).each do |p|
        next if !p.character
        next if can_manage_inklings?(p.character)
        names << p.character.name
      end

      names.uniq.sort
    end

    # Group specs shared on this inkling (e.g. ["Navy", "Faction:Marines"]),
    # for display in the "Shared With" section.
    def self.shared_group_list(inkling)
      split_list(inkling.shared_groups)
    end

    # Next sequence number for a new message or roll on this inkling.
    # Messages and rolls share one incrementing counter so every event
    # in a thread - message or roll - gets a unique, permanent number
    # regardless of type (e.g. 2.1, 2.2, 2.3...). Based on the highest
    # seq already assigned rather than a simple count, so it stays
    # stable even if individual entries are ever deleted.
    def self.next_event_seq(inkling)
      seqs = inkling.messages.to_a.map { |m| m.seq.to_i } +
        inkling.rolls.to_a.map { |r| r.seq.to_i }
      (seqs.max || 0) + 1
    end

    # The stable "2.1" style reference for a message or roll: inkling
    # ID, dot, per-thread sequence number. Use this (rather than the
    # underlying database ID) any time you need to point at a specific
    # message or roll from elsewhere, since it stays human-readable and
    # meaningful within the context of its thread.
    def self.event_ref(inkling, seq)
      "#{inkling.id}.#{seq}"
    end

    # Shared JSON shape for a roll, used by both InklingApi and
    # RollsApi (previously duplicated identically in both files).
    def self.format_roll_json(roll)
      {
        id: roll.id,
        ref: event_ref(roll.inkling, roll.seq),
        roll_type: roll.roll_type,
        roll_spec: roll.roll_spec,
        result: roll.result,
        result_value: roll.result_value,
        character: roll.character ? roll.character.name : nil,
        character_id: roll.character ? roll.character.id : nil,
        target_character: roll.target_character ? roll.target_character.name : roll.npc_name,
        target_character_id: roll.target_character ? roll.target_character.id : nil,
        npc_name: roll.npc_name,
        creator: roll.creator ? roll.creator.name : "Unknown",
        creator_id: roll.creator ? roll.creator.id : nil,
        private: roll.private == "true",
        reroll_count: roll.reroll_count.to_i,
        luck_cost: roll.luck_cost.to_i,
        created_at: roll.created_at,
        rolled_at: roll.rolled_at
      }
    end

    # Fixed job category so inkling-linked jobs land on their own board.
    # Create this category in-game with: job/createcategory INKLINGS
    # (override in inklings.yml if you want a different category name).
    def self.job_category
      Global.read_config("inklings", "job_category") || "INKLINGS"
    end

    # Makes sure the given inkling has a linked job, so staff are
    # notified. Creates one if it doesn't have one yet - or if the
    # previously-linked one has since been closed, since mirroring
    # onto a closed job isn't useful - otherwise mirrors the message
    # onto the existing open job as a comment.
    def self.ensure_job(inkling, title, message, enactor)
      if inkling.job && inkling.job.status != "closed"
        mirror_to_job(inkling, message, enactor)
        return inkling.job
      else
        # Add staff command instructions to the job body
        staff_instructions = "\n\n---\n\nSTAFF ACTIONS:\nUse +inkling/approve #{inkling.id} to approve.\nUse +inkling/needschanges #{inkling.id}=<feedback> to request revisions."
        job_body = message + staff_instructions

        result = Jobs.create_job(self.job_category, title, job_body, enactor)
        if result[:error]
          Global.logger.error("Inklings: Failed to create job for inkling ##{inkling.id} - #{result[:error]}")
          return nil
        end
        job = result[:job]
        update_inkling(inkling, job: job)
        return job
      end
    end

    # Adds a comment to an inkling's already-existing linked job.
    # admin_only is false because this is a message the player submitted
    # (or is meant to see), not an internal staff note.
    def self.mirror_to_job(inkling, message, enactor, admin_only = false)
      return if !inkling.job
      Jobs.comment(inkling.job, enactor, message, admin_only)
    end

    # There's no event fired when a JobReply is added, so instead of
    # pushing job replies into Inklings, we pull: call this whenever an
    # inkling is displayed, and it copies over any JobReply on the linked
    # job that hasn't been mirrored into the thread yet. admin_only
    # replies (internal staff notes on the job) are intentionally
    # skipped - those aren't meant for the player to see.
    def self.sync_job_replies(inkling)
      return if !inkling.job

      new_messages = false

      JobReply.find(job_id: inkling.job.id).to_a.each do |reply|
        next if reply.admin_only.to_s == "true"
        next if InklingMessage.find(source_job_reply_id: reply.id).any?

        InklingMessage.create(
          inkling: inkling,
          author: reply.author,
          text: reply.message,
          created_at: reply.respond_to?(:created_at) ? reply.created_at : Time.now,
          seq: Inklings.next_event_seq(inkling),
          is_staff: "true",
          source_job_reply: reply)

        new_messages = true
      end

      if new_messages
        # A staff response arrived via the linked job rather than an
        # in-game +inkling command. This does NOT unlock the thread -
        # a reply (through any channel) is not the same thing as a
        # review decision. Only +inkling/approve or
        # +inkling/needschanges change the lock/approval state - see
        # the comment on Inkling#approval_state.
        update_inkling(inkling, player_unread: "true")
        # NOTE: t() is a CommandHandler helper and isn't available here,
        # since this runs from a plain module method, not a command
        # instance. Using a plain string instead - swap in your game's
        # actual locale lookup (e.g. Global.locales.t(...)) if you want
        # this localized.
        Inklings.notify_player(inkling.character, "<inklings> You have a new inkling message. Use +inklings to view it.")
      end
    end

    # Renders the entire thread (every message and roll, in
    # chronological order) as plain text, for the job body when a
    # player submits. Deliberately includes everything regardless of
    # per-message privacy flags, since it's going to staff - the same
    # audience that can already see every private message/roll in the
    # thread anyway. Deliberately plain (no ansi color codes), since
    # this text is persisted onto a Job that's read back both in-game
    # and through the web portal's Job view.
    def self.compile_thread_text(inkling)
      events = []

      inkling.messages.to_a.each do |m|
        who = m.author ? m.author.name : "?"
        tags = []
        tags << "gm" if m.is_gm_note == "true"
        tags << private_tag_label(m, colorize: false) if m.is_private == "true"
        tag_text = tags.empty? ? "" : " [#{tags.join(", ")}]"
        ref = event_ref(inkling, m.seq)
        header = "##{ref} #{format_time(m.created_at, '%m/%d %H:%M')} #{who}#{tag_text}"
        events << [time_value(m.created_at), "#{header}\n#{m.text}"]
      end

      inkling.rolls.to_a.each do |r|
        who = r.creator ? r.creator.name : "?"
        target = r.target_character ? r.target_character.name : r.npc_name
        target_text = target.to_s.blank? ? "" : " for #{target}"
        private_tag = r.private.to_s == "true" ? " [private]" : ""
        ref = event_ref(inkling, r.seq)
        events << [time_value(r.created_at), "##{ref} #{format_time(r.created_at, '%m/%d %H:%M')} #{who} rolled #{r.roll_spec}#{target_text}#{private_tag}: #{r.result}"]
      end

      events.sort_by { |time, _text| time }.map { |_time, text| text }.join("\n#{'-' * 40}\n")
    end

    # +inkling/submit - locks the thread and sends its full current
    # contents to a single staff job. If the inkling already has an
    # OPEN linked job (e.g. this is a second round of submission after
    # staff replied and the player added more), the full thread is
    # mirrored as a fresh comment onto that same job rather than
    # creating a second one - "a single job" means one ongoing job per
    # inkling for as long as it stays open, not one job per submit. If
    # the previously-linked job was closed, a new one is created,
    # since that represents a finished round of review.
    def self.submit_inkling(inkling, submitter)
      title = submission_job_title(submitter, inkling.kind)

      # For resubmissions (has an open job already), just add a note about the resubmission
      if inkling.job && inkling.job.status != "closed"
        body = "#{submitter.name} has resubmitted this inkling.\n\nUse +inkling #{inkling.id} to view the full thread."
      else
        # For initial submission, include the full thread
        body = compile_thread_text(inkling)
      end

      job = ensure_job(inkling, title, body, submitter)

      # Add a submission note to the thread itself, including the job reference
      job_ref = job ? " Linked Job ##{job.id}." : ""
      InklingMessage.create(
        inkling: inkling,
        author: submitter,
        text: "Submitted for review.#{job_ref}",
        created_at: Time.now,
        seq: next_event_seq(inkling),
        is_staff: "false",
        is_private: "false",
        is_gm_note: "true",
        is_personal: "false",
        private_recipient_ids: "")

      update_inkling(inkling, locked: "true", approval_state: "submitted")

      dispatch_inkling_submitted(inkling)
    end

    # +inkling/approve - the single source of truth for approval.
    # Staff approve the INKLING (not the job); this closes the linked
    # job as a consequence via the same Jobs.close_job API +inkling/
    # close already uses, so there is exactly one place a thread gets
    # marked approved, never two separate approvals to keep in sync.
    # There's no confirmed AresMUSH event fired when a Job's status
    # changes, so the reverse direction (approving via the job itself
    # auto-approving the inkling) isn't implemented - see the README's
    # Verification Notes.
    def self.approve_inkling(inkling, staff, message = nil)
      note = message.to_s.strip

      if !note.blank?
        InklingMessage.create(
          inkling: inkling,
          author: staff,
          text: note,
          created_at: Time.now,
          seq: next_event_seq(inkling),
          is_staff: "true",
          is_private: "false",
          is_gm_note: "false")
      end

      close_message = note.blank? ? "Inkling approved." : note
      Jobs.close_job(staff, inkling.job, close_message) if inkling.job

      update_inkling(inkling, locked: "true", approval_state: "approved")
      notify_player(inkling.character, "<inklings> Your inkling ##{inkling.id} has been approved.")

      dispatch_inkling_approved(inkling, staff)
    end

    # +inkling/needschanges - adds staff feedback to the thread (both
    # as a visible message and as a job comment), then unlocks the
    # thread so the player can revise and resubmit. Deliberately a
    # distinct, explicit action from an ordinary staff reply - see the
    # comment on Inkling#approval_state for why ordinary replies don't
    # do this.
    def self.request_changes(inkling, staff, feedback)
      InklingMessage.create(
        inkling: inkling,
        author: staff,
        text: feedback,
        created_at: Time.now,
        seq: next_event_seq(inkling),
        is_staff: "true",
        is_private: "false",
        is_gm_note: "false")

      mirror_to_job(inkling, feedback, staff) if inkling.job
      # Close the job to signal this round of review is complete; next submission will create a fresh one
      Jobs.close_job(staff, inkling.job, "Changes requested. Player to revise and resubmit.") if inkling.job

      update_inkling(inkling, player_unread: "true", locked: "false", approval_state: "needs_changes")
      notify_player(inkling.character, "<inklings> Staff have requested changes on your inkling ##{inkling.id}. Use +inkling #{inkling.id} to view their feedback.")

      dispatch_inkling_needs_changes(inkling, staff)
    end

    # +inkling/requestunlock - Player requests to reopen a completed inkling.
    # Records the request and notifies staff via the linked job, but does not unlock it.
    def self.request_unlock(inkling, player, reason)
      InklingMessage.create(
        inkling: inkling,
        author: player,
        text: "Requested unlock: #{reason}",
        created_at: Time.now,
        seq: next_event_seq(inkling),
        is_staff: "false",
        is_private: "false",
        is_gm_note: "true",
        is_personal: "false",
        private_recipient_ids: "")

      mirror_to_job(inkling, "[Unlock Request] #{player.name} requested to reopen this inkling: #{reason}", player) if inkling.job

      notify_player(inkling.character, "<inklings> Your unlock request for inkling ##{inkling.id} has been sent to staff.")
    end

    # +inkling/unlock - Staff reopens a completed inkling for further editing.
    # Sets approval_state back to "needs_changes" and unlocks the thread.
    def self.unlock_inkling(inkling, staff)
      InklingMessage.create(
        inkling: inkling,
        author: staff,
        text: "Unlocked for further editing by staff.",
        created_at: Time.now,
        seq: next_event_seq(inkling),
        is_staff: "true",
        is_private: "false",
        is_gm_note: "true",
        is_personal: "false",
        private_recipient_ids: "")

      mirror_to_job(inkling, "Inkling unlocked. Player may now edit.", staff) if inkling.job

      update_inkling(inkling, locked: "false", approval_state: "needs_changes", player_unread: "true")
      notify_player(inkling.character, "<inklings> Your inkling ##{inkling.id} has been unlocked. You can now make edits and resubmit.")
    end

    # +inkling/reward - records a reward in the generic InklingReward
    # ledger (see plugin/models/inkling_reward.rb) and, for reward
    # types this plugin can actually apply through a confirmed
    # AresMUSH API, applies it:
    #   - "xp" is applied via FS3Skills.modify_xp(char, amount) - the
    #     same helper this plugin's bonus-XP cron job already uses.
    #   - "fs3_skill" is recorded but NOT auto-applied. There's no
    #     confirmed FS3Skills API for directly changing a skill rating
    #     (only modify_xp was confirmed against real FS3 source) - see
    #     the README's Verification Notes. Staff need to apply the
    #     actual skill change themselves through FS3's normal process;
    #     this just keeps a record and notifies the player.
    #   - Any other reward_type (a future SOUL/Boons/Banes system,
    #     etc.) is recorded the same way, unapplied, by design - this
    #     method doesn't need to know about those systems for them to
    #     start using this ledger.
    # visibility is "private" (default - only the recipient sees the
    # history entry) or "all" (every participant can see it).
    def self.grant_reward(inkling, character, granted_by, reward_type, reward_key, amount, reason: nil, visibility: "private")
      InklingReward.create(
        inkling: inkling,
        character: character,
        granted_by: granted_by,
        reward_type: reward_type,
        reward_key: reward_key,
        amount: amount.to_s,
        reason: reason,
        visibility: visibility,
        created_at: Time.now)

      applied_note = nil
      if reward_type == "xp" && defined?(FS3Skills)
        FS3Skills.modify_xp(character, amount.to_i)
        applied_note = nil
      elsif reward_type == "fs3_skill"
        applied_note = " (staff: apply this #{reward_key} change through FS3's normal process - it is not applied automatically)"
      end

      summary = reward_key.to_s.blank? ? "#{amount} #{reward_type}" : "#{amount} #{reward_type} (#{reward_key})"
      history_text = "Reward granted: #{summary}.#{applied_note}"
      history_text << " Reason: #{reason}" if !reason.to_s.blank?

      InklingMessage.create(
        inkling: inkling,
        author: granted_by,
        text: history_text,
        created_at: Time.now,
        seq: next_event_seq(inkling),
        is_staff: "true",
        is_private: visibility == "all" ? "false" : "true",
        is_gm_note: "false",
        private_recipient_ids: visibility == "all" ? "" : character.id)

      notify_player(character, "<inklings> You have received a reward on inkling ##{inkling.id}: #{summary}.")

      reward = InklingReward.find(inkling_id: inkling.id).last
      dispatch_inkling_rewarded(inkling, reward) if reward
    end

    def self.notify_player(char, message)
      Login.emit_ooc_if_logged_in(char, message)
    end

    # Character names a private message's recipient IDs resolve to, for
    # display purposes (e.g. showing "[private to Bob]" in the thread
    # view). Player-authored private entries leave private_recipient_ids
    # empty (visible only to the author + staff), so those correctly
    # return an empty array - there's no specific "someone" to name in
    # that case, just "[private]".
    def self.private_recipient_names(message)
      ids = message.private_recipient_ids.to_s.split(",").map(&:strip).reject(&:empty?)
      ids.map { |id| Character[id] }.compact.map(&:name).uniq.sort
    end

    # Human-readable label for a private message's tag:
    #   - "private to <names>" when the message has explicit recipients
    #     (always true for staff-authored private entries)
    #   - "private to staff" for a player's own private entry, which
    #     has no explicit recipient stored since it's just visible to
    #     the author + staff
    #   - "private" as a fallback for any other case
    def self.private_tag_label(message, colorize: true)
      recipients = private_recipient_names(message)
      if recipients.any?
        names = colorize ? recipients.map { |n| color_name(n) } : recipients
        return "private to #{names.join(", ")}"
      end
      return "private to staff" if message.is_staff.to_s != "true"
      "private"
    end

    # Whether a viewer is allowed to see a specific message.
    # Non-private messages are always visible. Private messages are
    # visible to: staff, the message author, and any character IDs
    # listed in private_recipient_ids.
    def self.can_see_message?(message, viewer)
      return Inklings.can_manage_inklings?(viewer) if message.is_gm_note.to_s == "true"
      return message.author && message.author.id == viewer.id if message.is_personal.to_s == "true"
      return true if message.is_private.to_s != "true"
      return true if Inklings.can_manage_inklings?(viewer)
      return true if message.author && message.author.id == viewer.id
      ids = message.private_recipient_ids.to_s.split(",").map(&:strip).reject(&:empty?)
      ids.include?(viewer.id)
    end

    def self.can_see_roll?(roll, viewer)
      return true if Inklings.can_manage_inklings?(viewer)
      return true if roll.private.to_s != "true"
      return true if roll.character && roll.character.id == viewer.id
      return true if roll.creator && roll.creator.id == viewer.id
      false
    end

    def self.get_cmd_handler(client, cmd, enactor)
      case cmd.root
      when "inkling", "inklings"
        # Shared switch handlers for both singular and plural
        if cmd.switch_is?("list")
          return InklingListCmd
        elsif cmd.switch_is?("types")
          return InklingTypesCmd
        elsif cmd.switch_is?("delete")
          return InklingDeleteCmd
        elsif cmd.switch_is?("reset")
          return InklingResetCmd
        elsif cmd.switch_is?("advance") || cmd.switch_is?("reply")
          return InklingReplyCmd
        elsif cmd.switch_is?("gm")
          return InklingGmCmd
        elsif cmd.switch_is?("private")
          return InklingPrivateCmd
        elsif cmd.switch_is?("share")
          return InklingShareCmd
        elsif cmd.switch_is?("group")
          return InklingGroupCmd
        elsif cmd.switch_is?("roll")
          return InklingRollCmd
        elsif cmd.switch_is?("new")
          return InklingNewCmd
        elsif cmd.switch_is?("submit")
          return InklingSubmitCmd
        elsif cmd.switch_is?("approve")
          return InklingApproveCmd
        elsif cmd.switch_is?("needschanges")
          return InklingNeedsChangesCmd
        elsif cmd.switch_is?("reward")
          return InklingRewardCmd
        elsif cmd.switch_is?("close")
          return InklingCloseCmd
        elsif cmd.switch_is?("personal")
          return InklingPersonalCmd
        elsif cmd.switch_is?("requestunlock")
          return InklingRequestUnlockCmd
        elsif cmd.switch_is?("unlock")
          return InklingUnlockCmd
        elsif cmd.switch_is?("tag")
          return InklingTagCmd
        elsif cmd.switch_is?("untag")
          return InklingUntagCmd
        elsif all_kinds.any? { |k| cmd.switch_is?(k) }
          return InklingStartCmd
        end

        # No switch: check if there's an inkling ID argument
        stripped_raw = cmd.raw.to_s.strip.sub(/^[\/\+\=\@\&]/, "")
        inkling_root = cmd.root.to_s
        if stripped_raw =~ /^#{inkling_root}\s+\S+/i
          return InklingViewCmd
        end
        return InklingsCmd
      end
      return nil
    end

    # Per https://www.aresmush.com/tutorials/code/events.html - the
    # Dispatcher asks every plugin for a handler by event name; we
    # only care about CronEvent (see InklingXpCronHandler).
    def self.get_event_handler(event_name)
      case event_name
      when "CronEvent"
        return InklingXpCronHandler
      end
      nil
    end

    # Per https://www.aresmush.com/tutorials/code/plugins.html and
    # https://www.aresmush.com/tutorials/code/web-debug.html - web
    # portal requests are dispatched by cmd name to a handler class
    # with a handle(request) method (request.cmd / request.args), the
    # same pattern as get_cmd_handler/get_event_handler above. See
    # plugin/web/*.rb for the handler classes themselves; all of them
    # are thin adapters delegating into InklingApi/RollsApi
    # (plugin/public/), which hold the actual logic.
    def self.get_web_request_handler(cmd_name)
      case cmd_name
      when "inklings_get_inklings"
        return InklingsGetInklingsWebHandler
      when "inklings_get_inkling"
        return InklingsGetInklingWebHandler
      when "inklings_create_inkling"
        return InklingsCreateInklingWebHandler
      when "inklings_reply_to_inkling"
        return InklingsReplyToInklingWebHandler
      when "inklings_close_inkling"
        return InklingsCloseInklingWebHandler
      when "inklings_delete_inkling"
        return InklingsDeleteInklingWebHandler
      when "inklings_share_inkling"
        return InklingsShareInklingWebHandler
      when "inklings_submit_inkling"
        return InklingsSubmitInklingWebHandler
      when "inklings_get_types"
        return InklingsGetTypesWebHandler
      when "inklings_add_roll"
        return InklingsAddRollWebHandler
      when "inklings_reroll_with_luck"
        return InklingsRerollWithLuckWebHandler
      when "inklings_add_tag"
        return InklingsAddTagWebHandler
      when "inklings_remove_tag"
        return InklingsRemoveTagWebHandler
      when "inklings_add_gm_note"
        return InklingsAddGmNoteWebHandler
      when "inklings_approve_inkling"
        return InklingsApproveInklingWebHandler
      when "inklings_request_changes"
        return InklingsRequestChangesWebHandler
      when "inklings_grant_reward"
        return InklingsGrantRewardWebHandler
      end
      nil
    end

    # --- Bonus XP for a configured inkling type -------------------------
    # See the inkling_type_xp/xp_amount/award_cron settings documented
    # in game/config/inklings.yml, and InklingXpCronHandler for the
    # CronEvent hookup (https://www.aresmush.com/tutorials/code/cron.html).

    def self.xp_award_type
      Global.read_config("inklings", "inkling_type_xp") || "update"
    end

    def self.xp_award_amount
      Global.read_config("inklings", "xp_amount") || 1
    end

    def self.xp_cron_state
      InklingXpCronState.all.to_a.first || InklingXpCronState.create
    end

    # Runs one award cycle: finds every approved character who has
    # submitted an inkling of the configured type since the last cycle
    # completed, and awards them bonus XP via FS3Skills.modify_xp -
    # the same helper FS3's own XP-granting code uses (see
    # plugins/fs3skills/helpers/xp.rb) - rather than reimplementing XP
    # logic here. No-ops entirely if FS3Skills isn't loaded.
    #
    # Idempotent/restart-safe: the "period_start" identifying this
    # cycle only advances once every character has been processed and
    # InklingXpCronState is updated, at the very end. If the process
    # crashes partway through, a retry reuses the same period_start,
    # and the per-character InklingXpAward records already written
    # prevent re-awarding anyone already processed - only the
    # remaining, not-yet-processed characters get evaluated. (The one
    # remaining edge case: a crash in the narrow window between
    # granting XP and writing that character's award record could in
    # theory cause one extra award for that one character - an
    # intentionally-accepted, very small risk, favoring "might award
    # once extra in a rare crash" over "might silently skip someone.")
    def self.run_xp_award_cycle(now)
      return if !defined?(FS3Skills)

      state = xp_cron_state
      # First-ever run: look back a bounded window (1 week) rather
      # than "since the beginning of time", so turning this feature on
      # doesn't suddenly sweep in and reward every matching inkling in
      # the game's entire history.
      period_start = state.last_period_end ? time_value(state.last_period_end) : (now - (86400 * 7))
      period_key = period_start.to_s

      kind = xp_award_type
      amount = xp_award_amount

      Character.all.to_a.select { |c| c.is_approved? }.each do |char|
        next if InklingXpAward.find(character_id: char.id, period_start: period_key).any?

        submitted = Inkling.find(character_id: char.id, kind: kind).to_a.any? { |i|
          t = time_value(i.created_at)
          t > period_start && t <= now
        }
        next if !submitted

        FS3Skills.modify_xp(char, amount)

        InklingXpAward.create(
          character: char,
          period_start: period_key,
          awarded_at: Time.now,
          xp_amount: amount)

        Global.logger.info("Inklings: awarded #{amount} XP to #{char.name} for a #{kind} inkling.")
      end

      state.update(last_period_end: now.to_s)
    end

    # --- Inkling updates with timestamp tracking -----
    # Helper method that updates an inkling and sets updated_at to the
    # current time. Use this instead of calling inkling.update directly.
    def self.update_inkling(inkling, attrs)
      inkling.update(attrs.merge(updated_at: Time.now))
    end

    # --- Tag management -----

    def self.add_tag(inkling, tag)
      return unless tag
      tag = tag.to_s.strip.downcase
      return if tag.empty?
      tags = inkling.tags.to_s.split(",").map(&:strip).reject(&:empty?)
      return if tags.include?(tag)
      tags << tag
      update_inkling(inkling, tags: tags.join(","))
    end

    def self.remove_tag(inkling, tag)
      return unless tag
      tag = tag.to_s.strip.downcase
      tags = inkling.tags.to_s.split(",").map(&:strip).reject(&:empty?)
      tags.delete(tag)
      update_inkling(inkling, tags: tags.empty? ? "" : tags.join(","))
    end

    def self.get_tags(inkling)
      inkling.tags.to_s.split(",").map(&:strip).reject(&:empty?)
    end

    # --- Lifecycle event dispatch ---
    # These methods dispatch lightweight lifecycle events that other plugins
    # can listen to via the Global.dispatcher mechanism. They do not alter
    # behavior - they are pure notification hooks.
    #
    # Other plugins listen via:
    #   def on_inkling_created(event_obj); /* ... */; end
    #   Global.dispatcher.add_event_handler("inkling:created", method(:on_inkling_created))

    def self.dispatch_inkling_created(inkling)
      Global.dispatcher.dispatch("inkling:created", inkling) if Global.dispatcher.respond_to?(:dispatch)
    rescue => e
      Global.logger.warn("Inklings: Could not dispatch inkling:created - #{e.message}")
    end

    def self.dispatch_inkling_submitted(inkling)
      Global.dispatcher.dispatch("inkling:submitted", inkling) if Global.dispatcher.respond_to?(:dispatch)
    rescue => e
      Global.logger.warn("Inklings: Could not dispatch inkling:submitted - #{e.message}")
    end

    def self.dispatch_inkling_approved(inkling, staff)
      Global.dispatcher.dispatch("inkling:approved", inkling, staff) if Global.dispatcher.respond_to?(:dispatch)
    rescue => e
      Global.logger.warn("Inklings: Could not dispatch inkling:approved - #{e.message}")
    end

    def self.dispatch_inkling_needs_changes(inkling, staff)
      Global.dispatcher.dispatch("inkling:needs_changes", inkling, staff) if Global.dispatcher.respond_to?(:dispatch)
    rescue => e
      Global.logger.warn("Inklings: Could not dispatch inkling:needs_changes - #{e.message}")
    end

    def self.dispatch_inkling_shared(inkling, shared_with)
      Global.dispatcher.dispatch("inkling:shared", inkling, shared_with) if Global.dispatcher.respond_to?(:dispatch)
    rescue => e
      Global.logger.warn("Inklings: Could not dispatch inkling:shared - #{e.message}")
    end

    def self.dispatch_inkling_rewarded(inkling, reward)
      Global.dispatcher.dispatch("inkling:rewarded", inkling, reward) if Global.dispatcher.respond_to?(:dispatch)
    rescue => e
      Global.logger.warn("Inklings: Could not dispatch inkling:rewarded - #{e.message}")
    end
  end
end
