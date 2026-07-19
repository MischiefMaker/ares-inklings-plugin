module AresMUSH
  module Inklings
    class RollsApi
      # Add a roll to an inkling
      # roll_type: "player" (roll for own character), "npc" (roll for NPC), "static" (just a number)
      # roll_spec: skill/attribute name for player/npc, description for static
      # result: the result string (e.g. "8", "Good (7)"). For player rolls, the frontend
      #   calls character_luck_reroll to get the actual FS3 result, then passes it here.
      # result_value: numeric value for sorting
      # npc_char_id: optional character ID for the NPC target, if it's tied to an actual Character record (npc rolls only)
      # npc_name: optional free-text NPC name for display, for NPCs with no Character record (npc rolls only)
      # is_private: whether only player and staff can see this
      #
      # Note: The frontend calls the character_luck_reroll web handler to perform FS3
      # rolls for player characters (since that's the available AresMUSH API that
      # returns an FS3 roll result). This aligns with the AresMUSH pattern where rolling
      # APIs handle the skill roll calculation and return the result, which is then
      # stored by application-specific code (like this plugin).
      #
      # viewer is the already-authenticated Character object (request.enactor
      # from the web handler), not a raw ID - matches the convention used
      # throughout InklingApi (see e.g. create_inkling/close_inkling).
      def self.add_roll(inkling_id, viewer, roll_type, roll_spec, result, result_value, npc_char_id: nil, npc_name: nil, is_private: false)
        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        unless Inklings.can_manage_inklings?(viewer) || Inklings.is_participant?(inkling, viewer)
          return { error: "Not authorized" }
        end

        unless Inklings.can_manage_inklings?(viewer) || viewer.is_approved?
          return { error: "Your character must be approved to add rolls." }
        end

        if inkling.locked == "true" && !Inklings.can_manage_inklings?(viewer)
          return { error: "This inkling has been submitted and is locked until staff respond." }
        end

        case roll_type
        when "player"
          target = viewer
          # Use FS3 system to perform the actual roll for the given skill
          roll_params = AresMUSH::FS3Skills::RollParams.new(roll_spec)
          roll_outcome = AresMUSH::FS3Skills.one_shot_roll(viewer, roll_params)
          if roll_outcome
            result = "#{roll_outcome[:success_title]} (#{roll_outcome[:successes]})"
            result_value = roll_outcome[:successes]
          else
            return { error: "Failed to perform FS3 roll for #{roll_spec}" }
          end

        when "npc", "static"
          unless Inklings.can_manage_inklings?(viewer)
            return { error: "Only staff can add NPC or static rolls" }
          end
          target = (roll_type == "npc" && npc_char_id) ? Character[npc_char_id] : nil

        else
          return { error: "Invalid roll type" }
        end

        # Create the roll
        roll = InklingRoll.create(
          inkling: inkling,
          character: (roll_type == "player") ? viewer : nil,
          target_character: target,
          npc_name: (roll_type == "npc" && !target) ? npc_name.to_s.strip.presence : nil,
          creator: viewer,
          roll_type: roll_type,
          roll_spec: roll_spec,
          result: result,
          result_value: result_value.to_i,
          seq: Inklings.next_event_seq(inkling),
          private: is_private ? "true" : "false",
          reroll_count: "0",
          luck_cost: "0",
          created_at: Time.now,
          rolled_at: Time.now
        )

        {
          roll: format_roll(roll)
        }
      end

      # Reroll using luck points
      # viewer is the already-authenticated Character object, not a raw ID -
      # see the note on add_roll above.
      def self.reroll_with_luck(inkling_id, roll_id, viewer, new_result, new_result_value, luck_cost)
        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        roll = InklingRoll[roll_id]
        return { error: "Roll not found" } if !roll

        # Only the player who made the roll or staff can reroll with luck
        unless Inklings.can_manage_inklings?(viewer) || (roll.character && viewer.id == roll.character.id)
          return { error: "You cannot reroll this" }
        end

        # Check if player has enough luck (only when a player is spending their own)
        char = roll.character
        if char && viewer.id == char.id
          current_luck = char.respond_to?(:luck) ? char.luck : 0
          unless current_luck >= luck_cost
            return { error: "Not enough luck points. You have #{current_luck}, need #{luck_cost}" }
          end
          # Deduct the luck
          char.update(luck: current_luck - luck_cost)
        end

        # Update the roll
        reroll_count = roll.reroll_count.to_i
        roll.update(
          result: new_result,
          result_value: new_result_value.to_i,
          reroll_count: reroll_count + 1,
          luck_cost: luck_cost,
          rolled_at: Time.now
        )

        # Notify others in the thread if it wasn't private
        if roll.private.to_s != "true"
          Inklings.update_inkling(inkling, player_unread: "true") if inkling.character.id != viewer.id
          Inklings.notify_player(inkling.character, "<inklings> A roll was rerolled in inkling ##{inkling.id}")
        end

        {
          roll: format_roll(roll)
        }
      end

      private

      def self.format_roll(roll)
        Inklings.format_roll_json(roll)
      end
    end
  end
end
