-- cm_frugal_bonus: a hand where every card scores pays out.
--
-- The counterweight to cm_waste_tax. The tax alone made frugality merely the
-- absence of a fine, which is not a reward -- so the wasteful player was
-- punished and the careful one got nothing back.
--
-- Strict: ONE unscored card forfeits the whole payment. Paying per scoring
-- card regardless would reward playing rather than playing clean, which is the
-- distinction the rule exists to draw.
--
-- The two rules are separate modifiers on purpose. A joker wanting the gambit
-- takes both; a gentler challenge can take only this half. A merged rule could
-- not be pulled apart again.
ChallengeMod.Frugal = ChallengeMod.Frugal or {}
local Frugal = ChallengeMod.Frugal

local DEFAULT_CARDS_PER_DOLLAR = 2

function Frugal.active()
  return G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_frugal_bonus and true or false
end

--- Its own rate, not the tax's: a joker can pay generously inside a challenge
--- that taxes harshly.
function Frugal.cards_per_dollar()
  local v = G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_frugal_bonus
  local n = tonumber(v)
  if not n or n < 1 then return DEFAULT_CARDS_PER_DOLLAR end
  return n
end

function Frugal.pay_for(count)
  if not count or count <= 0 then return 0 end
  return math.floor(count / Frugal.cards_per_dollar())
end

--- Dollars earned by a played hand, 0 unless every card scored.
---
--- Unscored cards are counted by ChallengeMod.Waste, which already exempts
--- debuffed ones -- so a boss's debuff cannot disqualify the payment any more
--- than it can trigger the fine. A debuffed card INSIDE the scoring hand still
--- counts toward the payment: it is part of the combination, and the player
--- chose the combination.
function Frugal.reward(played, scoring)
  if not (played and scoring) then return 0 end
  if not ChallengeMod.Waste then return 0 end
  if ChallengeMod.Waste.count_played(played, scoring) > 0 then return 0 end
  return Frugal.pay_for(#scoring)
end

function Frugal.pay_play(played, scoring)
  if not Frugal.active() then return 0 end
  local earned = Frugal.reward(played, scoring)
  if earned > 0 and ease_dollars then ease_dollars(earned) end
  return earned
end

--- What the current selection would earn, for the preview. Display only.
function Frugal.preview(area, handname, poker_hands)
  if not Frugal.active() then return 0 end
  if not (area and area.highlighted) then return 0 end
  local scoring = poker_hands and handname and poker_hands[handname]
    and poker_hands[handname][1]
  if not scoring then return 0 end
  return Frugal.reward(area.highlighted, scoring)
end
