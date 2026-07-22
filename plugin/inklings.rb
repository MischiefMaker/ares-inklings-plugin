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
    # game/config/inklings.yml. Defaults to "manage_apps" (the standard
    # AresMUSH permission for character application management). Override
    # in config if your game's staff structure differs.
    def self.can_manage_inklings?(enactor)
      return false if !enactor
      permission = Global.read_config("inklings", "manage_permission") || "manage_apps"
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

    # Whether the chargen-inkling integration is turned on. Controlled by
    # the "chargen_enabled" setting in game/config/inklings.yml; defaults to
    # true when the setting is absent. When false, the whole chargen-inkling
    # feature goes dormant - no chargen prompt, no app-review requirement, no
    # draft->inkling conversion on approval, and the profile/chargen custom
    # fields return nothing. Nothing else in the plugin is affected.
    def self.chargen_enabled?
      enabled = Global.read_config("inklings", "chargen_enabled")
      enabled.nil? ? true : enabled
    end

    # Inkling types offered/required during character generation. These are
    # intentionally hardcoded to secret and goal - the chargen web form and
    # the Character draft attributes (see
    # plugin/models/character_inkling_fields.rb) are built specifically for
    # these two, so the list is not config-driven. Returns an empty array
    # when chargen is disabled (see chargen_enabled?), which cleanly turns
    # the feature off everywhere that consumes this list.
    def self.chargen_required_types
      return [] unless chargen_enabled?
      ["secret", "goal"]
    end

    # The character's in-progress chargen draft(s) - see
    # plugin/models/character_inkling_fields.rb - as display-ready hashes,
    # one per chargen-required kind with non-blank draft text. Used to
    # surface these to staff on the web portal Inklings tab before the
    # character is approved, since they aren't real Inkling records yet
    # and don't otherwise show up anywhere in that list. Once the character
    # is approved, Inklings.character_approved converts each into a real
    # Inkling and clears the draft field, so this naturally returns nothing
    # for an approved character - no separate "is this stale" check needed.
    def self.chargen_drafts(char)
      return [] unless char
      drafts = []
      chargen_required_types.each do |kind|
        next unless char.respond_to?("inkling_#{kind}_title")
        title = char.send("inkling_#{kind}_title")
        text = char.send("inkling_#{kind}_text")
        next if title.to_s.blank? && text.to_s.blank?

        drafts << {
          kind: kind,
          label: kind_label(kind),
          color: (type_config[kind] || {})["color"] || "secondary",
          title: title,
          # Raw, not run through format_markdown_for_html - matches how
          # inkling message text is already handled elsewhere (see
          # format_inkling_summary / inkling-detail-modal.hbs's
          # {{msg.text}}): plain text, escaped by the template on render.
          text: text
        }
      end
      drafts
    end

    def self.valid_kind?(kind)
      type_config.key?(kind.to_s)
    end

    # Kinds this viewer is allowed to create (via +inkling/create or the
    # web portal's "New Inkling" picker). Staff can create any type.
    # An unapproved, non-staff viewer can only create kinds explicitly
    # flagged chargen: true in config (none, by default - see
    # chargen_required_types, which uses its own separate draft
    # mechanism instead of this path); everyone else is limited to
    # player/shared kinds. Mirrors the authorization check in
    # InklingApi.create_inkling - kept as a single source of truth here
    # rather than duplicated client-side, since this exists purely to
    # build user-facing type lists like the web portal's
    # create-inkling dropdown. Getting this right also matters for
    # hiding "+ New Inkling" entirely in the web portal when it would
    # be empty - see webportal/templates/components/inklings-tab.hbs.
    def self.creatable_kinds(viewer)
      return all_kinds if can_manage_inklings?(viewer)
      return chargen_kinds - staff_kinds if viewer && !viewer.is_approved?
      player_kinds + shared_kinds
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

    # Every inkling in the game, regardless of owner/participant/group
    # access, filtered by status and sorted newest-first - the same
    # filter/sort shape InklingsCmd and InklingApi.get_inklings already
    # use per-character, just without the character scoping. Shared by
    # the admin MUSH command and the admin web endpoint so query/
    # ordering logic isn't duplicated between them - each caller does
    # its own pagination on top (BorderedPagedListTemplate for MUSH,
    # a manual slice for the web JSON), since those are different
    # rendering targets, but the underlying list is identical.
    def self.all_inklings_query(status_filter: "open")
      inklings = Inkling.all.to_a
      inklings = case status_filter.to_s
      when "closed"
        inklings.select { |i| i.status == "closed" }
      when "all"
        inklings
      else
        inklings.select { |i| i.status == "open" }
      end
      inklings.sort_by { |i| time_value(i.created_at) }.reverse
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

    # --- Shared CommandHandler check conditions --------------------------
    # These three answer the same yes/no question every +inkling
    # subcommand's own check_* method already re-derives from
    # can_manage_inklings?/is_participant? - centralized here so the
    # actual condition lives in exactly one place, while each command
    # still owns its own check_* method (same name, same alphabetical-
    # ordering position as before) since only CommandHandler instances
    # can call t() to localize the resulting error message. Nil-safe:
    # each returns false for a nil inkling, so callers don't need their
    # own separate nil guard before calling these.

    # Staff, or an explicit/group participant (owner, creator, shared
    # individually, or via a matching group) - used by commands that
    # read or reply to a thread (view, comment, personal, private, reply).
    def self.can_view_or_reply?(inkling, char)
      return false if !inkling
      return true if can_manage_inklings?(char)
      is_participant?(inkling, char)
    end

    # Staff, or the inkling's own owner - used by commands that manage
    # thread-level state (close, tag/untag, share, group-share).
    def self.owner_or_staff?(inkling, char)
      return false if !inkling
      return true if can_manage_inklings?(char)
      inkling.character == char
    end

    # Whether inkling is closed. Nil-safe (a nil inkling isn't "closed" -
    # let the caller's own check_valid_inkling report the real error).
    def self.closed?(inkling)
      inkling && inkling.status == "closed"
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

      Inklings.notify_shared(target, inkling, added_by.name)

      :added
    end

    # Adds group_specs (assumed already validated via valid_group_spec? -
    # this method doesn't re-check) to inkling's shared_groups list, then
    # notifies any currently-approved character whose group membership
    # already matches one of the newly-added specs. Shared by both
    # +inkling/group (InklingGroupCmd) and the web portal's group-share
    # action (InklingApi.share_group) so the actual sharing/notification
    # logic lives in exactly one place. Returns the specs that were
    # actually new (already-set specs are silently skipped, same as
    # add_participant's :already_shared) and who got notified, so each
    # caller can phrase its own success/failure message.
    def self.add_group_share(inkling, group_specs, sharer)
      existing_specs = split_list(inkling.shared_groups)
      new_specs = group_specs.reject { |g| existing_specs.any? { |e| e.downcase == g.downcase } }
      return { new_specs: [], notified: [] } if new_specs.empty?

      combined = (existing_specs + new_specs).uniq.join(",")
      update_inkling(inkling, shared_groups: combined)

      # Notify currently-approved characters who match the new specs.
      # char_matches_group_spec? is checked before is_participant_explicit?
      # since it's pure computation with no DB round-trip, letting it
      # eliminate most candidates before the pricier explicit-participant
      # lookup runs.
      notified = []
      new_specs.each do |spec|
        Character.all.to_a.select { |c|
          c.is_approved? &&
            c.id != sharer.id &&
            char_matches_group_spec?(c, spec) &&
            !is_participant_explicit?(inkling, c)
        }.each do |char|
          notify_shared(char, inkling, sharer.name, with_group: true)
          notified << char.name
        end
      end

      { new_specs: new_specs, notified: notified.uniq.sort }
    end

    # Characters who can be picked as an explicit private-message
    # recipient: the thread's subject character (unless staff) plus
    # anyone explicitly added as a participant (unless staff) - excluding
    # any staff members, same as shared_with_names below. Deliberately
    # does NOT expand group shares into individual characters - a group
    # spec (e.g. "Faction:Navy") isn't a fixed list to pick one name from
    # the way an explicit share is. Backs both shared_with_names (MUSH/web
    # display) and the web reply form's private-target dropdown (see
    # InklingApi.format_shared_with's participants key and
    # InklingApi.reply_to_inkling's private_target_id) - +inkling/private
    # already lets staff name an explicit target on the MUSH side (see
    # InklingPrivateCmd); this is what the web picker validates against
    # for parity.
    def self.addressable_participants(inkling)
      participants = []

      if inkling.character && !can_manage_inklings?(inkling.character)
        participants << inkling.character
      end

      InklingParticipant.find(inkling_id: inkling.id).each do |p|
        next if !p.character
        next if can_manage_inklings?(p.character)
        participants << p.character
      end

      participants.uniq(&:id).sort_by(&:name)
    end

    # Character names shown in the "Shared With" section of a thread -
    # see addressable_participants for exactly who counts.
    def self.shared_with_names(inkling)
      addressable_participants(inkling).map(&:name)
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

    # --- Per-character read tracking (InklingReadReceipt) ---------------
    # Separate from Inkling#player_unread, which only ever reflects the
    # OWNING character's state. These track, per character + inkling,
    # how far into the thread that specific character has read - so
    # "unread" is meaningful for shared/group participants too. Powers
    # +inkling/new (InklingNewUnreadCmd) and the on-login catch-up
    # check (CharConnectedEventHandler).

    def self.find_read_receipt(inkling, char)
      InklingReadReceipt.find(inkling_id: inkling.id, character_id: char.id).first
    end

    # Records that char has now seen everything currently on inkling.
    # Called whenever the full thread is actually rendered to them (see
    # show_inkling) - never from a list view, which only shows
    # titles/counts, not content.
    def self.mark_read(inkling, char)
      seq = next_event_seq(inkling) - 1
      receipt = find_read_receipt(inkling, char)
      if receipt
        receipt.update(last_read_seq: seq)
      else
        InklingReadReceipt.create(inkling: inkling, character: char, last_read_seq: seq)
      end
    end

    # Timestamp of the earliest event on inkling that char hasn't seen
    # yet and didn't post themselves, or nil if they're fully caught up
    # - a character's own posts never count as unread for them, even
    # before they next explicitly view the thread, so posting an update
    # doesn't immediately re-flag your own thread in your own
    # +inkling/new queue. Only counts events char can actually see
    # (respects the same private/GM/personal visibility rules the
    # detail view itself uses). One pass over messages+rolls computes
    # both "is this unread" (see has_unread_for?) and "what's the
    # earliest unread event" (for +inkling/new's oldest-first ordering)
    # together, since unread_inklings_for needs both per candidate and
    # there's no reason to walk the same records twice.
    def self.earliest_unread_time(inkling, char)
      baseline = find_read_receipt(inkling, char)&.last_read_seq.to_i

      times = []
      inkling.messages.to_a.each do |m|
        next unless m.seq.to_i > baseline && (!m.author || m.author.id != char.id) && can_see_message?(m, char)
        times << time_value(m.created_at)
      end
      inkling.rolls.to_a.each do |r|
        next unless r.seq.to_i > baseline && (!r.creator || r.creator.id != char.id) && can_see_roll?(r, char)
        times << time_value(r.created_at)
      end

      times.min
    end

    def self.has_unread_for?(inkling, char)
      !earliest_unread_time(inkling, char).nil?
    end

    # Every inkling char has access to (own, explicitly shared, or via
    # a matching group) with unread content, oldest-unread-first - the
    # queue +inkling/new works through. No staff special-casing: this
    # only looks at inklings char can actually reach as a participant,
    # same scope +inklings already uses.
    def self.unread_inklings_for(char)
      own = Inkling.find(character_id: char.id).to_a
      shared = InklingParticipant.find(character_id: char.id).map(&:inkling).compact
      group = Inkling.all.to_a.select { |i| is_group_participant?(i, char) }

      candidates = (own + shared + group).uniq(&:id).select { |i| i.status == "open" }

      candidates.map { |i| [i, earliest_unread_time(i, char)] }
        .reject { |(_i, time)| time.nil? }
        .sort_by { |(_i, time)| time }
        .map(&:first)
    end

    # Search across viewable inklings by query text, searching tags first,
    # then titles, then message text (in priority order). Returns results
    # sorted by relevance: tag matches highest, title matches next, text
    # matches lowest.
    #
    # Visibility mirrors can_view_inkling? elsewhere in this file: staff
    # (can_manage_inklings?) search every inkling in the game, exactly like
    # +inkling/admin and the admin web page they're searching from; everyone
    # else is scoped to their own/shared/group inklings, same as
    # unread_inklings_for. Message text is matched through can_see_message?
    # so a GM note, another player's personal note, or a private message not
    # addressed to char can never surface or rank a thread via content the
    # viewer isn't allowed to read.
    #
    # Unlike all_inklings_query's callers (which slice to a page BEFORE
    # formatting), this scores every viewable candidate before sorting -
    # relevance ranking across pages inherently needs every candidate's
    # score up front, there's no way to know what belongs on page 2 without
    # first ranking everything. Fine at this plugin's scale; a game with a
    # very large inkling volume searched by staff (viewable = every inkling
    # in the game) would want a real search index instead of scoring
    # in-process on every request.
    def self.search_inklings(query, char)
      return [] if query.to_s.strip.blank?

      query_lower = query.to_s.strip.downcase

      viewable = if can_manage_inklings?(char)
        Inkling.all.to_a
      else
        own = Inkling.find(character_id: char.id).to_a
        shared = InklingParticipant.find(character_id: char.id).map(&:inkling).compact
        group = Inkling.all.to_a.select { |i| is_group_participant?(i, char) }
        (own + shared + group).uniq(&:id)
      end

      # Score each inkling based on matches (higher scores first)
      scored = viewable.map do |inkling|
        score = 0

        # Tags (highest priority)
        score += 100 * get_tags(inkling).count { |tag| tag.downcase.include?(query_lower) }

        # Title (medium priority)
        score += 50 if inkling.title.to_s.downcase.include?(query_lower)

        # Message text (lowest priority) - only messages this viewer may see
        inkling.messages.to_a.each do |msg|
          next unless can_see_message?(msg, char)
          score += 10 if msg.text.to_s.downcase.include?(query_lower)
        end

        score > 0 ? [inkling, score] : nil
      end.compact

      # Sort by score descending
      scored.sort_by { |(_i, score)| -score }.map(&:first)
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
        created_at: roll.created_at,
        rolled_at: roll.rolled_at
      }
    end

    # Fixed job category so inkling-linked jobs land on their own board.
    # Defaults to "Plots" (see game/config/inklings.yml, which ships
    # with that value set explicitly) - override job_category in
    # inklings.yml if your game uses a different category name.
    def self.job_category
      Global.read_config("inklings", "job_category") || "Plots"
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
        # instance. notify_new_message builds its own plain string rather
        # than going through the locale system for exactly this reason -
        # swap in your game's actual locale lookup (e.g.
        # Global.locales.t(...)) there if you want this localized.
        Inklings.notify_new_message(inkling.character, inkling)
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
    # since_seq: 0 (default) includes the whole thread. Pass a higher
    # value (see last_submission_seq) to only include events added
    # after that point - used by submit_inkling so resubmissions only
    # push what staff haven't already seen, instead of the full thread
    # every time.
    def self.compile_thread_text(inkling, since_seq: 0)
      events = []

      inkling.messages.to_a.each do |m|
        next if m.seq.to_i <= since_seq
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
        next if r.seq.to_i <= since_seq
        who = r.creator ? r.creator.name : "?"
        target = r.target_character ? r.target_character.name : r.npc_name
        target_text = target.to_s.blank? ? "" : " for #{target}"
        private_tag = r.private.to_s == "true" ? " [private]" : ""
        ref = event_ref(inkling, r.seq)
        events << [time_value(r.created_at), "##{ref} #{format_time(r.created_at, '%m/%d %H:%M')} #{who} rolled #{r.roll_spec}#{target_text}#{private_tag}: #{r.result}"]
      end

      events.sort_by { |time, _text| time }.map { |_time, text| text }.join("\n#{'-' * 40}\n")
    end

    # Seq of the most recent "submitted" marker on this inkling (see
    # submit_inkling, which leaves one every time it runs), or 0 if
    # it's never been submitted before. This is the boundary for what
    # staff have already been shown - submit_inkling uses it to only
    # push messages/rolls added after the last submission into the
    # job, instead of the whole thread every time, however many rounds
    # of back-and-forth revision have happened. No separate "last
    # submission" field needed since each submission already leaves
    # its own permanently-ordered marker in the thread.
    def self.last_submission_seq(inkling)
      submitted_seqs = inkling.messages.to_a.select { |m| m.message_type == "submitted" }.map { |m| m.seq.to_i }
      submitted_seqs.max || 0
    end

    # A single message rendered as its own block for the player-facing
    # detail view (+inkling <id> / +inkling/new) - a metadata line
    # (reference number, timestamp, author, tags) followed by a blank
    # line and then the message text on its own, since entries can run
    # to multiple paragraphs. Module-level (not on a CommandHandler
    # instance) so both InklingViewCmd and InklingNewUnreadCmd can
    # share it via render_inkling_view - see the note there on why it
    # can't use t().
    def self.format_view_message_block(inkling, message)
      who = message.author ? color_name(message.author.name) : "?"
      tags = []

      case message.message_type.to_s
      when "submitted"
        tags << "Submitted"
      when "approved"
        tags << "Approved"
      when "needs_changes"
        tags << "Needs Changes"
      when "reward"
        tags << "Reward"
      end

      tags << "staff" if message.is_staff == "true" && message.message_type.to_s.empty?
      tags << "gm" if message.is_gm_note == "true"
      tags << private_tag_label(message) if message.is_private == "true"
      tags << "private to you" if message.is_personal == "true"
      tag_text = tags.empty? ? "" : " [#{tags.join(", ")}]"

      ref = event_ref(inkling, message.seq)
      meta = "##{ref} #{format_time(message.created_at, '%m/%d %H:%M')} #{who}#{tag_text}"

      "#{meta}\n\n#{message.text}"
    end

    # "#<id> [TYPE] Title" - the compact identifying header used both
    # as the prefix on the full detail view (render_inkling_view) and
    # standalone by +inkling/comment (InklingCommentCmd), which shows a
    # single numbered entry without the rest of the thread and still
    # needs to say which inkling that entry belongs to.
    def self.inkling_short_header(inkling)
      title_text = inkling.title.to_s.blank? ? kind_label(inkling.kind) : inkling.title
      "##{inkling.id} [#{color_type(inkling.kind.upcase)}] #{color_title(title_text)}"
    end

    def self.format_view_roll_block(inkling, roll)
      who = roll.creator ? color_name(roll.creator.name) : "?"
      target_name = roll.target_character ? roll.target_character.name : roll.npc_name
      target_text = target_name.to_s.blank? ? "" : " for #{color_name(target_name)}"
      private_tag = roll.private == "true" ? " [private]" : ""
      ref = event_ref(inkling, roll.seq)
      "##{ref} #{format_time(roll.created_at, '%m/%d %H:%M')} #{who}#{private_tag} [Roll]\n\nRolled #{roll.roll_spec}#{target_text}: #{roll.result}"
    end

    # Full formatted display for one inkling from viewer's perspective:
    # header title (with lock tag), shared-with summary, every
    # message/roll they can see in chronological order, linked-job
    # note, and the submit/unlock hints - exactly what +inkling <id>
    # shows. Shared with +inkling/new (InklingNewUnreadCmd, which shows
    # the same detail view for the next unread thread) so there's one
    # place that owns "what does viewing an inkling look like," not two
    # copies that can drift.
    #
    # Plain module method, not a CommandHandler instance method, so it
    # can't call t() (see Lesson 20 in the dev guide) - the handful of
    # strings below that would normally go through the locale system
    # (shared-with labels, the "not yet submitted" reminder) are
    # written out directly instead, matching locale_en.yml's current
    # wording. InklingViewCmd no longer needs those specific locale
    # keys as a result.
    def self.render_inkling_view(inkling, viewer)
      separator = "-" * 60
      blocks = []

      inkling.messages.to_a.sort_by { |m| time_value(m.created_at) }
        .select { |m| can_see_message?(m, viewer) }
        .each { |m| blocks << [time_value(m.created_at), format_view_message_block(inkling, m)] }

      inkling.rolls.to_a.sort_by { |r| time_value(r.created_at) }.each do |roll|
        next if !can_see_roll?(roll, viewer)
        blocks << [time_value(roll.created_at), format_view_roll_block(inkling, roll)]
      end

      ordered = blocks.sort_by { |time, _block| time }.map(&:last)
      body = ordered.join("\n#{separator}\n")

      shared_lines = []
      shared_names = shared_with_names(inkling)
      shared_lines << "Players: #{shared_names.map { |n| color_name(n) }.join(", ")}" if shared_names.any?
      group_list = shared_group_list(inkling)
      shared_lines << "Groups: #{group_list.join(", ")}" if group_list.any?
      tag_list = get_tags(inkling)
      shared_lines << "Tags: #{tag_list.join(", ")}" if tag_list.any?
      shared_with_line = shared_lines.any? ? "\n\n[Shared With]\n#{shared_lines.join("\n")}" : ""

      lock_tag = ""
      if inkling.locked == "true"
        if inkling.approval_state == "approved"
          lock_tag = " %xh%cgLOCKED - Completed%xn"
        elsif inkling.approval_state == "submitted"
          lock_tag = " %xh%crLOCKED - Awaiting Staff Review%xn"
        else
          lock_tag = " %xh%crLOCKED%xn"
        end
      end
      title = "#{inkling_short_header(inkling)} (#{inkling.status})#{lock_tag}"

      shared_with_first = shared_with_line ? "#{shared_with_line}\n\n" : ""
      job_line = inkling.job ? "\n\n(Linked job ##{inkling.job.id}, status #{inkling.job.status})" : ""

      submit_reminder = (!can_manage_inklings?(viewer) && inkling.character == viewer && inkling.locked != "true" && inkling.status != "closed") ?
        "\n\n%xyThis Inkling is not currently under review.%xn Use +inkling/submit #{inkling.id} whenever you want staff to review it." : ""

      unlock_note = (inkling.locked == "true" && inkling.approval_state == "approved" && inkling.character == viewer) ?
        "\n\n%xhNeed this reopened? Use +inkling/requestunlock #{inkling.id}=<reason> to contact staff.%xn" : ""

      { title: title, body: shared_with_first + body + job_line + submit_reminder + unlock_note }
    end

    # Renders inkling's full detail view for viewer and emits it to
    # client, then marks it read for viewer - both the general
    # per-character receipt (mark_read) and, when viewer is the
    # inkling's own owner, the legacy player_unread flag other views
    # (+inklings, +inkling/list) still read. Shared by +inkling <id>
    # (InklingViewCmd) and +inkling/new (InklingNewUnreadCmd) - the
    # only difference between the two commands is how they pick WHICH
    # inkling to show; once picked, viewing it works identically.
    def self.show_inkling(inkling, viewer, client)
      sync_job_replies(inkling)
      view = render_inkling_view(inkling, viewer)
      template = BorderedDisplayTemplate.new view[:body], view[:title]
      client.emit template.render

      update_inkling(inkling, player_unread: "false") if inkling.character == viewer
      mark_read(inkling, viewer)
    end

    # +inkling/submit - locks the thread and sends staff only what's
    # new since the last submission (or the full thread, on the very
    # first submission - see last_submission_seq). If the inkling
    # already has an OPEN linked job (e.g. staff unlocked it without
    # closing the job - see Inklings.unlock_inkling), that new content
    # is mirrored as a fresh comment onto the same job rather than
    # creating a second one - "a single job" means one ongoing job per
    # inkling for as long as it stays open, not one job per submit. If
    # the previously-linked job was closed (e.g. after
    # +inkling/needschanges), a new one is created, since that
    # represents a finished round of review.
    # Returns { success: true, job: job } on success, or { error: "..." }
    # if the linked job couldn't be created. On failure, the thread is
    # deliberately left as-is (not locked, not marked "submitted") rather
    # than silently proceeding - ensure_job already logs the underlying
    # cause, but a job failure means staff were never actually notified,
    # so locking the thread anyway would strand the player in a "submitted,
    # awaiting review" state nobody is actually reviewing, with
    # +inkling/submit blocked from retrying (see check_not_already_locked).
    def self.submit_inkling(inkling, submitter)
      title = submission_job_title(submitter, inkling.kind)
      prior_seq = last_submission_seq(inkling)

      if prior_seq > 0
        delta = compile_thread_text(inkling, since_seq: prior_seq)
        delta = "(No new messages or rolls since the last submission.)" if delta.blank?
        body = "#{submitter.name} has resubmitted this inkling. Showing only what's new since the last submission - use +inkling #{inkling.id} to view the full thread.\n\n#{delta}"
      else
        body = compile_thread_text(inkling)
      end

      job = ensure_job(inkling, title, body, submitter)
      return { error: "Could not notify staff of this submission - please try again, or contact staff directly if the problem persists." } if !job

      # Add a submission note to the thread itself, including the job reference
      InklingMessage.create(
        inkling: inkling,
        author: submitter,
        text: "Submitted for review. Linked Job ##{job.id}.",
        created_at: Time.now,
        seq: next_event_seq(inkling),
        is_staff: "false",
        is_private: "false",
        is_gm_note: "true",
        is_personal: "false",
        private_recipient_ids: "",
        message_type: "submitted")

      update_inkling(inkling, locked: "true", approval_state: "submitted")

      dispatch_inkling_submitted(inkling)

      { success: true, job: job }
    end

    # +inkling/approve - the single source of truth for approval.
    # Staff approve the INKLING (not the job); this closes the linked
    # job as a consequence via the same Jobs.close_job API +inkling/
    # close already uses, so there is exactly one place a thread gets
    # marked approved, never two separate approvals to keep in sync.
    # There's no confirmed AresMUSH event fired when a Job's status
    # changes, so the reverse direction (approving via the job itself
    # auto-approving the inkling) isn't implemented.
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
          is_gm_note: "false",
          message_type: "approved")
      else
        # Add a system message to mark approval even if no feedback was provided
        InklingMessage.create(
          inkling: inkling,
          author: staff,
          text: "Inkling approved.",
          created_at: Time.now,
          seq: next_event_seq(inkling),
          is_staff: "true",
          is_private: "false",
          is_gm_note: "true",
          message_type: "approved")
      end

      close_message = note.blank? ? "Inkling approved." : note
      Jobs.close_job(staff, inkling.job, close_message) if inkling.job

      update_inkling(inkling, locked: "true", approval_state: "approved")
      notify_player(inkling.character, "<inklings> Your inkling ##{inkling.id} has been approved. Use +inkling #{inkling.id} to view it.", inkling: inkling)

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
        is_gm_note: "false",
        message_type: "needs_changes")

      mirror_to_job(inkling, feedback, staff) if inkling.job
      # Close the job to signal this round of review is complete; next submission will create a fresh one
      Jobs.close_job(staff, inkling.job, "Changes requested. Player to revise and resubmit.") if inkling.job

      update_inkling(inkling, player_unread: "true", locked: "false", approval_state: "needs_changes")
      notify_player(inkling.character, "<inklings> Staff have requested changes on your inkling ##{inkling.id}. Use +inkling #{inkling.id} to view their feedback.", inkling: inkling)

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

      notify_player(inkling.character, "<inklings> Your unlock request for inkling ##{inkling.id} has been sent to staff.", inkling: inkling)
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
      notify_player(inkling.character, "<inklings> Your inkling ##{inkling.id} has been unlocked. You can now make edits and resubmit - use +inkling #{inkling.id} to view it.", inkling: inkling)
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
    #     the "FS3 skill rewards require manual application" bullet in
    #     the README's Known Limitations. Staff need to apply the
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
        private_recipient_ids: visibility == "all" ? "" : character.id,
        message_type: "reward")

      notify_player(character, "<inklings> You have received a reward on inkling ##{inkling.id}: #{summary}. Use +inkling #{inkling.id} to view it.", inkling: inkling)

      reward = InklingReward.find(inkling_id: inkling.id).last
      dispatch_inkling_rewarded(inkling, reward) if reward
    end

    # inkling: optional - when given, also persists an offline notification
    # via Login.notify (the same AresMUSH notification infrastructure Jobs
    # uses - see Jobs.create_job's own Login.notify(c, :job, ...) call).
    # That records a LoginNotice the player sees in the web portal's
    # Notifications tab whether or not they're currently online, unlike
    # emit_ooc_if_logged_in below, which only reaches an already-connected
    # client. Omitted (nil) only for notifications with no single inkling
    # to reference.
    def self.notify_player(char, message, inkling: nil)
      Login.emit_ooc_if_logged_in(char, message)
      Login.notify(char, :inkling, message, inkling.id) if inkling && Login.respond_to?(:notify)
    end

    # Centralized "new message" notice - every place a reply/message lands
    # on a thread the recipient didn't just author (player reply seen by
    # staff via job mirror, staff reply, staff-started thread, job reply
    # mirrored back into the thread) used to build this text separately,
    # and two of those call sites couldn't reach the t() locale helper at
    # all (plain module code, not a CommandHandler), so they silently drifted
    # to a duplicate string with no ID. One helper, always includes the ID.
    def self.notify_new_message(char, inkling)
      notify_player(char, "<inklings> You have a new message on inkling ##{inkling.id}. Use +inkling #{inkling.id} to view it.", inkling: inkling)
    end

    # Centralized "shared with you" notice, for both individual shares
    # (+inkling/share, admin Add Inkling web form) and group shares
    # (+inkling/group) - same wording, just "with you" vs "with your group".
    def self.notify_shared(char, inkling, sharer_name, with_group: false)
      target = with_group ? "with your group" : "with you"
      notify_player(char, "<inklings> #{color_name(sharer_name)} has shared an inkling #{target}. Use +inkling #{inkling.id} to view it.", inkling: inkling)
    end

    # "You have a new inkling" notice for inklings staff create on a
    # player's behalf (+inkling/admin, admin web Add Inkling). Its own
    # helper (rather than folding into notify_new_message) since it's a
    # distinct event - a brand-new thread, not a message on an existing one.
    def self.notify_new_inkling(char, inkling)
      notify_player(char, "<inklings> You have a new inkling (##{inkling.id}). Use +inkling #{inkling.id} to view it.", inkling: inkling)
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
        elsif cmd.switch_is?("admin")
          return InklingAdminCmd
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
        elsif cmd.switch_is?("rollprivate")
          return InklingRollPrivateCmd
        elsif cmd.switch_is?("comment")
          return InklingCommentCmd
        elsif cmd.switch_is?("new")
          # bbnew-style: cycles through unread inklings, oldest first.
          # Deliberately takes no arguments - see InklingNewUnreadCmd.
          # Kind-based creation is +inkling/create, a separate switch,
          # so the two never collide.
          return InklingNewUnreadCmd
        elsif cmd.switch_is?("create")
          return InklingCreateCmd
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
        elsif chargen_required_types.any? { |k| cmd.switch_is?("view-#{k}") }
          return InklingViewChargenDraftCmd
        elsif all_kinds.any? { |k| cmd.switch_is?(k) }
          kind = all_kinds.find { |k| cmd.switch_is?(k) }
          # Self-targeted (no "=" - a target means staff acting on someone
          # else's behalf, which always goes through InklingStartCmd, whose
          # own permission check lets staff bypass the approval requirement)
          # use of a chargen-required kind by an unapproved character is the
          # MUSH-side draft flow, not real Inkling creation. See
          # InklingChargenDraftCmd for the full explanation. Once the
          # character is approved, or chargen is disabled
          # (chargen_required_types is then empty), this condition is never
          # true and the kind switch behaves normally via InklingStartCmd.
          self_targeted = !cmd.args.to_s.include?("=")
          if self_targeted && !enactor.is_approved? && Inklings.chargen_required_types.include?(kind)
            return InklingChargenDraftCmd
          end
          return InklingStartCmd
        elsif cmd.switch_is?("closed") || cmd.switch_is?("all")
          # Status filters on the enactor's own list (see the "+inklings/closed"
          # / "+inklings/all" doc comment on InklingsCmd) - not meta-commands
          # of their own. InklingsCmd re-checks cmd.switch_is? on these same
          # values inside #handle to pick the filter; this branch only routes
          # to it explicitly instead of relying on falling out of the chain
          # unmatched, which the catch-all right below would otherwise turn
          # into a wrongly-reported "unrecognized switch".
          return InklingsCmd
        elsif cmd.switch.present?
          # A switch was given but matched none of the branches above (a
          # staff typo, an unsupported kind, etc). Without this, an
          # unrecognized switch fell out of the if/elsif chain entirely
          # and was silently swallowed by the "no switch" fallback below
          # - e.g. "+inkling/aprove 5" quietly showed the enactor's own
          # list instead of reporting anything. Returning nil here defers
          # to Ares' own unrecognized-command handling, the same as any
          # cmd.root that isn't "inkling"/"inklings" in the first place.
          return nil
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
    # Dispatcher asks every plugin for a handler by event name. We care
    # about CronEvent (see InklingXpCronHandler) and CharConnectedEvent
    # (see CharConnectedEventHandler).
    def self.get_event_handler(event_name)
      case event_name
      when "CronEvent"
        return InklingXpCronHandler
      when "CharConnectedEvent"
        return CharConnectedEventHandler
      end
      nil
    end

    # Called by the official AresMUSH approval hook (custom_approval in
    # aresmush/plugins/chargen/custom_approval.rb) when a character is
    # approved. Converts the draft chargen-inkling data (stored on the
    # character as declared custom fields - see
    # plugin/models/character_inkling_fields.rb) into actual Inkling records,
    # then clears the draft fields so they don't linger or get re-converted
    # on a later re-approval.
    #
    # Per https://www.aresmush.com/tutorials/code/hooks/approval-triggers.html,
    # custom_approval(char) is called after char.is_approved = true is set,
    # so the character is already approved when this method runs. The
    # character itself serves as both the Inkling owner and the creator.
    #
    # Returns nothing (side effects only).
    def self.convert_chargen_drafts(char)
      return unless char
      return unless chargen_enabled?

      chargen_required_types.each do |kind|
        # Skip any configured kind that has no declared Character attribute
        # (see plugin/models/character_inkling_fields.rb) rather than raising.
        next unless char.respond_to?("inkling_#{kind}_title")

        title = char.send("inkling_#{kind}_title")
        text = char.send("inkling_#{kind}_text")

        # Only create once both halves of the draft are present - a title
        # is required (create_inkling itself rejects a blank one), so a
        # text-only draft is incomplete, not ready to convert. Left as a
        # draft rather than attempted-and-failed; AppReviewApi.app_review_lines
        # already flags this same incomplete state to staff before approval.
        next if title.to_s.blank? || text.to_s.blank?

        begin
          # character is both the owner and the creator of this Inkling
          result = InklingApi.create_inkling(char.id, char, kind, text, title)

          # Check for API errors (create_inkling returns { error: "msg" } on failure)
          if result.is_a?(Hash) && result[:error]
            AresMUSH::Coder.log_error "Error creating chargen inkling for #{char.name} (#{kind}): #{result[:error]}"
            next  # Don't clear draft if creation failed
          end

          # Clear draft fields only after successful creation
          char.update("inkling_#{kind}_title".to_sym => nil)
          char.update("inkling_#{kind}_text".to_sym => nil)
        rescue => e
          AresMUSH::Coder.log_error "Exception creating chargen inkling for #{char.name} (#{kind}): #{e.message}", e
        end
      end
    end

    # Per https://www.aresmush.com/tutorials/code/plugins.html and
    # https://www.aresmush.com/tutorials/code/web-debug.html - web
    # portal requests are dispatched by cmd name to a handler class
    # with a handle(request) method (request.cmd / request.args), the
    # same pattern as get_cmd_handler/get_event_handler above. See
    # plugin/web/*.rb for the handler classes themselves; all of them
    # are thin adapters delegating into InklingApi/RollsApi
    # (plugin/public/), which hold the actual logic.
    def self.get_web_request_handler(request)
      case request.cmd
      when "inklings_get_inklings"
        return InklingsGetInklingsWebHandler
      when "inklings_list_all"
        return InklingsListAllWebHandler
      when "inklings_get_inkling"
        return InklingsGetInklingWebHandler
      when "inklings_create_inkling"
        return InklingsCreateInklingWebHandler
      when "inklings_create_inkling_by_name"
        return InklingsCreateInklingByNameWebHandler
      when "inklings_reply_to_inkling"
        return InklingsReplyToInklingWebHandler
      when "inklings_close_inkling"
        return InklingsCloseInklingWebHandler
      when "inklings_delete_inkling"
        return InklingsDeleteInklingWebHandler
      when "inklings_share_inkling"
        return InklingsShareInklingWebHandler
      when "inklings_share_group"
        return InklingsShareGroupWebHandler
      when "inklings_request_unlock"
        return InklingsRequestUnlockWebHandler
      when "inklings_unlock_inkling"
        return InklingsUnlockInklingWebHandler
      when "inklings_submit_inkling"
        return InklingsSubmitInklingWebHandler
      when "inklings_add_roll"
        return InklingsAddRollWebHandler
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
      when "inklings_search"
        return InklingsSearchWebHandler
      end
      nil
    end

    # --- Bonus XP for a configured inkling type -------------------------
    # See the inkling_xp_type/inkling_xp_amount/inkling_xp_cron settings
    # documented in game/config/inklings.yml, and InklingXpCronHandler for
    # the CronEvent hookup (https://www.aresmush.com/tutorials/code/cron.html).

    def self.xp_award_type
      Global.read_config("inklings", "inkling_xp_type") || "update"
    end

    def self.xp_award_amount
      Global.read_config("inklings", "inkling_xp_amount") || 1
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

    # --- AresMUSH Hook: Chargen App Review ---
    # Called by the Chargen plugin during character application review.
    # Returns a formatted review status string with newlines between lines,
    # or an empty string when the feature is disabled or all checks pass.
    def self.get_app_review_issues(char)
      lines = Inklings::AppReviewApi.app_review_lines(char)
      lines.empty? ? "" : lines.join("\n")
    end
  end
end
