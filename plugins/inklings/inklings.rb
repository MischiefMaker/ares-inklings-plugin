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
    # Reuse the Jobs plugin's existing staff permission gate so anyone who
    # manages jobs can also manage staff-side inklings.
    def self.can_manage_inklings?(enactor)
      Jobs.can_manage_jobs?(enactor)
    end

    STAFF_KINDS   = ["hint", "vision", "nudge", "hook"]
    PLAYER_KINDS  = ["initiative", "request", "update", "pitch", "goal"]
    SHARED_KINDS  = ["secret"]
    ALL_KINDS     = STAFF_KINDS + PLAYER_KINDS + SHARED_KINDS

    # Kinds that can be created by unapproved characters (during chargen).
    # All other player commands require an approved character.
    CHARGEN_KINDS = ["secret", "goal"]

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

    def self.staff_target_warning(char)
      return nil if !char
      return "%xyWarning:%xn #{char.name} is not approved. You're creating this inkling on an unapproved character." if !char.is_approved?
      return "%xyWarning:%xn #{char.name} can manage staff-side systems. Make sure this inkling belongs on a real character, not a staff utility/player record." if Inklings.can_manage_inklings?(char)
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

    def self.find_matching_group_chars(group_name)
      query = group_name.to_s.strip
      return [] if query.blank?

      all_chars = Character.all.to_a

      if query.include?(":")
        group_key, group_value = query.split(":", 2).map(&:strip)
        return [] if group_key.blank? || group_value.blank?

        return all_chars.select { |c|
          c.respond_to?(:group) && c.group(group_key).to_s.downcase == group_value.downcase
        }.uniq(&:id)
      end

      group_keys = defined?(Demographics) ? Demographics.all_groups.keys : []

      all_chars.select { |c|
        next false unless c.respond_to?(:group)
        group_keys.any? { |key| c.group(key).to_s.downcase == query.downcase }
      }.uniq(&:id)
    end

    def self.add_participant(inkling, target, added_by)
      return :already_shared if Inklings.is_participant?(inkling, target)

      InklingParticipant.create(
        inkling: inkling,
        character: target,
        added_at: Time.now)

      Inklings.notify_player(target,
        "<inklings> #{added_by.name} has shared an inkling with you. Use +inkling #{inkling.id} to view it.")

      :added
    end

    # Fixed job category so inkling-linked jobs land on their own board.
    # Create this category in-game with: job/category create INKLINGS
    # (override in inklings.yml if you want a different category name).
    def self.job_category
      Global.read_config("inklings", "job_category") || "INKLINGS"
    end

    # Makes sure the given inkling has a linked job, so staff are
    # notified. Creates one if it doesn't have one yet; otherwise mirrors
    # the message onto the existing job as a comment.
    def self.ensure_job(inkling, title, message, enactor)
      if inkling.job
        mirror_to_job(inkling, message, enactor)
        return inkling.job
      else
        result = Jobs.create_job(self.job_category, title, message, enactor)
        if result[:error]
          Global.logger.error("Inklings: Failed to create job for inkling ##{inkling.id} - #{result[:error]}")
          return nil
        end
        job = result[:job]
        inkling.update(job: job)
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
          is_staff: "true",
          source_job_reply: reply)

        new_messages = true
      end

      if new_messages
        inkling.update(player_unread: "true")
        # NOTE: t() is a CommandHandler helper and isn't available here,
        # since this runs from a plain module method, not a command
        # instance. Using a plain string instead - swap in your game's
        # actual locale lookup (e.g. Global.locales.t(...)) if you want
        # this localized.
        Inklings.notify_player(inkling.character, "<inklings> You have a new inkling message. Use +inklings to view it.")
      end
    end

    def self.notify_player(char, message)
      Login.emit_ooc_if_logged_in(char, message)
    end

    # Whether a viewer is allowed to see a specific message.
    # Non-private messages are always visible. Private messages are
    # visible to: staff, the message author, and any character IDs
    # listed in private_recipient_ids.
    def self.can_see_message?(message, viewer)
      return Inklings.can_manage_inklings?(viewer) if message.is_gm_note.to_s == "true"
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
      when "inkling"
        if cmd.switch_is?("list")
          return InklingListCmd
        elsif cmd.switch_is?("delete")
          return InklingDeleteCmd
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
        elsif cmd.switch_is?("close")
          return InklingCloseCmd
        elsif ALL_KINDS.any? { |k| cmd.switch_is?(k) }
          return InklingStartCmd
        else
          return InklingViewCmd
        end
      when "inklings"
        if cmd.switch_is?("delete")
          return InklingDeleteCmd
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
        elsif cmd.switch_is?("close")
          return InklingCloseCmd
        elsif ALL_KINDS.any? { |k| cmd.switch_is?(k) }
          return InklingStartCmd
        end

        stripped_raw = cmd.raw.to_s.strip.sub(/^[\/\+\=\@\&]/, "")
        if stripped_raw =~ /^inklings\s+\S+/i
          return InklingViewCmd
        end
        return InklingsCmd
      end
      return nil
    end
  end
end
