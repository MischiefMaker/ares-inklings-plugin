module AresMUSH
  module Inklings
    class RollsApi
      # Add a roll to an inkling
      # roll_type: "player" (roll for own character), "npc" (roll for NPC), "static" (just a number)
      # roll_spec: skill/attribute name for player/npc, description for static
      # result: the result string (e.g. "8", "Good (7)")
      # result_value: numeric value for sorting
      # npc_char_id: optional character ID for the NPC target (npc rolls only)
      # is_private: whether only player and staff can see this
      def self.add_roll(inkling_id, viewer_id, roll_type, roll_spec, result, result_value, npc_char_id: nil, is_private: false)
        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        unless Inklings.can_manage_inklings?(viewer) || Inklings.is_participant?(inkling, viewer)
          return { error: "Not authorized" }
        end

        unless Inklings.can_manage_inklings?(viewer) || viewer.is_approved?
          return { error: "Your character must be approved to add rolls." }
        end

        case roll_type
        when "player"
          target = viewer

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
      def self.reroll_with_luck(inkling_id, roll_id, viewer_id, new_result, new_result_value, luck_cost)
        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

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
          inkling.update(player_unread: "true") if inkling.character.id != viewer.id
          Inklings.notify_player(inkling.character, "<inklings> A roll was rerolled in inkling ##{inkling.id}")
        end

        {
          roll: format_roll(roll)
        }
      end

      # Get all rolls for an inkling (respecting visibility)
      def self.get_rolls(inkling_id, viewer_id)
        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        unless Inklings.can_manage_inklings?(viewer) || Inklings.is_participant?(inkling, viewer)
          return { error: "Not authorized" }
        end

        rolls = InklingRoll.find(inkling_id: inkling.id).to_a.sort_by { |r| Inklings.time_value(r.created_at) }
        visible_rolls = rolls.select { |r| Inklings.can_see_roll?(r, viewer) }

        {
          rolls: visible_rolls.map { |r| format_roll(r) }
        }
      end

      private

      def self.format_roll(roll)
        target_name = roll.target_character ? roll.target_character.name : nil
        creator_name = roll.creator ? roll.creator.name : "Unknown"

        {
          id: roll.id,
          ref: Inklings.event_ref(roll.inkling, roll.seq),
          roll_type: roll.roll_type,
          roll_spec: roll.roll_spec,
          result: roll.result,
          result_value: roll.result_value,
          character: roll.character ? roll.character.name : nil,
          character_id: roll.character ? roll.character.id : nil,
          target_character: target_name,
          target_character_id: roll.target_character ? roll.target_character.id : nil,
          creator: creator_name,
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
