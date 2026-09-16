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
        if not check then
          -- Failing clears the trick, so the next hand leads freely. Without
          -- that a bad play would leave the same unbeatable lock in place.
          Trick.clear_lock()
          alert(why or "does not beat it")
        end
        return true
      end

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

-- A discard with nothing selected is the pass: it clears the trick. Discarding
-- cards does not, or discarding would be strictly better than passing and the
-- pass would have no reason to exist.
local discard_ref = G.FUNCS.discard_cards_from_highlighted
G.FUNCS.discard_cards_from_highlighted = function(e, hook)
  local passing = Trick.active()
    and G.GAME.modifiers.cm_pass
    and G.hand
    and #G.hand.highlighted == 0

  local ret = discard_ref and discard_ref(e, hook)

  if passing then
    -- The game's discard body is wrapped in `if highlighted_count > 0`, so
    -- with nothing selected it never reaches ease_discard(-1) and the pass
    -- would be free. Charge it here, and move the round on: the same guard
    -- skips the DRAW_TO_HAND transition too.
    if ease_discard then ease_discard(-1) end
    if G.GAME.current_round then
      G.GAME.current_round.discards_used = (G.GAME.current_round.discards_used or 0) + 1
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

  -- UNVERIFIED: this assumes the played cards have already left G.hand by the
  -- time mult is computed, so #G.hand.cards is the remainder. That ordering
  -- could not be confirmed from the game source and needs checking on device;
  -- if it is wrong the bonus either never fires or fires on every hand.
  if G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_shed_bonus
    and G.hand and G.play
    and #G.hand.cards == 0 and #G.play.cards > 0
  then
    local handname = G.GAME.last_hand_played
    local x = handname and ChallengeMod.Trick.shed_xmult(handname)
    if x then
      _mult = _mult * x
      alert(("shed x%s"):format(tostring(x)))
    end
  end

  return _mult
end
