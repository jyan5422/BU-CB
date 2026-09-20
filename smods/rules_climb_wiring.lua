-- Wires cm_climb, cm_pass, cm_climb_refund and cm_shed_bonus into the
-- game. The comparison itself lives in smods/rules_climb.lua.
local Climb = ChallengeMod.Climb

-- One alert at a time. Selection-change alerts fire faster than an
-- attention_text holds, so several used to sit on top of each other at the
-- same offset and become unreadable. This keeps a short hold and refuses to
-- queue another while one is still up.
local alert_until = 0

-- Last shed multiplier announced on selection. Declared up here because
-- debuff_hand resets it when a hand is committed, and a Lua local is not
-- visible above its declaration.
local shed_flashed = 1

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

  local place = Climb.alert_placement(opts)
  local under_play = opts.under_play
  local delay = opts.delay or 0

  G.E_MANAGER:add_event(Event({
    trigger = delay > 0 and "after" or "immediate",
    delay = delay,
    func = function()
      attention_text({
        text = text,
        scale = 0.6,
        hold = hold,
        -- G.ROOM_ATTACH is what the game centres its own dialogue on. It is
        -- nil outside a run, hence the fallback.
        major = under_play and (G.play or G.ROOM_ATTACH)
          or (G.ROOM_ATTACH or G.play or G.hand),
        backdrop_colour = opts.colour or G.C.RED,
        align = place.align,
        offset = { x = 0, y = place.y },
        -- attention_text's own sound is a UI blip. Silenced so a caller can
        -- ask for the sound that matches what the message means instead.
        silent = true,
      })
      -- Pitch and volume copied from card_eval_status_text's x_mult branch, so
      -- an Xmult announced by this reads as the same event as one announced by
      -- a joker rather than a near-miss of it.
      if opts.sound and play_sound then
        play_sound(opts.sound, opts.pitch or 1, opts.volume)
      end
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

    -- Deselecting everything tears the warning down, so the reason behind it
    -- must go too or it would reappear attached to the next illegal hand
    -- before that hand's own reason is computed.
    if count == 0 and check then ChallengeMod.Climb.last_reason = nil end

    if count > 0 then
      local lock = Climb.get_lock()
      local beats, why = Climb.beats(lock, count, handname, played)

      if not beats then
        if check then
          -- The check pass is what sets G.boss_throw_hand, so the game's
          -- "Hand will not score" warning is already on screen. Its second row
          -- renders Blind:get_loc_debuff_text, which is '' on a non-boss
          -- blind -- an empty slot the reason fits exactly. Hooking that
          -- (below) beats a transient flash: it stays up as long as the
          -- illegal selection does.
          ChallengeMod.Climb.last_reason = why
        else
          -- Failing clears the trick, so the next hand leads freely. Without
          -- that a bad play would leave the same unbeatable lock in place.
          Climb.clear_lock()
          -- Not the reason again: the warning row has been showing that for as
          -- long as the selection stood, and the game follows this with its own
          -- "Not Allowed!". What the player does not yet know is that the climb
          -- is now open.
          --
          -- Placed below the played cards, where "Not Allowed!" is above them.
          -- A delay was tried first and did not work: the game queues its
          -- message as a `before` event and this as an `after`, so the two
          -- landed together and overprinted each other.
          alert("Climb reset", {
            colour = G.C.BLUE, hold = 1.2, force = true,
            under_play = true, delay = 0.6,
          })
        end
        return true
      end

      if check then ChallengeMod.Climb.last_reason = nil end

      if not check then
        local continued = lock ~= nil
        ChallengeMod.Climb.last_reason = nil
        shed_flashed = 1
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

-- Keeps the climb reason's own row (lovely/cm_climb_warning_row.toml) in step
-- with the selection. Mirrors SMODS's update_blind_debuff_text: a DynaText
-- caches its string, so without a refresh func the row would keep whichever
-- reason was current when the warning box was built.
G.FUNCS.cm_update_climb_reason = function(e)
  if not e.config.object then return end
  local new_str = Climb.selection_subtext() or ""
  if new_str ~= e.config.object.string then
    e.config.object.config.string = { new_str }
    e.config.object:update_text(true)
    e.UIBox:recalculate()
  end
end

--- The shed payout flash, fired from lovely/cm_shed_bonus.toml once the bonus
--- has been applied.
---
--- Horizontally centred and static, below the played cards. It used to go
--- through card_eval_status_text anchored to the LAST played card, the way a
--- joker announces itself -- which pinned it to a card, so it sat off to one
--- side and slid around with the scoring animation. This is a payout for the
--- hand as a whole, not for one card.
function ChallengeMod.Climb.shed_flash(x)
  if not ChallengeMod.Climb.shed_announce() then return end
  alert(Climb.shed_label(x), {
    colour = G.C.MULT, hold = 1.2, force = true, under_play = true,
    -- The shed payout IS an Xmult, so it gets the game's Xmult sound.
    sound = "multhit2", pitch = 0.96, volume = 0.7,
  })
end

-- Shed bonus on selection. The preview mult already includes it
-- (lovely/cm_shed_preview.toml), but a number quietly doubling is easy to
-- miss, so name it once when the selection starts qualifying.
--
-- Keyed on the value rather than rate limited: selecting the last card is a
-- deliberate act and deserves the flash every time it happens, while the
-- preview refreshes far too often to announce on each call.
function ChallengeMod.Climb.shed_preview_flash(x)
  x = x or 1
  if x == shed_flashed then return end
  shed_flashed = x
  if x > 1 then
    alert(Climb.shed_label(x), {
      colour = G.C.MULT, hold = 1.1, force = true,
      sound = "multhit2", pitch = 0.96, volume = 0.7,
    })
  end
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
function ChallengeMod.Climb.shed_multiplier()
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

--- Should the flash be shown now? The multiplier applies on every scoring
-- pass, but the announcement should appear once per played hand.
--
-- Keyed on the cards in play rather than hands_played: the passes for one hand
-- do not share a hands_played value, so keying on that let the first pass
-- consume the announcement and blocked the one that would have drawn -- the
-- trace reported "skipped: guard failed" with every dependency present.
--
-- Rate limited by time instead, which cannot be fooled by however many passes
-- the scoring makes.
function ChallengeMod.Climb.shed_announce()
  if not (love and love.timer) then return true end
  local now = love.timer.getTime()
  local last = ChallengeMod.Climb.shed_announced_at or -1
  if now - last < 1.5 then return false end
  ChallengeMod.Climb.shed_announced_at = now
  return true
end
