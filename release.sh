#!/bin/bash
# Release script for LongYinLiZhiZhuan Cheat Table
# Usage: ./release.sh v6.2 "Brief description of changes"

VERSION=$1
DESC=$2
CT_FILE="games/LongYinLiZhiZhuan/patches/LongYinLiZhiZhuan.CT"

if [ -z "$VERSION" ] || [ -z "$DESC" ]; then
  echo "Usage: ./release.sh <version> <description>"
  echo "Example: ./release.sh v6.2 'Fix talent slots, add fog removal'"
  exit 1
fi

echo "=== Creating release $VERSION ==="

# 1. Git tag + push
git tag -a "$VERSION" -m "$DESC"
git push origin "$VERSION"

# 2. Generate changelog from last tag
PREV_TAG=$(git tag --sort=-v:refname | head -2 | tail -1)
echo ""
echo "=== Changelog since $PREV_TAG ==="
CHANGELOG=$(git log "$PREV_TAG"..HEAD --oneline --no-merges | head -20)
echo "$CHANGELOG"

# 3. Create GitHub Release
echo ""
echo "=== Creating GitHub Release ==="
gh release create "$VERSION" "$CT_FILE" \
  --title "龙胤立志传 修改器 $VERSION" \
  --notes "$(cat <<EOF
# 龙胤立志传 修改器 $VERSION

$DESC

## Changes
$CHANGELOG

## 使用方法 / How to Use
1. 下载 Cheat Engine 7.6: https://cheatengine.org
2. 打开游戏，用CE连接游戏进程
3. 加载 .CT 文件，启用修改

## 功能列表 / Features
资源/天赋/武学/生命/声望/门派资源/科研/建筑/旅行/战斗/属性/探索
物品添加器: 武器/防具/宝物/秘籍/马匹 (自选品质)
EOF
)"

echo ""
echo "=== GitHub Release created ==="
echo "URL: https://github.com/tantk/cheatengine-mcp-bridge/releases/tag/$VERSION"

# 4. Generate forum post text
echo ""
echo "=========================================="
echo "=== Copy-paste for FearlessRevolution ==="
echo "=========================================="
cat <<EOF

[b]LongYinLiZhiZhuan (龙胤立志传) Cheat Table $VERSION[/b]

$DESC

[b]Features:[/b]
[list]
[*]Money, Resources, Sect Currency, Faction Contribution
[*]Talent Points + Max Slots (99)
[*]Skill EXP Buffs (Combat + Living)
[*]HP Restore, Clear Injuries
[*]NPC Favor, Fame, Faction Affinity
[*]Sect Resources (fill to cap), No Resource Cost
[*]Instant Research, Instant Buildings
[*]Horse Speed Boost, Battle Speed Boost
[*]One-Hit KO, Stat Caps
[*]Fog of War Removal (dungeons)
[*]Item Adder: Weapons, Armor, Helmets, Shoes, Accessories, Horse Armor, Treasures, Books, Medicine, Food, Horses, Materials
[/list]

[b]Requirements:[/b] Cheat Engine 7.6+

[b]Download:[/b] [url=https://github.com/tantk/cheatengine-mcp-bridge/releases/tag/$VERSION]GitHub Release[/url]

[b]Notes:[/b]
- Auto-resolves method addresses at runtime (survives game updates)
- Bilingual UI (Chinese + English)
- Horse speed is saved with game — disable before saving
EOF

# 5. Generate Bilibili description text
echo ""
echo "=========================================="
echo "=== Copy-paste for Bilibili ==="
echo "=========================================="
cat <<EOF

【龙胤立志传】全功能修改器 $VERSION

$DESC

下载地址:
GitHub: https://github.com/tantk/cheatengine-mcp-bridge/releases/tag/$VERSION

需要 Cheat Engine 7.6: https://cheatengine.org

功能: 银两/资源/贡献/好感/声望/天赋/武学经验/气血/伤势
一击必杀/瞬间建筑/瞬间研究/马匹加速/战斗加速/揭示副本全图
物品添加器(武器/防具/宝物/秘籍/马匹等 自选品质)
EOF

echo ""
echo "=== Done! ==="
