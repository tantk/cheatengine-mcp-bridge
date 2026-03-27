# 龙胤立志传 (LongYinLiZhiZhuan) — Comprehensive Player Guide

*Data-mined from game files, IL2CPP dump, quest snapshots, and character database.*
*Game version: March 2026 Steam release.*

> **Disclaimer:** This guide is reverse-engineered from game data files and IL2CPP memory structures.
> Some mechanics interpretations may be incorrect — the actual formulas are in compiled code.
> Treat recommendations as informed guesses, not gospel.

---

## Table of Contents
1. [Game Overview](#game-overview)
2. [How the Game Actually Works — Core Mechanics](#core-mechanics)
3. [Starting the Game — Story Mode vs Free Mode](#starting-the-game)
4. [Faction Guide (门派)](#faction-guide)
5. [Character & Recruitment Guide](#character-guide)
6. [Martial Arts System & Skill Recommendations](#martial-arts)
7. [Internal Arts (内功) — The Foundation](#internal-arts)
8. [Combat Skills — Best Picks by Weapon Type](#combat-skills)
9. [Talent System (天赋)](#talent-system)
10. [Item System](#item-system)
11. [Quest & Event Guide](#quest-guide)
12. [Map & Locations](#map-locations)
13. [Economy & Trading](#economy)
14. [Tips & Tricks](#tips)

---

## 1. Game Overview <a name="game-overview"></a>

龙胤立志传 is an open-world wuxia RPG set in ancient China. You play as a young martial artist navigating the jianghu (martial world) — joining factions, learning kung fu, recruiting companions, conquering territories, and unraveling a plot involving fugitives, sect wars, and legendary treasures.

**Core Systems:**
- **9 martial art categories** with 147+ internal arts and 100+ combat skills
- **30 factions** ranging from major sects (少林, 武当) to minor gangs
- **170+ named characters** with unique personalities, relationships, and signature moves
- **Life skills**: Medicine (医术), Poison (毒术), Scholarship (学识), Eloquence (口才), Harvesting (采伐), Planting (木植), Forging (锻造), Alchemy (炼药), Cooking (烹饪)
- **Territory conquest**: Cities and towns can be captured by factions
- **Dynamic events**: Tournaments, ambushes, treasure hunts, rare encounters

---

## 2. How the Game Actually Works — Core Mechanics <a name="core-mechanics"></a>

Understanding these systems is critical. Getting them wrong will lead to bad build decisions.

### The Stat System (属性)

Every hero has **three layers** for each stat:

| Layer | Field | What It Is |
|-------|-------|-----------|
| **baseAttri** | Current trained value | What you've earned through practice |
| **maxAttri** | Potential ceiling | The MAXIMUM baseAttri can reach |
| **totalAttri** | Effective value | baseAttri + equipment + buffs + all bonuses |

**The 6 Core Attributes** (indices 0-5):
| Index | Name | Chinese | Role |
|-------|------|---------|------|
| 0 | Strength | 力道 | Physical damage, carry weight |
| 1 | Agility | 灵巧 | Evasion, speed, finesse attacks |
| 2 | Intelligence | 智力 | Qi/mana-based abilities, learning |
| 3 | Willpower | 意志 | Mental resistance, persistence |
| 4 | Constitution | 体质 | HP, endurance, defense |
| 5 | Meridians | 经脉 | Internal energy flow, qi capacity |

**The 9 Combat Skills** (indices 0-8):
| Index | Type | Chinese | Weapon |
|-------|------|---------|--------|
| 0 | Internal | 内功 | Passive cultivation |
| 1 | Dodge | 轻功 | Evasion/movement |
| 2 | Unique | 绝技 | Special techniques |
| 3 | Fist | 拳掌 | Unarmed/palm |
| 4 | Sword | 剑法 | Sword |
| 5 | Knife | 刀法 | Blade/saber |
| 6 | Long | 长兵 | Polearm/staff |
| 7 | Strange | 奇门 | Exotic weapons |
| 8 | Shoot | 射术 | Ranged/projectile |

Each combat skill also has base/max/total layers, plus its own `fightExp` and `bookExp` progress.

### Potential (潜力) vs Direct Stats — THE Most Important Distinction

When a skill's training effect says:
- **"力道1"** → Directly adds +1 to your current 力道 (baseAttri[0]). **Immediate power gain.**
- **"力道潜力1"** → Adds +1 to your 力道 **ceiling** (maxAttri[0]). **No immediate power — just raises the cap so you can train higher.**

**Why this matters:** A skill that gives "力道潜力2" is a **long-term investment**. It lets you eventually reach higher stats through continued training, but gives you nothing right now. A skill giving "力道2" gives immediate combat power but doesn't raise your ceiling.

**Optimal strategy:** Prioritize 潜力 (potential) skills EARLY in the game when you have time to train. Switch to direct-stat skills when you need immediate power for urgent battles.

### Experience Coefficient (经验系数) — Higher = HARDER

The 经验系数 column in the skill database is a **cost multiplier**, NOT a speed boost:
- **经验系数 0.8** = Needs only 80% of normal experience → **easy to train**
- **经验系数 1.0** = Standard training difficulty
- **经验系数 1.3** = Needs 130% of normal experience → **slow to train**
- **经验系数 3.0** = Needs 300% of normal experience → **extremely slow**

This is why 龙胤归藏功 (the ultimate internal art) has 经验系数 3.0 — it's the best skill but takes 3x longer to level up. 霸刀一式 (highest blade power) has 经验系数 0.8 — relatively easy to train despite being powerful.

**When picking skills, consider the efficiency ratio:** raw power OR stat growth per unit of training time.

### Combat Formulas (Simplified)

From the game code structures, combat uses:
- **Damage** = f(attacker's totalAttri, skill basePower, skill powerCoeff, skill level, weapon bonuses)
- **Defense** = f(defender's armor, armorRate, reduceReciveDamageRate, partPosture)
- **Hit/Miss** = f(attacker's acc vs defender's evade)
- **Critical** = f(critRate vs antiCrit)
- **Counter** = f(counter vs antiCounter)
- **Combo** = f(comboRate vs antiCombo)

**Body Part System (部位):** Heroes have 6 body parts with individual posture values (partPosture 0-5). Attacks target specific parts — breaking a part's posture opens it to heavy damage.

**The HeroSpeAddData system** is the universal bonus dictionary — ALL bonuses from equipment, buffs, talents, and skills flow through it. It has 198 enum types covering every modifier imaginable (damage, armor, speed, crit, elemental, exp rates, etc.).

### Hero Force Level (heroForceLv) — Faction Rank

`heroForceLv` is your rank within your faction, NOT raw power level:
- Advancing rank requires: contribution points + minimum skill counts
- Higher rank unlocks: access to better skills, more authority, better training grounds
- Rank affects: `maxAttri` (via `ManageHeroForceLvChangeMaxAttri()`) — so ranking up **permanently raises your stat ceilings**

**This is a major power multiplier** — ranking up in your faction directly expands how strong you can become.

### Hero Strength Level (heroStrengthLv)

`heroStrengthLv` (offset 0xBC, float) is the game's calculated overall power rating. It's derived from the sum of all your totalAttri + totalFightSkill + equipment. This is what the game displays as your "combat power" (战力).

### Aptitude (资质 / talent field)

The `talent` field (offset 0x1DC, Int32) on HeroData determines innate learning speed:
- **究极** (Ultimate) — Fastest growth, rarest (~5% of characters)
- **超群** (Exceptional) — Very good growth
- **聪颖** (Clever) — Good growth
- **平平** (Average) — Standard
- **愚钝** (Dull) — Slowest growth

Aptitude affects how quickly baseAttri increases during training. A 究极 hero training the same skill will gain stats much faster than a 愚钝 hero. **This is the single most important stat for long-term character power.**

---

## 3. Starting the Game <a name="starting-the-game"></a>

### Story Mode (剧情模式)
- You start at age 18 in **仙霞派** (Xianxia Sect) territory
- Your starting faction is **仙霞派** (ID 25), a sword-focused sect
- Initial combat power: ~148, very low — you are a complete novice
- **Opening plot**: 唐门 (Tang Clan) and 青城派 are hunting fugitives 王添翼 and 岳无畏 in the 大理 area

### Free Mode (自由模式)
- You start at age 18, **unaffiliated** (belongForceID = -1)
- Starting near **京城** (capital city)
- More freedom to choose your path — join any faction or go solo

### Early Game Priority
1. **Join a faction** — gives you access to their martial arts library and training
2. **Train internal arts first** — these boost ALL your stats permanently
3. **Build relationships** — gift, spar, and do favors to increase hero affinity
4. **Do every event you see** — colored star ratings indicate difficulty and reward quality

---

## 3. Faction Guide (门派) <a name="faction-guide"></a>

### Tier 1 — Major Powers (Grade 5-6)
These are the strongest factions with the best skills and resources.

| Faction | Grade | Style | Martial Specialties | Life Skills | Special Items | Notes |
|---------|-------|-------|-------------------|-------------|---------------|-------|
| **阎罗殿** (Yanluo Palace) | 6 | Aggressive | 内功/刀法/绝技/拳掌 | 采伐 | Equipment | Villain faction, strongest leader 阎罗王 (power rank -1) |
| **大隐阁** (Hidden Pavilion) | 6 | Neutral | 内功/轻功/奇门/剑法 | 学识/口才 | Treasures ×2 | Scholarly elite, has 归墟秘典 (top internal art) |
| **少林寺** (Shaolin) | 6 | Righteous | 内功/绝技/长兵/拳掌 | 医术 | Manuals | Classic powerhouse — 易筋经, 洗髓经, 金刚不坏神功 |
| **武当派** (Wudang) | 5 | Righteous | 内功/绝技/剑法/拳掌 | 木植/炼药 | Manuals | Balanced — 太极神功, 太极拳法, 太极剑道 |
| **茅山派** (Maoshan) | 5 | Neutral | 绝技/奇门/剑法 | 炼药 | Pills ×1.5 | Strange arts, 天劫九重 (top 奇门, power 25) |
| **金刚密宗** (Vajra Sect) | 5 | Aggressive | 内功/绝技/奇门 | 烹饪 | Food ×1.5 | Buddhist esoteric, powerful 因陀罗杵 and 大日如来功 |
| **五毒教** (Five Poisons) | 5 | Aggressive | 奇门/绝技/拳掌 | 木植/毒术 | Treasures | Poison specialists, 万毒宝典 |
| **丐帮** (Beggar's Sect) | 5 | Righteous | 拳掌/长兵/绝技 | 口才/烹饪 | Food ×2 | 降龙掌法 (power 26, highest fist) + 打狗八绝棍 |

### Tier 2 — Mid Powers (Grade 3-4)
| Faction | Grade | Style | Martial Specialties | Life Skills | Special Items |
|---------|-------|-------|-------------------|-------------|---------------|
| **唐门** (Tang Clan) | 4 | Aggressive | 绝技/射术/刀法 | 毒术 | Materials ×1.5 |
| **药王谷** (Medicine Valley) | 4 | Neutral | 内功/拳掌/射术 | 医术/炼药 | Pills ×2 |
| **飞龙门** (Flying Dragon) | 4 | Neutral | 绝技/长兵/刀法 | 采伐 | Horses ×2 |
| **峨眉派** (Emei) | 4 | Righteous | 内功/轻功/拳掌 | 木植 | Materials |
| **天山派** (Tianshan) | 4 | Aggressive | 轻功/内功/拳掌 | 医术 | Pills |
| **神机门** (Mechanism Gate) | 4 | Righteous | 奇门/射术/绝技 | 学识/锻造 | Equipment ×1.5 |
| **长乐帮** (Changle Gang) | 3 | Neutral | 轻功/刀法/射术 | 口才 | Treasures ×1.5 |
| **铸剑山庄** (Sword Forge) | 3 | Neutral | 剑法/绝技/刀法 | 采伐/锻造 | Equipment ×2 |
| **霸刀门** (Tyrant Blade) | 3 | Neutral | 刀法/长兵/绝技 | 烹饪 | Food |
| **蓬莱派** (Penglai) | 3 | Righteous | 内功/剑法/奇门 | 学识 | Manuals |
| **崆峒派** (Kongtong) | 3 | Aggressive | 绝技/奇门/长兵 | 毒术 | Horses |
| **霹雳堂** (Thunder Hall) | 3 | Neutral | 射术/绝技/长兵 | 锻造 | Materials ×2 |

### Tier 3 — Minor Factions (Grade 0-2)
聚义门, 黄河帮, 八卦门, 海沙帮, 铁掌帮, 仙霞派 (your starting sect in story mode), 巨鲸帮, 金龙帮, 青城派, 伏牛派.

### Recommended Faction Choices

**For Combat Power**: 少林寺 or 阎罗殿 — best internal arts + widest skill coverage
**For Balanced Play**: 武当派 — strong in everything, righteous alignment
**For Swordplay**: 大隐阁 — top sword + internal art combo, scholarly bonuses
**For Assassination**: 唐门 or 天山派 — ranged/stealth builds
**For Crafting**: 铸剑山庄 or 霹雳堂 — forge your own equipment

---

## 4. Character & Recruitment Guide <a name="character-guide"></a>

### Best Recruits by Role

**Ultimate Powerhouses** (Hidden characters, power level 15):
| Character | Hidden Faction | Specialty | Signature Moves | Tags |
|-----------|---------------|-----------|-----------------|------|
| **逍遥生** | 大隐阁 | 奇门/绝技/轻功 | 天劫九重; 公输遗匣; 碧海潮生曲 | 万物归墟; 游戏人间; 神机妙算 |
| **独孤剑** | 蓬莱派 | 剑法/轻功/内功 | 无尽剑意; 诛仙剑法; 仙娥折梅 | 返璞归真; 人剑合一; 武学天才 |
| **炼气士** | 峨眉派 | 射术/轻功/绝技 | 多情飞刀 + 7 hidden weapons | 天人合一; 先天真气; 不老长生 |
| **都点检** | 飞龙门 | 长兵/绝技/内功 | 龙胤归藏功; 打狗八绝棍; 达摩神杖 | 登峰造极; 不动如山; 艺成百家 |
| **独臂刀** | 阎罗殿 | 刀法/内功/绝技 | 霸刀一式; 净乐琉璃刀; 蚩尤鬼降 | 十殿阎王; 侠义无双; 至死不渝 |
| **斗酒僧** | 少林寺 | 拳掌/内功/轻功 | 醉梦鱼龙舞; 灵犀一指; 白虹贯日掌 | 即身成佛; 天人合一; 刀枪不入 |

**Early-Game Recruitable Stars** (power level 3-4):
| Character | Affiliation | Aptitude | Specialty | Why Recruit |
|-----------|-------------|----------|-----------|-------------|
| **余采薇** (ID 4) | 仙霞派 | 究极 | 内功/轻功/剑法 | "武学天才" tag, best aptitude in starting sect |
| **白云天** (ID 51) | 峨眉派 | 究极 | 内功/轻功/剑法 | Ultimate aptitude, has 三洞灵宝经 |
| **张文馨** (ID 43) | 武当派 | 究极 | 剑法/拳掌 | "武学天才", knows 道德真经 + 太极剑道 |
| **思中澜** (ID 37) | 大隐阁 | 究极 | 剑法 | "武学天才", has 天来剑术 + 归墟秘典 |
| **李天临** (ID 168) | 无 | 究极 | 剑法/奇门 | "武学天才", young (18), unaffiliated = easy recruit |
| **阮芷** (ID 129) | 大隐阁 | 究极 | 奇门 | "足智多谋; 锐眼; 见多识广" |

**Aptitude Tiers** (affects training speed):
- **究极** (Ultimate) — fastest learning, rarest
- **超群** (Exceptional) — very good
- **聪颖** (Clever) — good
- **平平** (Average)
- **愚钝** (Dull) — slowest

### The "侠义七子" (Seven Righteous Heroes)
A group of young heroes from different sects, all recruitable:
- 项问天 (飞龙门, 刀法) — righteous warrior
- 郭勇锐 (丐帮, 拳掌) — honest fool
- 阮芷 (大隐阁, 奇门) — genius strategist (究极 aptitude!)
- 彗定 (少林寺, 长兵) — devoted monk
- 清风 (武当派, 剑法) — cunning beauty
- 李云鹤 (药王谷, 射术) — kind healer
- 吕舞阳 (蓬莱派, 剑法) — ruthless swordsman

### The "侠盗四奇" (Four Odd Thieves)
Legendary retired fighters — **天残, 地缺, 南丑, 北怪**. All power level 6 with **元始天功** + **飘飘欲仙** + **虎啸龙吟**. Each has a disability tag but incredible power. They also appear in younger "中年" (middle-aged) versions at power 3.

### Characters to Watch Out For
- **阎罗王** (ID 29) — Yanluo King, enemies with 道无名, 空闻, 张青蓬, 郭淮. The game's main antagonist figure.
- **金龙生** (ID 139) — "江湖百晓" (Jianghu Know-It-All), power 7 with 究极 aptitude, knows everything. Scholars dream recruit.
- **墨璇玑** (ID 54) — 神机门 master crafter, 究极 aptitude, but sickly (旧病沉疴; 脉络阻塞)

---

## 5. Martial Arts System & Skill Recommendations <a name="martial-arts"></a>

### The 9 Martial Categories

| Category | Chinese | Role | Key Stat |
|----------|---------|------|----------|
| **Internal Arts** (内功) | 内功 | Foundation — boosts all stats | 内功, 经脉 |
| **Lightness** (轻功) | 轻功 | Evasion, movement speed | 灵巧 |
| **Absolute Arts** (绝技) | 绝技 | Defense, special techniques | 力道, 体质 |
| **Fist/Palm** (拳掌) | 拳掌 | Unarmed/palm strikes | 力道, 经脉 |
| **Sword** (剑法) | 剑法 | Elegant, balanced offense | 灵巧 |
| **Blade** (刀法) | 刀法 | Heavy offensive | 力道 |
| **Polearm** (长兵) | 长兵 | Range + power | 体质, 意志 |
| **Exotic** (奇门) | 奇门 | Unusual weapons, tricks | 智力 |
| **Ranged** (射术) | 射术 | Projectiles, hidden weapons | 灵巧, 智力 |

### 9 Life Skill Categories
| Skill | Chinese | Use |
|-------|---------|-----|
| Medicine | 医术 | Heal injuries, cure poison |
| Poison | 毒术 | Apply poison, create toxins |
| Scholarship | 学识 | Research, learn faster |
| Eloquence | 口才 | Persuade, negotiate, recruit |
| Harvesting | 采伐 | Gather wood, ore, materials |
| Planting | 木植 | Grow herbs, food ingredients |
| Forging | 锻造 | Craft weapons, armor |
| Alchemy | 炼药 | Brew potions, pills |
| Cooking | 烹饪 | Cook food for buffs |

### Training Priority Order

**Early Game (low stats, low ceilings):**
1. **Internal Art (内功)** — Train this first. It raises your core attributes while you practice.
2. **One attack skill** — Pick ONE weapon type and focus. Spreading thin wastes time.
3. **Lightness (轻功)** — Evasion keeps you alive while you're weak.

**Mid Game (decent base, need ceiling raises):**
1. **Switch to 潜力-heavy skills** — Raise ceilings for your core stats
2. **Rank up in your faction** — `heroForceLv` increases directly boost maxAttri
3. **Absolute Art (绝技)** — Defense becomes important for harder content

**Late Game (high ceilings, maxing out):**
1. **龙胤归藏功** if you can get it — raises ALL ceilings (but slow at 3.0 exp cost)
2. **Direct-stat skills** to fill up to your raised ceilings
3. **Multiple weapon types** for tactical flexibility

**Do NOT:** Train 4 different weapon skills early game. Each skill needs separate exp — focus wins.

---

## 6. Internal Arts (内功) — The Foundation <a name="internal-arts"></a>

Internal arts don't have attack power — they **permanently boost your attributes** while training. Higher-tier ones give "潜力" (potential) bonuses that are far more valuable.

### God-Tier Internal Arts

| Name | Faction | Training Effect | Exp Coeff | Notes |
|------|---------|----------------|-----------|-------|
| **龙胤归藏功** | Universal | ALL 6 attribute potentials +1 | **3.0 (very slow)** | Ultimate art — raises every ceiling. Worth the grind. |
| **易筋经** | 少林寺 | 经脉潜力2; 内功潜力2; 内功1; 经脉1 | 1.3 | Shaolin's crown jewel — strong potential + direct gains |
| **归墟秘典** | 大隐阁 | 智力潜力2; 内功潜力1; 内功1; 智力1 | 1.3 | Best for intelligence-based builds |
| **不老长春功** | 天山派 | 内功潜力2; 经脉潜力1; 内功1; 经脉1 | 1.3 | Grants "不老长生" — slows aging |
| **太极神功** | 武当派 | 内功潜力2; 智力潜力1; 内功1; 智力1 | 1.0 | Wudang's signature — **1.0 coeff makes it efficient!** |
| **洗髓经** | 少林寺 | 力道潜力2; 意志潜力1; 内功1; 力道1 | 1.1 | Body transformation — strength path |
| **大日如来功** | 金刚密宗 | 内功潜力2; 智力潜力1; 内功1; 智力1 | 1.2 | Buddhist tantric power |
| **万恶魔功** | 阎罗殿 | 力道潜力2; 内功潜力1; 内功1; 力道1 | 1.0 | Evil path — **1.0 coeff = fast for its tier** |
| **元始天功** | Universal | 内功潜力2; 绝技潜力1; 智力1; 经脉1 | 1.1 | Rare universal — learned by 侠盗四奇 |
| **龙虎金丹功** | 茅山派 | 内功潜力1; 经脉潜力1; 体质潜力1 | 1.2 | Triple potential — three ceilings at once |

### Internal Art Training Strategy

**Key insight:** Internal arts give NO attack power (基础威力 = 0). Their ENTIRE value is the stat growth from training them. Pick based on **which stats you need** and **how fast you need them**.

- **Early game**: Use your faction's basic arts (经验系数 0.8-1.0 = fast to train)
- **Mid game**: Switch to arts with 潜力 (potential) bonuses to raise your ceilings
- **Late game**: 龙胤归藏功 is the ultimate goal — all 6 potentials. But at 经验系数 3.0 it takes **3x longer** per level. Only worth it once you've exhausted easier options.

**Efficiency picks** (great training effect relative to exp cost):
- **太极神功** (武当派, exp 1.0) — 内功潜力2 + 智力潜力1 at standard training speed. Best ratio.
- **万恶魔功** (阎罗殿, exp 1.0) — 力道潜力2 + 内功潜力1 at standard speed. Evil but efficient.
- **洗髓经** (少林寺, exp 1.1) — 力道潜力2 + 意志潜力1. Near-standard cost for top growth.

**Avoid assuming "best skill = best choice":** 龙胤归藏功 is mathematically superior but you'll spend 3x the time per level. A character training 太极神功 will hit practical power benchmarks much sooner.

---

## 7. Combat Skills — Best Picks by Weapon Type <a name="combat-skills"></a>

> **Reading the tables below:**
> - **Power** = 基础威力, the skill's base damage. Higher = more damage per hit.
> - **Exp** = 经验系数, the training cost multiplier. Lower = faster to level up (0.8 is fast, 1.3 is slow).
> - **Training** = Stats gained while practicing. "潜力" raises ceilings (long-term); direct stats give immediate power.
> - **Efficiency** = Power-to-training-cost ratio. A high-power, low-exp-cost skill is the best value.

### Fist/Palm (拳掌) — Top Picks
| Skill | Power | Exp | Faction | Training | Notes |
|-------|-------|-----|---------|----------|-------|
| **降龙掌法** | 26 | 0.9 | 丐帮 | 拳掌潜力1; 力道潜力2; 经脉2 | **Best fist** — high power + low cost + great growth |
| **玄冥神掌** | 24 | 1.1 | 天山派 | 经脉潜力2; 拳掌1; 经脉1 | Good power, raises meridian ceiling |
| **白虹贯日掌** | 23 | 1.0 | 天山派 | 拳掌潜力1; 经脉潜力2; 拳掌1; 经脉1 | **Best training value** — 4 stat gains at standard cost |
| **大力金刚掌** | 23 | 1.0 | 少林寺 | 力道潜力2; 拳掌1; 力道1 | Pure strength ceiling + immediate gains |
| **太极拳法** | 21 | 1.0 | 武当派 | 拳掌潜力2; 拳掌1; 经脉1 | Pairs with 太极神功, standard cost |
| **酒仙散手** | 22 | **1.2** | 丐帮 | 拳掌潜力2; 拳掌1; 力道1 | Decent but slower than 降龙掌法 |

### Sword (剑法) — Top Picks
| Skill | Power | Exp | Faction | Training | Notes |
|-------|-------|-----|---------|----------|-------|
| **诛仙剑法** | 25 | 1.1 | Universal | 剑法潜力2; 灵巧潜力1; 灵巧2 | **Best sword** — high power, good growth, findable anywhere |
| **太极剑道** | 23 | 1.1 | 武当派 | 剑法潜力2; 智力潜力1; 剑法1; 经脉1 | Intelligence path — pairs with 太极神功 |
| **灭心绝情剑** | 23 | 1.1 | 峨眉派 | 剑法潜力2; 剑法1; 灵巧1 | Cold-blooded technique |
| **九霄冲天剑** | 22 | **1.2** | 天山派 | 剑法潜力2; 剑法1; 经脉1 | Slightly slower to train |
| **天来剑术** | 22 | 1.0 | 大隐阁 | 剑法潜力2; 剑法1; 灵巧1 | **Most efficient** — good stats at standard cost |

### Blade (刀法) — Top Picks
| Skill | Power | Exp | Faction | Training | Notes |
|-------|-------|-----|---------|----------|-------|
| **霸刀一式** | **28** | **0.8** | 霸刀门 | 刀法潜力2; 力道潜力1; 体质潜力1 | **BEST MELEE IN GAME** — highest power AND easiest to train. Triple potential. |
| **九州风雷刀** | 26 | 1.1 | Universal | 刀法潜力2; 力道潜力1; 力道2 | Best universal blade — findable anywhere |
| **净乐琉璃刀** | 25 | 1.0 | 长乐帮 | 意志潜力2; 力道潜力1; 刀法潜力1 | Triple potential at standard cost |
| **杀人刀法** | 24 | 1.0 | 阎罗殿 | 体质潜力2; 刀法潜力1; 刀法1; 体质1 | 4 stat gains, evil alignment |
| **屠龙要术** | 22 | 1.1 | 铸剑山庄 | 刀法潜力2; 刀法1; 力道1 | Dragon-slaying technique |

### Polearm (长兵) — Top Picks
| Skill | Power | Exp | Faction | Training | Notes |
|-------|-------|-----|---------|----------|-------|
| **惊鸿一点枪** | 27 | 1.1 | 飞龙门 | 长兵潜力2; 意志潜力1; 长兵2 | **Best polearm** — top power, great training |
| **达摩神杖** | 24 | 1.0 | 少林寺 | 长兵潜力2; 体质潜力1; 经脉潜力1 | **Triple potential at standard cost!** Most efficient polearm. |
| **打狗八绝棍** | 23 | 1.1 | 丐帮 | 长兵潜力1; 经脉潜力2; 力道2 | Mix of potential + immediate power |
| **霸王枪法** | 23 | 1.0 | 霸刀门 | 长兵潜力2; 长兵1; 意志1 | Standard cost, solid choice |
| **八荒六合戟** | 23 | **1.2** | 飞龙门 | 体质潜力2; 长兵1; 体质1 | Slower but builds constitution |

### Exotic Weapons (奇门) — Top Picks
| Skill | Power | Exp | Faction | Training | Notes |
|-------|-------|-----|---------|----------|-------|
| **天劫九重** | 25 | 1.0 | 茅山派 | 奇门潜力2; 意志潜力2 | **Best exotic** — top power at standard cost, double potential |
| **因陀罗杵** | 24 | 1.0 | 金刚密宗 | 奇门潜力2; 智力潜力1; 奇门1; 力道1 | Indra's vajra — 4 stats at standard cost |
| **铁拐化龙** | 23 | 1.0 | 蓬莱派 | 奇门潜力2; 奇门1; 智力1 | Iron crutch, standard cost |
| **金刚伏魔圈** | 21 | **1.2** | 少林寺 | 奇门潜力2; 奇门1; 意志1 | Slightly slow but Shaolin quality |
| **画龙点睛** | 21 | 1.0 | 大隐阁 | 意志潜力2; 奇门1; 意志1 | Great willpower ceiling growth |

### Ranged (射术) — Top Picks
| Skill | Power | Exp | Faction | Training | Notes |
|-------|-------|-----|---------|----------|-------|
| **灭世天雷** | **30** | **1.3** | 霹雳堂 | 射术潜力1; 智力/意志潜力1; 锻造潜力2 | **HIGHEST POWER IN GAME** but slow to train. Raises crafting potential! |
| **神火飞鸦** | 24 | 1.1 | 霹雳堂 | 射术潜力2; 射术1; 灵巧1 | Easier alternative from same faction |
| **九天罗候针** | 24 | 1.0 | 唐门 | 射术/灵巧/智力潜力1; 毒术1 | **Most efficient ranged** — triple potential at standard cost |
| **呕血坐隐功** | 23 | **1.2** | 大隐阁 | 射术潜力2; 射术1; 灵巧1 | Scholarly ranged art |
| **多情飞刀** | 22 | **0.9** | Universal | 射术潜力2; 智力潜力1; 智力2 | **Easiest high-tier ranged** — fast to train, good intel growth |

---

## 8. Talent System (天赋/标签) <a name="talent-system"></a>

Each hero can equip **talents (标签/Tag)** that grant passive bonuses. The number of slots depends on `GetMaxTagNum()` which varies by hero status (typically 9-10 base slots).

**Talent Points (heroTagPoint)** are spent to acquire/change talents. You earn them through training and events.

### Key Talent Tags (from character data)
- **武学天才** — Martial genius, dramatically faster skill learning
- **炉火纯青** — Mastery level, skills deal more damage
- **绝艺超群** — Exceptional technique, combat bonus
- **身怀绝技** — Possesses special techniques
- **内力精纯** — Pure internal energy, better qi circulation
- **飞檐走壁** — Wall-running, high evasion
- **刀枪不入** — Invulnerable to weapons (defensive)
- **拔山扛鼎** — Mountain-lifting strength, power boost
- **剑随意动** — Sword follows thought, auto-parry
- **铁手钢拳** — Iron fists, unarmed damage boost
- **百步穿杨** — Hundred-pace accuracy, ranged bonus
- **神出鬼没** — Ghost-like movement, stealth bonus

### Talent Tip
With our cheat table, you can set talent points to 99 for your entire sect and raise the slot cap so every hero can have maximum talents equipped.

---

## 9. Item System <a name="item-system"></a>

### Item Types
| Type | ID | Description |
|------|----|-------------|
| **Equipment** (装备) | 0 | Weapons (Sword, Blade, Spear, etc.), Armor, Helmet, Shoes, Decoration |
| **Medicine** (药品) | 1 | HP/Mana recovery, injury healing |
| **Food** (食物) | 2 | Buff food, wine, soups |
| **Skill Book** (秘籍) | 3 | Learn martial arts from books |
| **Treasure** (珍宝) | 4 | Collectibles, trade goods |
| **Material** (材料) | 5 | Wood (木材), Ore (矿料), Medicine (药引), Food (食材), Poison (毒物) |
| **Horse** (马匹) | 6 | Mount — affects travel speed, combat mobility |

### Rarity Levels
1. **白** (White) — Common
2. **绿** (Green) — Uncommon
3. **蓝** (Blue) — Rare
4. **紫** (Purple) — Epic
5. **红/金** (Red/Gold) — Legendary

### Top-Tier Medicine
| Name | Effect |
|------|--------|
| 万灵回生散 | Full HP recovery |
| 紫霄玄关散 | Full Qi/Mana recovery |
| 九转还魂丹 | Complete body restoration |
| 天香断续散 | Heals all injuries |
| 还阳正气丹 | Cures all meridian damage |

### Material SubTypes
| ID | Type | Chinese |
|----|------|---------|
| 0 | Wood | 木材 |
| 1 | Ore | 矿料 |
| 2 | Medicine Base | 药引 |
| 3 | Food Ingredient | 食材 |
| 4 | Poison | 毒物 |

Material level 5 = 绝世 (Legendary) prefix.

---

## 10. Quest & Event Guide <a name="quest-guide"></a>

### Event Color = Difficulty Rating
Events are color-coded in the quest log:
- <span style="color:green">**绿色 (Green) ★★**</span> — Easy, low risk
- <span style="color:blue">**蓝色 (Blue) ★★★**</span> — Moderate
- <span style="color:orange">**橙色 (Orange) ★★★★★**</span> — Hard, good rewards
- <span style="color:purple">**紫色 (Purple) ★★★★**</span> — Special/plot-related
- <span style="color:red">**红色 (Red) ★★★★★★**</span> — Extreme, best rewards

### Main Plot Events
1. **大理混战** (Battle of Dali) — Tang Clan + Qingcheng hunting fugitives in 大理北方. Your starting story hook.
2. **白云下山** (Baiyun Descends) — A girl from 峨眉派 wants to sneak out while the master is away. Location: 峨眉派.
3. **疯癫邪道(二)** — Mad heretics appear near 佛山镇北方, poisoned by some strange toxin.

### Recurring Event Types
| Event | Description | Priority |
|-------|-------------|----------|
| **比武大赛** (Tournament) | Fight tournament in cities, great rewards | **HIGH** — attend every one |
| **拍卖大会** (Auction) | Buy rare items at auction | **HIGH** if you have money |
| **飞贼夺物** (Thief Chase) | Stop a thief, recover stolen goods | Medium |
| **采花大盗** (Flower Thief) | Stop a predator | Medium — reputation boost |
| **家传兵器** (Family Heirloom) | Find/return a family weapon | **HIGH** — often legendary gear |
| **参加宴会** (Attend Banquet) | Social event, build relationships | Medium |
| **赤脚医生** (Barefoot Doctor) | Medical event, needs 医术 skill | Medium |
| **侠士论战** (Heroes' Debate) | Philosophical debate, needs 学识/口才 | Medium |
| **吟诗作赋** (Poetry Contest) | Needs 学识 | Low unless high scholarship |
| **招募家丁** (Recruit Servants) | Hire NPCs | Low |
| **千里名驹** (Legendary Horse) | Tame a rare horse near 霸刀门南方 | **HIGH** — "凶险奇遇, 建议携队友前往" (dangerous, bring companions!) |

### Travel Events (Big Map)
| Event | Description | Priority |
|-------|-------------|----------|
| **高手比武** (Expert Duel) | Fight a random master | Medium-High |
| **武林争斗** (Martial Conflict) | Faction battle, pick a side | Medium |
| **隐居铁匠/神医** (Hidden Smith/Doctor) | Find hidden NPCs for rare items/healing | **HIGH** |
| **世外桃源** (Hidden Paradise) | Discover a hidden area | **HIGH** — unique rewards |
| **上古遗迹** (Ancient Ruins) | Explore ruins for treasure | **HIGH** |
| **藏宝地图** (Treasure Map) | Follow map to treasure | **HIGH** |
| **采掘材料** (Gather Materials) | Resource gathering spot | Low |
| **争夺宝物** (Treasure Contest) | Compete for a treasure | Medium-High |
| **门派恩怨** (Sect Grudge) | Inter-faction conflict | Medium |
| **无名地窖** (Unknown Cellar) | Hidden dungeon | **HIGH** |

---

## 11. Map & Locations <a name="map-locations"></a>

### Major Cities & Their Specialties
| City | Controlled By | Specialty Good | Notes |
|------|--------------|----------------|-------|
| **京城** (Capital) | 飞龙门 | 棋谱 (Chess Manual) | Central hub, many events |
| **杭州** | Neutral | 字帖 (Calligraphy) | Eastern trading hub |
| **福州** | 大隐阁 | 木材/矿料 | Crafting materials |
| **大理** | 峨眉派 | 食材/毒物 | Major story location |
| **幽州** | 茅山派 | 香炉 (Incense) | Northern frontier |
| **晋阳** | 少林寺 | 画本 (Painting) | Near Shaolin |
| **成都** | 唐门 | 酒器 (Wine Vessel) | Sichuan, Tang Clan territory |
| **西凉** | 霸刀门 | 珠玉 (Gems) | Western frontier |
| **江陵** | 武当派 | 史书 (History Books) | Central China |
| **扬州** | 神机门 | 服饰 (Clothing) | Rich trading city |
| **逻娑** | 金刚密宗 | 药引 (Medicine Base) | Tibet/high altitude |
| **灵州** | 天山派 | 乐器 (Musical Instruments) | Far northwest |
| **应天** | 丐帮 | 典籍 (Classics) | Southern capital |

### Strategic Territory Tips
- Cities have levels (1-5) — higher = better shops, more events
- Faction-controlled towns provide benefits to that faction's members
- Conquer towns by defeating the local garrison (needs high power + companions)
- Some towns are adjacent to faction headquarters — control them for strategic advantage

---

## 12. Economy & Trading <a name="economy"></a>

### Money-Making Strategies
1. **Sell crafted equipment** — forge weapons/armor from gathered materials
2. **Tournament prizes** — 比武大赛 gives excellent rewards
3. **Auction flipping** — buy undervalued items at 拍卖大会
4. **Treasure hunting** — 藏宝地图, 上古遗迹 events
5. **Materials farming** — gather 绝世 (lv5) materials for crafting or sale

### City Specialty Goods
Buy specialty items cheap in their home city, sell them at a markup elsewhere. The trading system rewards long-distance travel.

---

## 13. Tips & Tricks <a name="tips"></a>

### Combat
- **Pair your internal art with your weapon stat** — e.g., strength-building 内功 + blade (刀法) skills, or meridian-building 内功 + fist (拳掌)
- **The potential/ceiling system is key** — a character who trained 潜力 skills early will crush one who only trained direct stats, given enough time
- **Bring companions to dangerous events** — "凶险奇遇" warnings are real
- **Save before tournaments** — losing means wasted time
- **Body part posture matters** — attacks target specific body parts. Broken posture = massive damage

### Character Building
- **Aptitude (资质) is the single most important trait** — 究极 heroes learn faster, making every hour of training more valuable. 究极 > 超群 > 聪颖 > 平平 > 愚钝
- **Young characters (age 16-20) have more room to grow** — they'll train longer before aging penalties
- **Personality affects behavior**: 稳重 (steady) and 忠厚 (loyal) are reliable; 叛逆 (rebellious) and 算计 (scheming) may betray you
- **Alignment matters for recruitment**: 善良 (good) characters resist joining evil factions
- **Don't judge by starting power** — a young 究极 character with low current stats will far surpass an old 平平 character with high stats, given training time

### Faction Management
- **Rank up (heroForceLv)** — this permanently raises stat ceilings via `ManageHeroForceLvChangeMaxAttri()`. Ranking up is NOT optional.
- **Recruit characters with complementary skills** — don't stack all sword users
- **Life skills are as important as combat** — you need a doctor (医术), a crafter (锻造), an alchemist (炼药)
- **Talent slots are limited** (base 10 for NPCs) — choose combat-relevant tags first

### Recommended Early Build Path (Story Mode)
1. Start in 仙霞派 → train their basic 剑法 and 内功 (low exp cost = fast progress)
2. Recruit 余采薇 (究极 aptitude, already in your sect)
3. Focus on ONE weapon type + internal art. Don't spread training across multiple weapons
4. Attend every 比武大赛 — rewards + reputation + combat exp
5. Get the 千里名驹 event horse near 霸刀门 (bring companions! it's marked 凶险)
6. Rank up in your faction ASAP — the maxAttri ceiling boost is massive
7. Work toward a high-tier 内功 book: 太极神功 (exp 1.0, efficient) or 万恶魔功 (exp 1.0, evil path)
8. Visit 大理 for main plot when you feel ready (difficulty ★★★)
9. Eventually aim for 龙胤归藏功 as your endgame internal art

### Skill Picking Rule of Thumb
When comparing two skills, calculate **value = (power + potential_count×3) / exp_coefficient**:
- 霸刀一式: (28 + 3×3) / 0.8 = **46.3** ← exceptional
- 降龙掌法: (26 + 3×3) / 0.9 = **38.9** ← great
- 灭世天雷: (30 + 3×3) / 1.3 = **30.0** ← decent power but slow
- 多情飞刀: (22 + 3×3) / 0.9 = **34.4** ← surprisingly good value

This rough formula helps compare across categories. But also factor in which stats you actually need.

### Keyboard Shortcuts (with BepInEx mods)
- **P** — Toggle auto-continue dialog (TraceData plugin)
- **F11** — Cycle outside-battle speed (StaminaLock plugin)

---

*Guide compiled from game data files, IL2CPP memory dumps, quest snapshots, and the 龙胤立志传数据资料.xlsx spreadsheet. Some mechanics may vary with game updates.*
