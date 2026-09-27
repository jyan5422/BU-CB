-- cm_waste_tax: cards you throw away cost money.
--
-- The problem it solves: with no redraw, emptying your hand is progress, and
-- the shed bonus asks only whether the hand is empty -- never how it got that
-- way. So the two cheapest routes to empty were the two most wasteful ones.
-- Dumping five junk cards as a High Card cost one hand and nothing else, and a
-- discard was a free permanent hand-size reduction. Both were rewarded and
-- neither was priced.
--
-- A wasted card is one that leaves your hand without contributing: played but
-- not part of the scoring hand, or discarded. Every two of them costs a dollar,
-- rounded down -- so a single stray card is forgiven and real Big 2
-- combinations, which score every card, are never taxed at all.
--
-- Deliberately money rather than hands or score: it bites hardest early, when
-- a run is fragile and the junk opener is most tempting, and it never makes a
-- round unwinnable the way another lost hand could.
ChallengeMod.Waste = ChallengeMod.Waste or {}
local Waste = ChallengeMod.Waste

local DEFAULT_CARDS_PER_DOLLAR = 2

function Waste.active()
  return G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_waste_tax and true or false
end

--- How many wasted cards one dollar covers. The modifier's value, so a
--- challenge can make waste cheaper or dearer without new code.
function Waste.cards_per_dollar()
  local v = G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_waste_tax
  local n = tonumber(v)
  if not n or n < 1 then return DEFAULT_CARDS_PER_DOLLAR end
  return n
end

--- Dollars owed for `count` wasted cards. Rounded DOWN, which is what makes a
--- two-card High Card free: one stray card is not worth a fine.
function Waste.charge_for(count)
  if not count or count <= 0 then return 0 end
  return math.floor(count / Waste.cards_per_dollar())
end

--- Wasted cards in a played hand: those not in the scoring hand.
---
--- Debuffed cards are never counted. They cannot score whatever the player
--- does, so taxing them would charge for a boss's effect rather than for a
--- choice. In practice a debuffed card usually sits INSIDE the scoring hand --
--- the hand still evaluates, the card just yields no chips -- so this mostly
--- matters for a debuffed kicker.
function Waste.count_played(played, scoring)
  if not played then return 0 end

  local is_scoring = {}
  for _, card in ipairs(scoring or {}) do is_scoring[card] = true end

  local wasted = 0
  for _, card in ipairs(played) do
    if not is_scoring[card] and not (card and card.debuff) then
      wasted = wasted + 1
    end
  end
  return wasted
end

--- Wasted cards in a discard: all of them, since none contributed.
---
--- Debuffed cards are exempt here too, and that is the right incentive: dead
--- cards are exactly what a player should be clearing out, and charging for it
--- would punish the only sensible response to the blind.
function Waste.count_discarded(cards)
  if not cards then return 0 end
  local wasted = 0
  for _, card in ipairs(cards) do
    if not (card and card.debuff) then wasted = wasted + 1 end
  end
  return wasted
end

--- Charge for a played hand. Called from lovely/cm_waste_tax.toml, which has
--- the scoring hand in scope.
function Waste.tax_play(played, scoring)
  if not Waste.active() then return 0 end
  local owed = Waste.charge_for(Waste.count_played(played, scoring))
  Waste.charge(owed)
  return owed
end

--- Charge for a discard.
function Waste.tax_discard(cards)
  if not Waste.active() then return 0 end
  local owed = Waste.charge_for(Waste.count_discarded(cards))
  Waste.charge(owed)
  return owed
end

--- Take the money and say so. ease_dollars animates the counter and handles
--- going negative -- bankrupt_at only gates purchases, so a charge can put a
--- player in the red without ending the run.
function Waste.charge(owed)
  if not owed or owed <= 0 then return end
  if ease_dollars then ease_dollars(-owed) end
  if ChallengeMod.Climb and ChallengeMod.Climb.alert_money then
    ChallengeMod.Climb.alert_money(owed)
  end
end

--- What the current selection would cost, for the preview. Display only.
function Waste.preview(area, handname, poker_hands)
  if not Waste.active() then return 0 end
  if not (area and area.highlighted) then return 0 end
  local scoring = poker_hands and handname and poker_hands[handname]
    and poker_hands[handname][1]
  return Waste.charge_for(Waste.count_played(area.highlighted, scoring))
end
