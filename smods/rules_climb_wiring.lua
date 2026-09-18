-- Wires cm_climb, cm_pass, cm_climb_refund and cm_shed_bonus into the
-- game. The comparison itself lives in smods/rules_climb.lua.
local Climb = ChallengeMod.Climb

-- One alert at a time. Selection-change alerts fire faster than an
-- attention_text holds, so several used to sit on top of each other at the
-- same offset and become unreadable. This keeps a short hold and refuses to
-- queue another while one is still up.
local alert_until = 0

local function alert(text, opts)
  if not (G.E_MANAGER and attention_text and love and love.timer) then return end
  opts = opts or {}

  local now = love.timer.getTime()
  local hold = opts.hold or 0.9
  -- force jumps the queue for committed actions (a failed play, a pass, the
  -- shed payout) but still extends the window, so two forced alerts in quick
  -- succession do not stack.
  if not opts.force and now < alert_until then return end
  alert_until = math.max(alert_until, now) + hold

  G.E_MANAGER:add_event(Event({
    trigger = "immediate",
    func = function()
      attention_text({
        text = text,
        scale = 0.6,
        hold = hold,
        -- Centred on the room rather than anchored to a card area: attaching
        -- to G.play put it over the score, and G.hand put it over the cards.
        -- G.ROOM_ATTACH is what the game centres its own dialogue on. It is
        -- nil outside a run, hence the fallback.
        major = G.ROOM_ATTACH or G.play or G.hand,
        backdrop_colour = opts.colour or G.C.RED,
        align = "cm",
        offset = { x = 0, y = opts.y or 0 },
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
  if Climb.active() then
    local played = check and G.hand and G.hand.highlighted or cards
    local count = #(played or {})

    if count > 0 then
      local lock = Climb.get_lock()
      local beats, why = Climb.beats(lock, count, handname, played)

      if not beats then
        if check then
          -- The check pass drives the game's "will not score" label, which says
          -- only that, not why. Surfacing the reason there would mean patching
          -- that label's construction, which I could not locate; instead the
          -- reason is shown as an alert the moment the selection becomes
          -- illegal, so it appears before the hand is committed.
          if ChallengeMod.Climb.last_reason ~= why then
            ChallengeMod.Climb.last_reason = why
            alert(why)
          end
        else
          -- Failing clears the trick, so the next hand leads freely. Without
          -- that a bad play would leave the same unbeatable lock in place.
          Climb.clear_lock()
          alert(why or "does not beat it", { hold = 1.6, force = true })
        end
        return true
      end

      if check then ChallengeMod.Climb.last_reason = nil end

      if not check then
        local continued = lock ~= nil
        Climb.set_lock(count, handname, played)
        -- Holding the trick means you never had to pass, so the pass comes
        -- back. Discards buy passes and joker triggers, never score, so this
        -- cannot be turned into points the way a refunded hand could.
        if continued
          and G.GAME.modifiers.cm_climb_refund
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
  local passing = Climb.active()
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
    Climb.clear_lock()
    alert("pass", { colour = G.C.BLUE, hold = 1.2, force = true })
  end
  return ret
end

-- cm_shed_bonus: emptying your hand pays an Xmult graded on the hand you go
-- out with.
--
-- Applied at the final scoring step so it multiplies the finished total. It
-- used to ride mod_mult, but that runs several times per hand -- base mult,
-- post-joker, then the final step -- and the once-per-hand guard caught the
-- first, so the bonus scaled the BASE mult and every joker after it compounded
-- on top. Hooking the final_scoring_step context instead lands it exactly once,
-- after all cards and jokers have scored.
--
-- Ending the round matters too: can_play is gated on
-- #G.hand.highlighted <= 0, so with an empty hand the player cannot play at
-- all, only burn discards on passes nothing can follow. Resolving is honest
-- about a position already decided.
--
-- Deliberately NOT implemented by zeroing card_limit: the game-over check at
-- functions/state_events.lua:330 fires when card_limit <= 0 AND the hand is
-- empty, so that would turn the reward into an instant loss. An empty hand
-- with the limit left alone is safe -- it simply draws nothing.
-- The multiplication itself is a Lovely patch at the final scoring step
-- (lovely/cm_shed_bonus.toml) because `mult` is a local inside evaluate_play
-- and cannot be reached from a Lua hook. This exposes the decision so the
-- patch stays a one-liner.
-- Set false once the shed bonus is confirmed working. The empty-hand test can
-- only be checked during a real hand, so this reports what it saw.
ChallengeMod.Climb.SHED_DEBUG = true

function ChallengeMod.Climb.shed_multiplier()
  if ChallengeMod.Climb.SHED_DEBUG and sendInfoMessage then
    sendInfoMessage(("SHED: hand=%s play=%s last=%s"):format(
      tostring(G.hand and #G.hand.cards), tostring(G.play and #G.play.cards),
      tostring(G.GAME and G.GAME.last_hand_played)), "ChallengeMod")
  end
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_shed_bonus) then return 1 end
  if not (G.hand and #G.hand.cards == 0) then return 1 end

  -- Deliberately NOT guarded per hand. The scoring pass runs more than once
  -- for the same played hand -- the trace showed it banking 576 with the bonus
  -- and then 192 without -- and the later value wins. Refusing to re-apply
  -- meant the un-multiplied score was the one kept. The multiplication is
  -- idempotent per pass because it scales whatever mult that pass built.

  local x = G.GAME.last_hand_played and ChallengeMod.Climb.shed_xmult(G.GAME.last_hand_played)
  if not x then return 1 end

  return x
end

--- Should the flash be shown for this hand? The multiplier applies on every
-- scoring pass, but the announcement should appear only once.
function ChallengeMod.Climb.shed_announce()
  local round = G.GAME and G.GAME.current_round
  local this_hand = round and round.hands_played
  if ChallengeMod.Climb.shed_announced == this_hand then return false end
  ChallengeMod.Climb.shed_announced = this_hand
  return true
end
