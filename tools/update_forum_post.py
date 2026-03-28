"""
FearlessRevolution Forum Post Updater
Updates the cheat table post with latest features/changelog.

Usage:
  python update_forum_post.py --user YOUR_USER --pass YOUR_PASS --post-id 446470

Requires: pip install requests beautifulsoup4
"""

import requests
from bs4 import BeautifulSoup
import argparse
import time
import os
import subprocess

FORUM_URL = "https://fearlessrevolution.com"
TOPIC_URL = f"{FORUM_URL}/viewtopic.php?f=4&t=38568"

def get_changelog(n=10):
    """Get recent git commits as changelog."""
    try:
        result = subprocess.run(
            ["git", "log", f"--oneline", f"-{n}", "--no-merges"],
            capture_output=True, text=True, cwd=os.path.dirname(__file__) or "."
        )
        return result.stdout.strip()
    except:
        return "(changelog unavailable)"

def generate_bbcode():
    """Generate the BBCode content for the forum post."""
    changelog = get_changelog(15)

    return f"""[size=150][b]龙胤立志传 / LongYinLiZhiZhuan — All-in-One Cheat Table[/b][/size]

[b]Game:[/b] 龙胤立志传 (LongYinLiZhiZhuan) — Steam
[b]CE Version:[/b] 7.6 required
[b]Auto-updates:[/b] RVAs resolved at runtime — survives game patches

[size=130][b]Features[/b][/size]

[b]Resources[/b]
[list]
[*]Set Money (银两)
[*]Max Carry Weight (负重上限)
[*]Max Rarity All Items (品质全满)
[*]Set Sect Currency (门派贡献)
[/list]

[b]Talents[/b]
[list]
[*]Max Talent Slots → 99 (天赋槽位)
[*]Set Talent Points (天赋点)
[*]Sect-Wide Talent Editor (全门派天赋)
[/list]

[b]Skills[/b]
[list]
[*]Max Skill Learn Limits → 99 (武学上限)
[*]Combat EXP Buff — 武学天才 (configurable %)
[*]Living EXP Buff — 博学多才 (configurable %)
[/list]

[b]Health[/b]
[list]
[*]Restore HP (回满气血)
[*]Clear All Injuries (清除伤势)
[/list]

[b]Reputation[/b]
[list]
[*]Max NPC Favor (好感全满)
[*]Set Fame / Clear Bad Fame (声望/恶名)
[*]Faction Contribution for shops (外门贡献)
[*]Faction Affinity (门派好感度)
[/list]

[b]Sect Management[/b]
[list]
[*]Max Sect Resources — fill to cap (门派资源)
[*]No Resource Cost — resources never consumed (无消耗)
[*]Instant Research Completion (瞬间研究)
[*]Instant Building Completion (瞬间建筑)
[/list]

[b]Exploration[/b]
[list]
[*]Reveal Dungeon Map — removes fog of war (揭示副本全图)
[/list]

[b]Travel & Battle[/b]
[list]
[*]Horse Speed Boost — configurable multiplier (马匹加速)
[*]Battle Speed Boost — up to 999x (战斗加速)
[*]One-Hit KO — all enemies to 1 HP (一击必杀)
[/list]

[b]Stats[/b]
[list]
[*]Set Stat Caps — all attributes/skills (属性上限)
[/list]

[b]Item Adder (GUI)[/b]
[list]
[*]Martial Arts Books (G5) — 40+ skills
[*]Materials (Wood/Ore/Medicine/Food/Poison)
[*]Medicine & Food (Grade 3-5)
[*]Horses — 100% tame (48 types)
[*]Weapons — 36 types, Level 0-5, Rarity 0-5
[*]Armor / Helmet / Shoes — 6 types each
[*]Accessories — 6 types (Sachet/Fan/Ring/Pendant/Belt/Mask)
[*]Horse Armor (Saddle)
[*]Treasures — 10 types (Instrument/Chess/Calligraphy/etc)
[/list]

[size=130][b]How to Use[/b][/size]
[list=1]
[*]Download and install [url=https://cheatengine.org]Cheat Engine 7.6[/url]
[*]Start the game and load a save
[*]Open CE, attach to LongYinLiZhiZhuan.exe
[*]Load the .CT file
[*]Enable cheats from the table
[*]For Item Adder: expand the section, tick it, click "Connect to Game" first
[/list]

[b]Notes:[/b]
[list]
[*]Horse Speed is saved with game — disable before saving
[*]Fog of War reveal: click once per dungeon (enter dungeon first)
[*]Bilingual UI: Chinese + English
[/list]

[size=130][b]Recent Changes[/b][/size]
[code]{changelog}[/code]

[size=130][b]Download[/b][/size]
See attachment below.
"""


