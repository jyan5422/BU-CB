-- Wires cm_trick_lock, cm_pass, cm_trick_refund and cm_shed_bonus into the
-- game. The comparison itself lives in smods/rules_trick.lua.
local Trick = ChallengeMod.Trick

local function alert(text)
  if not (G.E_MANAGER and attention_text) then return end
  G.E_MANAGER:add_event(Event({
    trigger = "immediate",
    func = function()
      attention_text({
        text = text,
        scale = 0.7,
        hold = 2,
        major = G.play or G.hand,
        backdrop_colour = G.C.RED,
        align = "cm",
        offset = { x = 0, y = -2.5 },
        silent = true,
      })
      return true
    end,
  }))
end

-- Enforcement rides Blind:debuff_hand. Returning true debuffs the played hand,
-- which is exactly "the hand is thrown away": it scores nothing and still
-- costs the hand, the same as playing an illegal hand into a boss that gates
-- hand size.
--
-- The `check` pass is the pre-play query the UI makes, so a hand that cannot
-- win is greyed out rather than played into a wall. Nothing is mutated during
-- check -- only the real call updates the lock.
local debuff_hand_ref = Blind.debuff_hand
function Blind:debuff_hand(cards, hand, handname, check)
  if Trick.active() then
    local played = check and G.hand and G.hand.highlighted or cards
    local count = #(played or {})

    if count > 0 then
      local lock = Trick.get_lock()
      local beats, why = Trick.beats(lock, count, handname, played)

      if not beats then
        if check then
          -- The check pass drives the "will not score" label, which says only
          -- that -- not why. Stash the reason so the label can carry it, since
          -- the Big 2 order is the surprising part (a 2 outranks a 5).
          ChallengeMod.Trick.last_reason = why
        else
          -- Failing clears the trick, so the next hand leads freely. Without
          -- that a bad play would leave the same unbeatable lock in place.
          Trick.clear_lock()
          alert(why or "does not beat it")
        end
        return true
      end

      if check then ChallengeMod.Trick.last_reason = nil end

      if not check then
        local continued = lock ~= nil
        Trick.set_lock(count, handname, played)
        -- Holding the trick means you never had to pass, so the pass comes
        -- back. Discards buy passes and joker triggers, never score, so this
        -- cannot be turned into points the way a refunded hand could.
        if continued
          and G.GAME.modifiers.cm_trick_refund
          and ease_discard
        then
          ease_discard(1)
        end
      end
    end
  end

  return debuff_hand_ref(self, cards, hand, handname, check)
end

-- Any discard is a pass: it clears the trick, whether or not cards were
-- selected. Giving up the trick is the cost of discarding at all, which keeps
-- the two decisions -- improve my hand, or keep the trick -- in tension
-- without making a zero-card discard a separate special case.
local discard_ref = G.FUNCS.discard_cards_from_highlighted
G.FUNCS.discard_cards_from_highlighted = function(e, hook)
  local passing = Trick.active()
    and G.GAME.modifiers.cm_pass
    and G.hand

  local zero_card = passing and #G.hand.highlighted == 0
  local ret = discard_ref and discard_ref(e, hook)

  if passing then
    -- With cards selected the game charges the discard itself. With none, its
    -- whole body is skipped by `if highlighted_count > 0`, so the charge has
    -- to happen here or a zero-card pass would be free.
    if zero_card and ease_discard then
      ease_discard(-1)
      if G.GAME.current_round then
        G.GAME.current_round.discards_used = (G.GAME.current_round.discards_used or 0) + 1
      end
    end
    Trick.clear_lock()
    alert("pass")
  end
  return ret
end

-- cm_shed_bonus: playing your last card pays an Xmult graded on the hand you
-- go out with, and ends the round.
--
-- Ending it matters: can_play is gated on #G.hand.highlighted <= 0, so with an
-- empty hand you cannot play at all, only burn discards on passes nothing can
-- follow. The position is already decided, so resolving it is honest rather
-- than making the player click through a loss.
--
-- Deliberately NOT implemented by zeroing card_limit: the game-over check at
-- functions/state_events.lua:330 fires when card_limit <= 0 AND the hand is
-- empty, so that would turn the reward into an instant loss. An empty hand
-- with the limit left alone is safe -- it simply draws nothing.
local mod_mult_ref = mod_mult
function mod_mult(_mult)
  _mult = mod_mult_ref(_mult)

  -- mod_mult is called several times while scoring one hand -- for the base
  -- mult, again after jokers, and once more at the final step -- so the bonus
  -- has to be applied once per hand rather than per call, or it compounds.
  -- G.GAME.current_round.hands_played identifies the hand.
  if G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_shed_bonus
    and G.hand and G.play
    and #G.hand.cards == 0 and #G.play.cards > 0
  then
    local round = G.GAME.current_round
    local this_hand = round and round.hands_played
    if ChallengeMod.Trick.shed_applied ~= this_hand then
      local handname = G.GAME.last_hand_played
      local x = handname and ChallengeMod.Trick.shed_xmult(handname)
      if x then
        ChallengeMod.Trick.shed_applied = this_hand
        _mult = _mult * x
        alert(("shed X%s"):format(tostring(x)))
      end
    end
  end

  return _mult
end