def login(session, username, password):
    """Login to phpBB forum."""
    login_url = f"{FORUM_URL}/ucp.php?mode=login"
    page = session.get(login_url)
    soup = BeautifulSoup(page.text, 'html.parser')

    form = soup.find('form', {'id': 'login'})
    if not form:
        print("ERROR: Login form not found")
        return False

    sid = form.find('input', {'name': 'sid'})
    sid_val = sid['value'] if sid else ''

    resp = session.post(login_url, data={
        'username': username,
        'password': password,
        'login': 'Login',
        'sid': sid_val,
        'redirect': 'index.php',
    })

    if 'logout' in resp.text.lower():
        print("Login successful!")
        return True
    else:
        print("ERROR: Login failed")
        return False


def edit_post(session, post_id, new_content, subject=None):
    """Edit an existing phpBB post."""
    edit_url = f"{FORUM_URL}/posting.php?mode=edit&p={post_id}"

    # Fetch edit form to get tokens
    page = session.get(edit_url)
    soup = BeautifulSoup(page.text, 'html.parser')

    form = soup.find('form', {'id': 'postform'})
    if not form:
        print("ERROR: Edit form not found — may not have permission")
        return False

    # Extract all hidden fields
    hidden = {}
    for inp in form.find_all('input', {'type': 'hidden'}):
        name = inp.get('name')
        if name:
            hidden[name] = inp.get('value', '')

    # Get current subject if not overriding
    if not subject:
        subj_input = form.find('input', {'name': 'subject'})
        subject = subj_input.get('value', '') if subj_input else ''

    # Submit edit
    data = {
        **hidden,
        'subject': subject,
        'message': new_content,
        'post': 'Submit',
        'addbbcode20': '100',
    }

    resp = session.post(edit_url, data=data, allow_redirects=False)

    if resp.status_code in (301, 302):
        print(f"Post {post_id} updated successfully!")
        return True
    else:
        print(f"ERROR: Edit may have failed (status {resp.status_code})")
        # Check for error message
        if 'error' in resp.text.lower():
            soup2 = BeautifulSoup(resp.text, 'html.parser')
            err = soup2.find('div', {'class': 'error'})
            if err:
                print(f"  Forum error: {err.get_text()}")
        return False


def main():
    parser = argparse.ArgumentParser(description='Update FearlessRevolution forum post')
    parser.add_argument('--user', required=True, help='Forum username')
    parser.add_argument('--password', required=True, help='Forum password')
    parser.add_argument('--post-id', default='446470', help='Post ID to edit')
    parser.add_argument('--dry-run', action='store_true', help='Print BBCode without posting')
    args = parser.parse_args()

    bbcode = generate_bbcode()

    if args.dry_run:
        print("=== DRY RUN — BBCode output ===")
        print(bbcode)
        return

    session = requests.Session()
    session.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'

    if not login(session, args.user, args.password):
        return

    time.sleep(1)  # Respect flood control

    edit_post(session, args.post_id, bbcode)


if __name__ == '__main__':
    main()
