import streamlit as st
import pandas as pd
import json
import requests
import time
from datetime import datetime
from pathlib import Path
from collections import Counter

# ════════════════════════════════════════════════════════════════
# CONFIG
# ════════════════════════════════════════════════════════════════
st.set_page_config(
    page_title="ONE · Admin",
    page_icon="🎵",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap');

/* ── Global ── */
html, body, [class*="css"], .stApp { font-family:'Inter',sans-serif !important; background:#f5f5f7 !important; }
.block-container { padding:1.5rem 2rem 3rem 2rem !important; max-width:1400px !important; }
p, span, div, label, li { color:#1a1a1a !important; }

/* ── Page header gizle ── */
header[data-testid="stHeader"] { background: transparent !important; }

/* ── Tabs ── */
.stTabs [data-baseweb="tab-list"] {
    gap:4px; background:#e8e8ed; padding:5px;
    border-radius:13px; border:1px solid #dcdce0; width:fit-content;
}
.stTabs [data-baseweb="tab"] {
    border-radius:9px; padding:7px 18px;
    font-weight:600; font-size:.82rem;
    color:#888 !important; background:transparent; border:none !important;
    transition: all .15s;
}
.stTabs [aria-selected="true"] {
    background:#fff !important; color:#1a1a1a !important;
    box-shadow:0 1px 5px rgba(0,0,0,.1);
}
.stTabs [data-baseweb="tab-border"] { display:none; }
.stTabs [data-baseweb="tab-panel"] { padding-top:1.2rem; }

/* ── Cards ── */
.one-card {
    background:#fff; border:1px solid #e4e4e9;
    border-radius:18px; overflow:hidden;
    transition:border-color .2s, box-shadow .2s;
    margin-bottom:.9rem;
    box-shadow:0 1px 3px rgba(0,0,0,.05);
}
.one-card:hover { border-color:#c4c4cc; box-shadow:0 4px 18px rgba(0,0,0,.09); }

.card-top { display:flex; align-items:center; gap:.7rem; padding:.8rem 1rem .6rem; }
.avatar {
    width:34px; height:34px; border-radius:50%;
    display:flex; align-items:center; justify-content:center;
    font-weight:800; font-size:.82rem; color:#fff; flex-shrink:0;
}
.dname { font-size:.86rem; font-weight:700; color:#1a1a1a !important; line-height:1.2; }
.uname { font-size:.69rem; color:#bbb !important; font-weight:500; }
.ts    { font-size:.67rem; color:#ccc !important; margin-left:auto; white-space:nowrap; }

/* Song row */
.song-row { display:flex; align-items:center; gap:.7rem; padding:.75rem 1rem .5rem; }
.art { width:48px; height:48px; border-radius:9px; object-fit:cover; flex-shrink:0; }
.art-ph { width:48px; height:48px; border-radius:9px; background:#f0f0f5; display:flex; align-items:center; justify-content:center; font-size:1.1rem; flex-shrink:0; }
.sname { font-size:.88rem; font-weight:700; color:#1a1a1a !important; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.aname { font-size:.74rem; color:#999 !important; margin-top:2px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.genre-tag { font-size:.67rem; color:#ccc !important; margin-top:1px; }

/* Card footer */
.card-foot { display:flex; align-items:center; gap:.4rem; flex-wrap:wrap; padding:.4rem 1rem .8rem; }
.mood-pill { display:inline-flex; align-items:center; gap:5px; padding:3px 9px; border-radius:20px; font-size:.73rem; font-weight:700; }
.mdot { width:6px; height:6px; border-radius:50%; display:inline-block; flex-shrink:0; }
.pill { background:#f0f0f5; border-radius:20px; padding:2px 8px; font-size:.68rem; color:#999 !important; font-weight:500; }
.note { padding:0 1rem .6rem; font-size:.76rem; color:#bbb !important; font-style:italic; line-height:1.4; }

/* Detay butonu — küçük link stili */
.det-btn {
    display:inline-block; font-size:.72rem; font-weight:600;
    color:#5460B8 !important; cursor:pointer;
    padding:.3rem .9rem; border-radius:8px;
    background:#eef0fb; border:1px solid #d4d8f5;
    margin:.2rem 1rem .8rem; transition:background .15s;
}
.det-btn:hover { background:#dde0f8; }

/* User profile card */
.user-profile-card {
    background:#fff; border:1px solid #e4e4e9; border-radius:18px;
    padding:1.1rem 1.2rem; margin-bottom:.7rem;
    box-shadow:0 1px 3px rgba(0,0,0,.05);
}
.up-header { display:flex; align-items:center; gap:.85rem; margin-bottom:.9rem; }
.up-avatar { width:46px; height:46px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-weight:800; font-size:1.05rem; color:#fff; }
.up-name { font-size:.95rem; font-weight:700; color:#1a1a1a !important; }
.up-user { font-size:.72rem; color:#bbb !important; }
.stat-row { display:flex; gap:.4rem; flex-wrap:wrap; margin-top:.4rem; }
.stat-chip { background:#f5f5f7; border:1px solid #e8e8ed; border-radius:9px; padding:4px 9px; font-size:.7rem; color:#999 !important; text-align:center; }
.stat-val { font-size:.9rem; font-weight:700; color:#1a1a1a !important; display:block; }

/* Leaderboard */
.leaderboard-row { display:flex; align-items:center; gap:.7rem; padding:.55rem .75rem; background:#fff; border:1px solid #eaeaef; border-radius:11px; margin-bottom:.35rem; }
.lb-rank { font-size:.78rem; font-weight:800; color:#ccc !important; width:18px; }
.lb-name { font-size:.83rem; font-weight:600; color:#1a1a1a !important; flex:1; }
.lb-val  { font-size:.78rem; color:#bbb !important; }

/* Sidebar */
section[data-testid="stSidebar"] { background:#fff !important; border-right:1px solid #e8e8ed !important; }
section[data-testid="stSidebar"] .block-container { padding:1rem !important; }
section[data-testid="stSidebar"] label { color:#1a1a1a !important; font-size:.78rem !important; font-weight:600 !important; }
section[data-testid="stSidebar"] .stCaption p { color:#bbb !important; }

/* Metrics */
[data-testid="stMetric"] { background:#fff; border:1px solid #e4e4e9; border-radius:14px; padding:.85rem 1rem; box-shadow:0 1px 3px rgba(0,0,0,.04); }
[data-testid="stMetricLabel"] p { color:#bbb !important; font-size:.72rem !important; font-weight:600 !important; text-transform:uppercase; letter-spacing:.05em; }
[data-testid="stMetricValue"] { color:#1a1a1a !important; font-size:1.55rem !important; font-weight:800 !important; }
[data-testid="stMetricDelta"] { display:none; }

/* Inputs */
input, textarea, [data-baseweb="input"] input { background:#f5f5f7 !important; border:1px solid #e0e0e5 !important; color:#1a1a1a !important; border-radius:9px !important; }
.stMultiSelect [data-baseweb="tag"] { background:#e8e8ed !important; }
.stMultiSelect [data-baseweb="tag"] span { color:#1a1a1a !important; }

/* Buttons — genel */
.stButton > button {
    background:#fff !important; color:#1a1a1a !important;
    border:1px solid #dcdce0 !important; border-radius:10px !important;
    font-weight:600 !important; font-size:.82rem !important;
    padding:.4rem .95rem !important;
    box-shadow:0 1px 3px rgba(0,0,0,.06) !important;
    transition:all .15s !important;
}
.stButton > button:hover { background:#f5f5f7 !important; border-color:#c4c4cc !important; }
/* Primary — sadece yenile butonu için koyu */
.stButton > button[kind="primary"] {
    background:#1a1a1a !important; color:#fff !important;
    border:1px solid #1a1a1a !important;
}
.stButton > button[kind="primary"]:hover { background:#333 !important; border-color:#333 !important; }

/* View toggle — radio pill stili */
div[data-testid="stRadio"] { margin-bottom: .5rem; }
div[data-testid="stRadio"] > div {
    display:inline-flex !important; gap:0 !important;
    background:#f0f0f5 !important; border-radius:10px !important;
    padding:3px !important; border:1px solid #e0e0e5 !important;
    flex-wrap:nowrap !important;
}
div[data-testid="stRadio"] > div > label {
    display:flex !important; align-items:center !important;
    padding:5px 16px !important; border-radius:8px !important;
    font-size:.8rem !important; font-weight:600 !important;
    color:#888 !important; cursor:pointer !important;
    transition:all .15s !important; margin:0 !important;
    gap:6px !important;
}
div[data-testid="stRadio"] > div > label:has(input:checked) {
    background:#fff !important; color:#1a1a1a !important;
    box-shadow:0 1px 4px rgba(0,0,0,.1) !important;
}
/* Radio circle gizle */
div[data-testid="stRadio"] > div > label > div:first-child { display:none !important; }
div[data-testid="stRadio"] > div > label input[type="radio"] { display:none !important; }

/* Expanders */
details summary { background:#f8f8fa !important; border-radius:10px !important; padding:.5rem .8rem !important; color:#1a1a1a !important; }
[data-testid="stExpander"] { border:1px solid #e8e8ed !important; border-radius:12px !important; background:#fff !important; overflow:hidden; }

/* Sidebar select kutuları */
section[data-testid="stSidebar"] input { background:#f8f8fa !important; color:#1a1a1a !important; border:1px solid #e4e4e9 !important; border-radius:9px !important; }
section[data-testid="stSidebar"] [data-baseweb="select"] > div:first-child { background:#f8f8fa !important; border:1px solid #e4e4e9 !important; border-radius:9px !important; }
section[data-testid="stSidebar"] [data-baseweb="select"] span { color:#1a1a1a !important; }
section[data-testid="stSidebar"] [data-baseweb="tag"] { background:#e8e8ed !important; border-radius:6px !important; }
section[data-testid="stSidebar"] [data-baseweb="tag"] span { color:#1a1a1a !important; }
section[data-testid="stSidebar"] [data-baseweb="tag"] [role="presentation"] { color:#999 !important; }

/* Dropdown popup — global (portal dışarıda render edilir) */
[data-baseweb="popover"] { background:#fff !important; border:1px solid #e4e4e9 !important; border-radius:12px !important; box-shadow:0 4px 20px rgba(0,0,0,.1) !important; }
[data-baseweb="menu"] { background:#fff !important; border-radius:12px !important; }
[role="listbox"] { background:#fff !important; padding:4px !important; }
[role="option"] { background:#fff !important; border-radius:8px !important; margin:1px 0 !important; }
[role="option"]:hover, [role="option"][aria-selected="true"] { background:#f0f0f5 !important; }
[role="option"] * { color:#1a1a1a !important; font-size:.82rem !important; }
[role="option"][aria-selected="true"] * { font-weight:600 !important; }
/* Checkbox in multiselect */
[data-baseweb="checkbox"] [data-checked="true"] { background:#5460B8 !important; border-color:#5460B8 !important; }
[data-baseweb="checkbox"] { border-color:#dcdce0 !important; }

/* Divider */
.one-divider { height:1px; background:#eaeaef; margin:1.2rem 0; }

/* Day header */
.day-header-row { display:flex; align-items:center; gap:.75rem; margin:2rem 0 .9rem; }
.day-label { font-size:.7rem; font-weight:700; letter-spacing:.12em; color:#bbb; text-transform:uppercase; white-space:nowrap; }
.day-line  { flex:1; height:1px; background:#eaeaef; }
.day-count { font-size:.68rem; color:#ccc; white-space:nowrap; }

/* Detail panel */
.detail-panel { background:#fff; border:1px solid #e0e0e8; border-radius:20px; padding:1.4rem; margin-bottom:1.4rem; box-shadow:0 2px 12px rgba(0,0,0,.07); }

/* Dataframe */
.stDataFrame { border-radius:12px; overflow:hidden; border:1px solid #e8e8ed !important; }
iframe { border-radius:12px; }

div[data-testid="stHorizontalBlock"] { gap:.7rem; }
</style>
""", unsafe_allow_html=True)

# ════════════════════════════════════════════════════════════════
# PATHS & CONSTANTS
# ════════════════════════════════════════════════════════════════
BASE_DIR    = Path(__file__).parent
DATA_FILE   = BASE_DIR / "dailyshare.json"
USERS_FILE  = BASE_DIR / "appusers.json"
FRIENDS_FILE= BASE_DIR / "friendships.json"
CONFIG_FILE = BASE_DIR / ".cloudkit_config.json"

CK_BASE = "https://api.apple-cloudkit.com/database/1/iCloud.com.batu.ones/production/public"

# ════════════════════════════════════════════════════════════════
# HELPERS
# ════════════════════════════════════════════════════════════════
def load_config():
    return json.loads(CONFIG_FILE.read_text()) if CONFIG_FILE.exists() else {}

def save_config(c):
    CONFIG_FILE.write_text(json.dumps(c))

def luminance(h):
    try:
        h = h.lstrip("#")
        r,g,b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
        return .299*r + .587*g + .114*b
    except Exception:
        return 100

def txt_on(hex_color):
    return "#000" if luminance(hex_color) > 155 else "#fff"

def ck_fetch_all(token, record_type, prog_cb=None):
    records, cursor = [], None
    while True:
        body = {"query": {"recordType": record_type}, "resultsLimit": 200}
        if cursor:
            body["continuationMarker"] = cursor
        resp = requests.post(
            f"{CK_BASE}/records/query",
            params={"ckAPIToken": token},
            headers={"Content-Type": "application/json"},
            json=body,
        )
        if resp.status_code != 200:
            return None, resp.json().get("reason", "Bilinmeyen hata")
        data = resp.json()
        batch = data.get("records", [])
        records.extend(batch)
        if prog_cb:
            prog_cb(len(records))
        if data.get("moreComing"):
            cursor = data.get("continuationMarker")
            time.sleep(0.2)
        else:
            break
    return records, None

def flatten_records(records):
    flat = []
    for r in records:
        row = {
            "_recordName": r.get("recordName"),
            "_createdAt":  r.get("created", {}).get("timestamp"),
            "_modifiedAt": r.get("modified", {}).get("timestamp"),
        }
        for k, v in r.get("fields", {}).items():
            row[k] = v.get("value")
        flat.append(row)
    return flat

# ════════════════════════════════════════════════════════════════
# FETCH
# ════════════════════════════════════════════════════════════════
def do_refresh(token):
    prog = st.progress(0, text="Veriler yükleniyor...")

    prog.progress(0.1, text="👥 Kullanıcılar çekiliyor…")
    users_raw, err = ck_fetch_all(token, "AppUser")
    if err:
        st.error(f"AppUser hatası: {err}"); prog.empty(); return False

    prog.progress(0.4, text="📋 Paylaşımlar çekiliyor…")
    shares_raw, err = ck_fetch_all(token, "DailyShare")
    if err:
        st.error(f"DailyShare hatası: {err}"); prog.empty(); return False

    prog.progress(0.75, text="🤝 Arkadaşlıklar çekiliyor…")
    friends_raw, err = ck_fetch_all(token, "Friendship")
    if err:
        friends_raw = []

    prog.progress(0.95, text="💾 Kaydediliyor…")
    USERS_FILE.write_text(json.dumps(flatten_records(users_raw),   ensure_ascii=False, indent=2, default=str))
    DATA_FILE.write_text( json.dumps(flatten_records(shares_raw),  ensure_ascii=False, indent=2, default=str))
    FRIENDS_FILE.write_text(json.dumps(flatten_records(friends_raw or []), ensure_ascii=False, indent=2, default=str))

    prog.progress(1.0, text=f"✓ {len(users_raw)} kullanıcı · {len(shares_raw)} paylaşım · {len(friends_raw or [])} arkadaşlık")
    time.sleep(0.8); prog.empty()
    return True

# ════════════════════════════════════════════════════════════════
# LOAD
# ════════════════════════════════════════════════════════════════
@st.cache_data(ttl=300)
def load_user_map():
    if not USERS_FILE.exists():
        return {}
    users = json.loads(USERS_FILE.read_text())
    mapping = {}
    for u in users:
        uid = u.get("userID") or ""
        mapping[uid] = {
            "displayName": u.get("displayName") or u.get("username") or uid[-8:],
            "username":    u.get("username") or "",
            "avatarColor": u.get("avatarColor") or "#444",
            "inviteCode":  u.get("inviteCode") or "",
            "isPublic":    u.get("isPublic", 0),
            "createdDate": u.get("createdDate"),
        }
    return mapping

@st.cache_data(ttl=300)
def load_df():
    if not DATA_FILE.exists():
        return pd.DataFrame()
    records = json.loads(DATA_FILE.read_text())
    df = pd.DataFrame(records)
    for col in ["date", "createdAt", "_createdAt"]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    ts_col = "date" if "date" in df.columns else "_createdAt"
    if ts_col in df.columns:
        # UTC → Türkiye saati (UTC+3) dönüşümü
        df["_dt"] = (
            pd.to_datetime(df[ts_col], unit="ms", errors="coerce", utc=True)
              .dt.tz_convert("Europe/Istanbul")
              .dt.tz_localize(None)           # naive'e çevir (strftime uyumluluğu)
        )
        df["_date_str"] = df["_dt"].dt.strftime("%Y-%m-%d")
        # Gerçek paylaşım saatini _createdAt'ten al (UTC+3)
        if "_createdAt" in df.columns:
            df["_time_str"] = (
                pd.to_datetime(df["_createdAt"], unit="ms", errors="coerce", utc=True)
                  .dt.tz_convert("Europe/Istanbul")
                  .dt.strftime("%H:%M")
            )
        else:
            df["_time_str"] = df["_dt"].dt.strftime("%H:%M")
        df["_month"]    = df["_dt"].dt.to_period("M").astype(str)
        df["_week"]     = df["_dt"].dt.to_period("W").astype(str)
        df["_weekday"]  = df["_dt"].dt.day_name()

    # Aynı kullanıcının aynı günkü duplicate kayıtlarını temizle
    # (DailyShare + friend paylaşımı kopyası) — en erken _createdAt'i tut
    if "userID" in df.columns and "_date_str" in df.columns and "_createdAt" in df.columns:
        before = len(df)
        df = (
            df.sort_values("_createdAt")
              .drop_duplicates(subset=["userID", "_date_str"], keep="first")
              .reset_index(drop=True)
        )
        after = len(df)
        if before != after:
            print(f"[dedup] {before - after} duplicate kayıt temizlendi ({before} → {after})")

    return df

@st.cache_data(ttl=300)
def load_friends_df():
    if not FRIENDS_FILE.exists():
        return pd.DataFrame()
    return pd.DataFrame(json.loads(FRIENDS_FILE.read_text()))

# ════════════════════════════════════════════════════════════════
# SIDEBAR
# ════════════════════════════════════════════════════════════════
cfg   = load_config()
token = cfg.get("token", "")

with st.sidebar:
    st.markdown("## 🎵 ONE")
    st.markdown('<div style="height:1px;background:#e8e8ed;margin:.5rem 0 1rem 0"></div>', unsafe_allow_html=True)

    if not token:
        st.warning("Token girilmemiş.")
        nt = st.text_input("CloudKit API Token", type="password")
        if st.button("Kaydet", use_container_width=True, type="primary"):
            cfg["token"] = nt; save_config(cfg); st.rerun()
        st.stop()

    # Status + yenile
    mtime_str = ""
    if DATA_FILE.exists():
        mtime = datetime.fromtimestamp(DATA_FILE.stat().st_mtime)
        mtime_str = mtime.strftime("%d %b, %H:%M")

    st.markdown(
        f'<div style="background:#f5f5f7;border:1px solid #eaeaef;border-radius:12px;padding:.6rem .9rem;margin-bottom:.5rem">'
        f'  <div style="display:flex;align-items:center;justify-content:space-between">'
        f'    <span style="font-size:.78rem;font-weight:700;color:#1a1a1a">● Bağlı</span>'
        f'    <span style="font-size:.68rem;color:#bbb">{mtime_str}</span>'
        f'  </div>'
        f'</div>',
        unsafe_allow_html=True
    )
    if st.button("🔄 Verileri Yenile", use_container_width=True):
        ok = do_refresh(token)
        if ok:
            st.cache_data.clear(); st.rerun()

    st.markdown('<div style="height:1px;background:#eaeaef;margin:.9rem 0 .7rem 0"></div>', unsafe_allow_html=True)

    user_map = load_user_map()
    df_all   = load_df()

    if df_all.empty:
        st.info("Veri yok — ↺ ile yenile."); st.stop()

    # ── Filtreler ──
    st.markdown('<span style="font-size:.68rem;font-weight:700;color:#bbb;letter-spacing:.1em;text-transform:uppercase">Filtreler</span>', unsafe_allow_html=True)

    all_uids = sorted(
        df_all["userID"].dropna().unique().tolist() if "userID" in df_all.columns else [],
        key=lambda u: user_map.get(u, {}).get("displayName", "").lower()
    )
    sel_users = st.multiselect(
        "Kullanıcı",
        options=all_uids,
        format_func=lambda u: f"{user_map.get(u,{}).get('displayName', u[-6:])}  @{user_map.get(u,{}).get('username','')}",
    )

    if "_date_str" in df_all.columns:
        valid_dates = pd.to_datetime(df_all["_date_str"].dropna()).sort_values()
        min_d, max_d = valid_dates.min().date(), valid_dates.max().date()
        date_rng = st.date_input("Tarih aralığı", value=(min_d, max_d), min_value=min_d, max_value=max_d)
    else:
        date_rng = None

    mood_opts = sorted(df_all["moodColor"].dropna().unique()) if "moodColor" in df_all.columns else []
    sel_moods = st.multiselect("Mood rengi", options=mood_opts,
                               format_func=lambda c: f"● {c}")

    platform_opts = sorted(df_all["platform"].dropna().unique()) if "platform" in df_all.columns else []
    sel_platform  = st.multiselect("Platform", options=platform_opts)

    st.markdown('<div style="height:1px;background:#e8e8ed;margin:.75rem 0"></div>', unsafe_allow_html=True)

    with st.expander("Token değiştir"):
        nt2 = st.text_input("Yeni token", type="password", key="nt2")
        if st.button("Kaydet ", key="save_tok"):
            cfg["token"] = nt2; save_config(cfg); st.rerun()

    st.markdown('<div style="margin-top:1rem;font-size:.7rem;color:#333;text-align:center">Hisset · Keşfet · Paylaş</div>',
                unsafe_allow_html=True)

# ════════════════════════════════════════════════════════════════
# APPLY FILTERS
# ════════════════════════════════════════════════════════════════
df = df_all.copy()
if sel_users:
    df = df[df["userID"].isin(sel_users)]
if date_rng and len(date_rng) == 2:
    s, e = pd.Timestamp(date_rng[0]), pd.Timestamp(date_rng[1])
    df = df[
        (pd.to_datetime(df["_date_str"], errors="coerce") >= s) &
        (pd.to_datetime(df["_date_str"], errors="coerce") <= e)
    ]
if sel_moods:
    df = df[df["moodColor"].isin(sel_moods)]
if sel_platform:
    df = df[df["platform"].isin(sel_platform)]

df = df.sort_values("_createdAt" if "_createdAt" in df.columns else "date", ascending=False)

friends_df = load_friends_df()

# ════════════════════════════════════════════════════════════════
# TABS
# ════════════════════════════════════════════════════════════════
tab_feed, tab_users, tab_analytics, tab_friends = st.tabs([
    "📋  Feed", "👥  Kullanıcılar", "📊  Analitik", "🤝  Bağlantılar"
])

# ────────────────────────────────────────────────────────────────
# TAB 1: FEED
# ────────────────────────────────────────────────────────────────
with tab_feed:
    # Metrikler
    c1,c2,c3,c4,c5 = st.columns(5)
    c1.metric("Paylaşım",   len(df))
    c2.metric("Kullanıcı",  df["userID"].nunique()   if "userID"    in df.columns else "—")
    c3.metric("Gün",        df["_date_str"].nunique() if "_date_str" in df.columns else "—")
    c4.metric("Şarkı",      df["songName"].nunique()  if "songName"  in df.columns else "—")
    c5.metric("Ort. Streak",
              f'{df["currentStreak"].dropna().astype(float).mean():.1f}'
              if "currentStreak" in df.columns else "—")

    if df.empty:
        st.info("Filtre sonucu boş."); st.stop()

    dates_avail = sorted(df["_date_str"].dropna().unique(), reverse=True) if "_date_str" in df.columns else []

    st.markdown('<div class="one-divider"></div>', unsafe_allow_html=True)

    # View toggle — radio styled as pill
    view = st.radio("Görünüm", ["☰ Kompakt", "🖼 Detaylı"],
                    horizontal=True, label_visibility="collapsed",
                    key="view_toggle")
    show_photos = (view == "🖼 Detaylı")

    st.markdown('<div style="height:.6rem"></div>', unsafe_allow_html=True)

    # ── Detail overlay (session state) ──
    if "detail_idx" not in st.session_state:
        st.session_state.detail_idx = None

    if st.session_state.detail_idx is not None:
        match = df[df["_recordName"] == st.session_state.detail_idx] if "_recordName" in df.columns else pd.DataFrame()
        row   = match.iloc[0] if not match.empty else None
        if row is None:
            st.session_state.detail_idx = None
        else:
            uid   = row.get("userID") or ""
            info  = user_map.get(uid, {})
            dname = info.get("displayName", uid[-8:])
            uname = info.get("username", "")
            color = info.get("avatarColor", "#444")
            init  = dname[0].upper()

            with st.container():
                st.markdown(f"""
                <div style="background:#fff;border:1px solid #e0e0e8;border-radius:20px;padding:1.5rem;margin-bottom:1.5rem">
                  <div style="display:flex;align-items:center;gap:1rem;margin-bottom:1.2rem">
                    <div class="avatar" style="width:52px;height:52px;font-size:1.2rem;background:{color}">{init}</div>
                    <div>
                      <div style="font-size:1.1rem;font-weight:800;color:#1a1a1a">{dname}</div>
                      <div style="font-size:.8rem;color:#555">@{uname} · {row.get('_date_str','')} {row.get('_time_str','')}</div>
                    </div>
                    <div style="margin-left:auto;font-size:1.3rem">{row.get('weatherIcon','')}</div>
                  </div>
                </div>
                """, unsafe_allow_html=True)

                dc1, dc2 = st.columns([1,1])
                with dc1:
                    photo_url = ""
                    photo_raw = row.get("photoAsset")
                    if isinstance(photo_raw, dict):
                        photo_url = photo_raw.get("downloadURL","")
                    if photo_url:
                        st.image(photo_url, use_container_width=True, caption="Günlük fotoğraf")
                    else:
                        st.info("Bu paylaşımda fotoğraf yok.")

                with dc2:
                    art_url = row.get("albumArtURL","")
                    if art_url:
                        st.image(art_url, width=120)
                    song   = row.get("songName","—")
                    artist = row.get("artistName","")
                    genre  = row.get("genre","")
                    platform = row.get("platform","")
                    st.markdown(f"### {row.get('emoji','🎵')} {song}")
                    st.markdown(f"**{artist}**")
                    if genre:   st.caption(f"🎸 {genre}")
                    if platform: st.caption(f"📱 {platform}")

                    st.markdown("---")
                    mood_hex = row.get("moodColor","#444")
                    mood_w   = row.get("moodWord","")
                    mood_l   = row.get("feelingLabel","")
                    st.markdown(
                        f'<span style="background:{mood_hex};color:{txt_on(mood_hex)};'
                        f'padding:5px 14px;border-radius:20px;font-weight:700;font-size:.85rem">'
                        f'{mood_w}</span>  <span style="color:#666;font-size:.85rem">{mood_l}</span>',
                        unsafe_allow_html=True
                    )
                    note = (row.get("dailyNote") or "").strip()
                    if note:
                        st.markdown(f'<div style="margin-top:.8rem;color:#888;font-style:italic">"{note}"</div>',
                                    unsafe_allow_html=True)

                    streak = row.get("currentStreak")
                    weather_icon = row.get("weatherIcon","")
                    cols_meta = st.columns(3)
                    try:
                        streak_int = int(float(streak)) if streak is not None and str(streak) not in ("", "nan") else None
                    except (ValueError, TypeError):
                        streak_int = None
                    if streak_int:
                        cols_meta[0].metric("Streak", f"🔥 {streak_int} gün")
                    cols_meta[1].metric("Platform", platform or "—")
                    if weather_icon:
                        cols_meta[2].metric("Hava", weather_icon)

                if st.button("✕ Kapat", key="close_detail"):
                    st.session_state.detail_idx = None
                    st.rerun()

            st.markdown('<div style="height:1px;background:#e8e8ed;margin:1rem 0 1.5rem 0"></div>', unsafe_allow_html=True)

    # ── Gün gün feed ──
    for day in dates_avail:
        day_df = df[df["_date_str"] == day]
        try:
            day_label = datetime.strptime(day, "%Y-%m-%d").strftime("%-d %B %Y, %A")
        except Exception:
            day_label = day

        # Gün başlığı + mini avatar şeridi
        active_in_day = day_df["userID"].dropna().unique() if "userID" in day_df.columns else []
        avatars_html  = ""
        for uid in list(active_in_day)[:8]:
            info  = user_map.get(uid,{})
            color = info.get("avatarColor","#444")
            init  = (info.get("displayName","?")[0]).upper()
            avatars_html += (
                f'<div title="{info.get("displayName","")} @{info.get("username","")}" '
                f'class="avatar" style="width:26px;height:26px;font-size:.65rem;'
                f'background:{color};display:inline-flex;margin-right:4px">{init}</div>'
            )

        st.markdown(
            f'<div class="day-header-row">'
            f'  <span class="day-label">{day_label}</span>'
            f'  <div style="display:flex;align-items:center;gap:3px">{avatars_html}</div>'
            f'  <div class="day-line"></div>'
            f'  <span class="day-count">{len(day_df)} giriş</span>'
            f'</div>',
            unsafe_allow_html=True
        )

        cols = st.columns(3, gap="small")

        for ci, (df_idx, row) in enumerate(day_df.iterrows()):
            uid   = row.get("userID") or ""
            info  = user_map.get(uid,{})
            dname = info.get("displayName", uid[-8:])
            uname = info.get("username","")
            color = info.get("avatarColor","#444")
            init  = dname[0].upper() if dname else "?"

            song      = row.get("songName","—")
            artist    = row.get("artistName","")
            genre     = row.get("genre","")
            mood_hex  = row.get("moodColor","#333")
            mood_w    = row.get("moodWord","")
            note      = (row.get("dailyNote") or "").strip()
            emoji_s   = row.get("emoji","🎵")
            streak    = row.get("currentStreak")
            platform  = row.get("platform","")
            art_url   = row.get("albumArtURL","")
            weather   = row.get("weatherIcon","")
            time_s    = row.get("_time_str","")

            photo_url = ""
            photo_raw = row.get("photoAsset")
            if isinstance(photo_raw, dict):
                photo_url = photo_raw.get("downloadURL","")

            mood_bg  = mood_hex + "18"
            mood_txt = txt_on(mood_hex)

            with cols[ci % 3]:
                st.markdown('<div class="one-card">', unsafe_allow_html=True)

                # Header
                st.markdown(
                    f'<div class="card-top">'
                    f'  <div class="avatar" style="background:{color}">{init}</div>'
                    f'  <div style="flex:1;min-width:0">'
                    f'    <div class="dname">{dname}</div>'
                    f'    <div class="uname">@{uname}</div>'
                    f'  </div>'
                    f'  <div class="ts">{weather} {time_s}</div>'
                    f'</div>',
                    unsafe_allow_html=True
                )

                # Photo (detaylı modda hep göster, kompaktta gizle)
                if photo_url and show_photos:
                    try:
                        st.image(photo_url, use_container_width=True)
                    except Exception:
                        pass

                # Song
                art_tag = (f'<img src="{art_url}" class="art"/>' if art_url
                           else f'<div class="art-ph">🎵</div>')
                st.markdown(
                    f'<div class="song-row">'
                    f'  {art_tag}'
                    f'  <div style="flex:1;min-width:0">'
                    f'    <div class="sname">{emoji_s} {song}</div>'
                    f'    <div class="aname">{artist}</div>'
                    f'    <div class="genre-tag">{genre}</div>'
                    f'  </div>'
                    f'</div>',
                    unsafe_allow_html=True
                )

                # Note
                if note:
                    st.markdown(f'<div class="note">"{note}"</div>', unsafe_allow_html=True)

                # Footer: mood + pills
                try:
                    streak_val  = int(float(streak)) if streak is not None and str(streak) not in ("", "nan") else None
                except (ValueError, TypeError):
                    streak_val  = None
                streak_pill = (f'<span class="pill">🔥 {streak_val}</span>' if streak_val else "")
                plat_pill   = (f'<span class="pill">{platform}</span>' if platform else "")
                st.markdown(
                    f'<div class="card-foot">'
                    f'  <span class="mood-pill" style="background:{mood_bg};color:{mood_hex};border:1px solid {mood_hex}40">'
                    f'    <span class="mdot" style="background:{mood_hex}"></span>{mood_w}'
                    f'  </span>'
                    f'  {streak_pill}{plat_pill}'
                    f'</div>',
                    unsafe_allow_html=True
                )

                # Detay butonu — key olarak df index kullan (her zaman unique)
                rec_name = row.get("_recordName") or str(df_idx)
                btn_key  = f"det_{day}_{df_idx}"
                if st.button("Detay →", key=btn_key):
                    st.session_state.detail_idx = rec_name
                    st.rerun()

                st.markdown('</div>', unsafe_allow_html=True)

# ────────────────────────────────────────────────────────────────
# TAB 2: KULLANICILAR
# ────────────────────────────────────────────────────────────────
with tab_users:
    st.markdown("### 👥 Kullanıcı Profilleri")

    if not user_map:
        st.info("Kullanıcı verisi yok — yenile.")
        st.stop()

    # Kullanıcı başına istatistik
    user_stats = {}
    if not df_all.empty and "userID" in df_all.columns:
        for uid, grp in df_all.groupby("userID"):
            streaks = grp["currentStreak"].dropna().astype(float) if "currentStreak" in grp.columns else pd.Series([])
            moods   = grp["moodColor"].dropna().value_counts()
            songs   = grp["songName"].dropna().value_counts()
            user_stats[uid] = {
                "total":       len(grp),
                "max_streak":  int(streaks.max()) if len(streaks) else 0,
                "top_mood":    moods.index[0] if len(moods) else "—",
                "top_song":    songs.index[0] if len(songs) else "—",
                "last_date":   grp["_date_str"].max() if "_date_str" in grp.columns else "—",
                "top_artist":  grp["artistName"].dropna().value_counts().index[0] if "artistName" in grp.columns and len(grp["artistName"].dropna()) else "—",
            }

    sorted_uids = sorted(user_map.keys(),
                         key=lambda u: user_stats.get(u, {}).get("total", 0), reverse=True)

    ucols = st.columns(3, gap="medium")
    for ui, uid in enumerate(sorted_uids):
        info  = user_map[uid]
        dname = info.get("displayName","?")
        uname = info.get("username","")
        color = info.get("avatarColor","#444")
        init  = dname[0].upper() if dname else "?"
        code  = info.get("inviteCode","")
        stats = user_stats.get(uid, {})

        top_mood_hex = stats.get("top_mood","#444")
        mood_lbl     = df_all[df_all["moodColor"] == top_mood_hex]["moodWord"].dropna().mode()
        mood_lbl     = mood_lbl.iloc[0] if len(mood_lbl) else top_mood_hex

        with ucols[ui % 3]:
            st.markdown(
                f'<div class="user-profile-card">'
                f'  <div class="up-header">'
                f'    <div class="up-avatar" style="background:{color}">{init}</div>'
                f'    <div>'
                f'      <div class="up-name">{dname}</div>'
                f'      <div class="up-user">@{uname}</div>'
                f'    </div>'
                f'    <div style="margin-left:auto;font-size:.7rem;color:#2e2e2e">#{code}</div>'
                f'  </div>'
                f'  <div class="stat-row">'
                f'    <div class="stat-chip"><span class="stat-val">{stats.get("total",0)}</span>paylaşım</div>'
                f'    <div class="stat-chip"><span class="stat-val">🔥{stats.get("max_streak",0)}</span>max streak</div>'
                f'    <div class="stat-chip"><span class="stat-val" style="font-size:.75rem">{mood_lbl}</span>en sık mood</div>'
                f'    <div class="stat-chip"><span class="stat-val" style="font-size:.65rem">{str(stats.get("top_artist","—"))[:14]}</span>en sık sanatçı</div>'
                f'  </div>'
                f'  <div style="margin-top:.6rem;font-size:.7rem;color:#333">Son: {stats.get("last_date","—")}</div>'
                f'</div>',
                unsafe_allow_html=True
            )

            # Bu kullanıcının son 3 paylaşımı
            with st.expander("Son paylaşımlar"):
                u_df = df_all[df_all["userID"] == uid].sort_values(
                    "_createdAt" if "_createdAt" in df_all.columns else "date", ascending=False
                ).head(3)
                for _, row in u_df.iterrows():
                    photo_url = ""
                    photo_raw = row.get("photoAsset")
                    if isinstance(photo_raw, dict):
                        photo_url = photo_raw.get("downloadURL","")

                    col_img, col_txt = st.columns([1,2])
                    with col_img:
                        if photo_url:
                            try: st.image(photo_url, use_container_width=True)
                            except: pass
                        elif row.get("albumArtURL"):
                            try: st.image(row["albumArtURL"], use_container_width=True)
                            except: pass
                    with col_txt:
                        mh = row.get("moodColor","#444")
                        st.markdown(
                            f'<div style="font-size:.82rem;font-weight:700;color:#ddd">'
                            f'{row.get("emoji","🎵")} {row.get("songName","—")}</div>'
                            f'<div style="font-size:.72rem;color:#666">{row.get("artistName","")}</div>'
                            f'<div style="margin-top:4px">'
                            f'<span style="background:{mh}22;color:{mh};border:1px solid {mh}40;'
                            f'padding:2px 8px;border-radius:12px;font-size:.68rem;font-weight:700">'
                            f'{row.get("moodWord","")}</span></div>'
                            f'<div style="font-size:.68rem;color:#333;margin-top:3px">{row.get("_date_str","")}</div>',
                            unsafe_allow_html=True
                        )
                    st.markdown('<div style="height:1px;background:#e8e8ed;margin:.5rem 0"></div>', unsafe_allow_html=True)

# ────────────────────────────────────────────────────────────────
# TAB 3: ANALİTİK
# ────────────────────────────────────────────────────────────────
with tab_analytics:
    st.markdown("### 📊 Analitik")

    if df.empty:
        st.info("Veri yok."); st.stop()

    # ── Genel metrikler ──
    a1,a2,a3,a4 = st.columns(4)
    a1.metric("Toplam Paylaşım",  len(df_all))
    a2.metric("Aktif Kullanıcı",  df_all["userID"].nunique() if "userID" in df_all.columns else "—")
    a3.metric("En Yüksek Streak",
              int(df_all["currentStreak"].dropna().astype(float).max())
              if "currentStreak" in df_all.columns else "—")
    a4.metric("Fotoğraflı Paylaşım",
              df_all["photoAsset"].dropna().apply(lambda x: bool(x) if x else False).sum()
              if "photoAsset" in df_all.columns else "—")

    st.markdown('<div style="height:1px;background:#e8e8ed;margin:1.5rem 0"></div>', unsafe_allow_html=True)

    left_col, right_col = st.columns(2, gap="large")

    with left_col:
        # Günlük aktivite
        st.markdown("**Günlük Aktivite**")
        if "_date_str" in df.columns:
            daily = df.groupby("_date_str").size().reset_index(name="Paylaşım")
            daily["_date_str"] = pd.to_datetime(daily["_date_str"])
            st.area_chart(daily.set_index("_date_str"), color="#5460B8")

        # Haftanın günleri
        st.markdown("**Haftanın Günlerine Göre**")
        if "_weekday" in df.columns:
            order = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
            tr    = {"Monday":"Pazartesi","Tuesday":"Salı","Wednesday":"Çarşamba",
                     "Thursday":"Perşembe","Friday":"Cuma","Saturday":"Cumartesi","Sunday":"Pazar"}
            wd = df["_weekday"].value_counts().reindex(order, fill_value=0).rename(index=tr)
            st.bar_chart(wd)

    with right_col:
        # Mood dağılımı
        st.markdown("**Mood Rengi Dağılımı**")
        if "moodColor" in df.columns:
            mood_counts = df.groupby("moodColor").agg(
                count=("moodColor","count"),
                label=("moodWord", lambda x: x.mode().iloc[0] if len(x.mode()) else "")
            ).sort_values("count", ascending=False)

            for mhex, mrow in mood_counts.iterrows():
                pct = mrow["count"] / len(df) * 100
                bar_w = int(pct)
                st.markdown(
                    f'<div style="display:flex;align-items:center;gap:.6rem;margin-bottom:.35rem">'
                    f'  <div style="width:12px;height:12px;border-radius:50%;background:{mhex};flex-shrink:0"></div>'
                    f'  <div style="width:90px;font-size:.75rem;color:#888;overflow:hidden;white-space:nowrap">{mrow["label"]}</div>'
                    f'  <div style="flex:1;background:#e0e0e8;border-radius:4px;height:8px;overflow:hidden">'
                    f'    <div style="width:{bar_w}%;background:{mhex};height:100%;border-radius:4px"></div>'
                    f'  </div>'
                    f'  <div style="font-size:.72rem;color:#555;width:30px;text-align:right">{mrow["count"]}</div>'
                    f'</div>',
                    unsafe_allow_html=True
                )

        st.markdown('<div style="height:1rem"></div>', unsafe_allow_html=True)

        # Aylık trend
        st.markdown("**Aylık Trend**")
        if "_month" in df.columns:
            monthly = df.groupby("_month").size().reset_index(name="Paylaşım")
            st.bar_chart(monthly.set_index("_month"))

    st.markdown('<div style="height:1px;background:#e8e8ed;margin:1.5rem 0"></div>', unsafe_allow_html=True)

    bot_l, bot_m, bot_r = st.columns(3, gap="large")

    with bot_l:
        # Streak liderboard
        st.markdown("**🔥 Streak Sıralaması**")
        if "currentStreak" in df_all.columns and "userID" in df_all.columns:
            streak_lb = (
                df_all.groupby("userID")["currentStreak"]
                .apply(lambda x: x.dropna().astype(float).max())
                .sort_values(ascending=False)
                .head(10)
                .reset_index()
            )
            streak_lb.columns = ["userID","max_streak"]
            for i, row in streak_lb.iterrows():
                info  = user_map.get(row["userID"],{})
                dname = info.get("displayName", row["userID"][-8:])
                color = info.get("avatarColor","#444")
                init  = dname[0].upper()
                rank_colors = {0:"#F5C842",1:"#C0C0C0",2:"#CD7F32"}
                rank_c = rank_colors.get(i,"#333")
                st.markdown(
                    f'<div class="leaderboard-row">'
                    f'  <div class="lb-rank" style="color:{rank_c}">#{i+1}</div>'
                    f'  <div class="avatar" style="width:28px;height:28px;font-size:.7rem;background:{color}">{init}</div>'
                    f'  <div class="lb-name">{dname}</div>'
                    f'  <div class="lb-val">🔥 {int(row["max_streak"])}</div>'
                    f'</div>',
                    unsafe_allow_html=True
                )

    with bot_m:
        # En çok paylaşan
        st.markdown("**📋 En Aktif Kullanıcılar**")
        if "userID" in df_all.columns:
            top_users = df_all["userID"].value_counts().head(10)
            for i, (uid, cnt) in enumerate(top_users.items()):
                info  = user_map.get(uid,{})
                dname = info.get("displayName", uid[-8:])
                color = info.get("avatarColor","#444")
                init  = dname[0].upper()
                st.markdown(
                    f'<div class="leaderboard-row">'
                    f'  <div class="lb-rank">#{i+1}</div>'
                    f'  <div class="avatar" style="width:28px;height:28px;font-size:.7rem;background:{color}">{init}</div>'
                    f'  <div class="lb-name">{dname}</div>'
                    f'  <div class="lb-val">{cnt} paylaşım</div>'
                    f'</div>',
                    unsafe_allow_html=True
                )

    with bot_r:
        # En çok dinlenen şarkılar
        st.markdown("**🎵 En Çok Paylaşılan Şarkılar**")
        if "songName" in df.columns:
            top_songs = (
                df.groupby(["songName","artistName"]).size()
                .sort_values(ascending=False).head(10).reset_index()
            )
            top_songs.columns = ["Şarkı","Sanatçı","Sayı"]
            for i, row in top_songs.iterrows():
                st.markdown(
                    f'<div class="leaderboard-row">'
                    f'  <div class="lb-rank">#{i+1}</div>'
                    f'  <div style="flex:1;min-width:0">'
                    f'    <div style="font-size:.8rem;font-weight:600;color:#1a1a1a;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{row["Şarkı"]}</div>'
                    f'    <div style="font-size:.7rem;color:#555">{row["Sanatçı"]}</div>'
                    f'  </div>'
                    f'  <div class="lb-val">{row["Sayı"]}x</div>'
                    f'</div>',
                    unsafe_allow_html=True
                )

    # Platform & Genre
    st.markdown('<div style="height:1px;background:#e8e8ed;margin:1.5rem 0"></div>', unsafe_allow_html=True)
    pg1, pg2 = st.columns(2, gap="large")

    with pg1:
        st.markdown("**📱 Platform Dağılımı**")
        if "platform" in df.columns:
            plat = df["platform"].value_counts()
            st.bar_chart(plat)

    with pg2:
        st.markdown("**🎸 En Popüler Türler**")
        if "genre" in df.columns:
            genre_counts = df["genre"].dropna().value_counts().head(10)
            for g, cnt in genre_counts.items():
                pct = cnt / len(df) * 100
                st.markdown(
                    f'<div style="display:flex;align-items:center;gap:.6rem;margin-bottom:.3rem">'
                    f'  <div style="flex:1;font-size:.78rem;color:#888;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{g}</div>'
                    f'  <div style="width:100px;background:#e0e0e8;border-radius:4px;height:7px">'
                    f'    <div style="width:{int(pct)}%;background:#5460B8;height:100%;border-radius:4px"></div>'
                    f'  </div>'
                    f'  <div style="font-size:.72rem;color:#555;width:25px;text-align:right">{cnt}</div>'
                    f'</div>',
                    unsafe_allow_html=True
                )

# ────────────────────────────────────────────────────────────────
# TAB 4: BAĞLANTILAR
# ────────────────────────────────────────────────────────────────
with tab_friends:
    st.markdown("### 🤝 Arkadaşlık Ağı")

    if friends_df.empty:
        st.info("Arkadaşlık verisi yok — yenile.")
    else:
        # Metrikler
        f1,f2,f3,f4 = st.columns(4)
        accepted = friends_df[friends_df["status"]=="accepted"] if "status" in friends_df.columns else pd.DataFrame()
        pending  = friends_df[friends_df["status"]=="pending"]  if "status" in friends_df.columns else pd.DataFrame()
        removed  = friends_df[friends_df["status"]=="removed"]  if "status" in friends_df.columns else pd.DataFrame()

        f1.metric("Toplam",   len(friends_df))
        f2.metric("✅ Kabul",  len(accepted))
        f3.metric("⏳ Bekleyen", len(pending))
        f4.metric("❌ Kaldırılan", len(removed))

        st.markdown('<div style="height:1px;background:#e8e8ed;margin:1rem 0"></div>', unsafe_allow_html=True)

        # En bağlı kullanıcılar
        if "user1ID" in friends_df.columns and "user2ID" in friends_df.columns:
            acc = accepted.copy() if len(accepted) else pd.DataFrame(columns=["user1ID","user2ID"])
            all_ids = pd.concat([acc["user1ID"], acc["user2ID"]]).value_counts().head(10)

            st.markdown("**🏆 En Çok Arkadaşı Olan Kullanıcılar**")
            fr_cols = st.columns(2, gap="large")
            for i, (uid, cnt) in enumerate(all_ids.items()):
                info  = user_map.get(uid,{})
                dname = info.get("displayName", str(uid)[-8:])
                color = info.get("avatarColor","#444")
                init  = dname[0].upper() if dname else "?"
                with fr_cols[i % 2]:
                    st.markdown(
                        f'<div class="leaderboard-row">'
                        f'  <div class="lb-rank">#{i+1}</div>'
                        f'  <div class="avatar" style="width:30px;height:30px;font-size:.75rem;background:{color}">{init}</div>'
                        f'  <div class="lb-name">{dname} <span style="color:#444;font-size:.7rem">@{info.get("username","")}</span></div>'
                        f'  <div class="lb-val">{cnt} bağlantı</div>'
                        f'</div>',
                        unsafe_allow_html=True
                    )

        st.markdown('<div style="height:1px;background:#e8e8ed;margin:1.2rem 0"></div>', unsafe_allow_html=True)

        # Arkadaşlık tablosu
        st.markdown("**Tüm Arkadaşlıklar**")
        status_filter = st.selectbox("Durum filtresi", ["Tümü","accepted","pending","removed"])

        show_df = friends_df.copy()
        if status_filter != "Tümü":
            show_df = show_df[show_df["status"] == status_filter]

        def uid_to_name(uid):
            if not uid:
                return str(uid)
            info = user_map.get(str(uid),{})
            return f"{info.get('displayName',str(uid)[-8:])} (@{info.get('username','')})"

        if "user1ID" in show_df.columns and "user2ID" in show_df.columns:
            show_df = show_df.copy()
            show_df["Kullanıcı 1"] = show_df["user1ID"].apply(uid_to_name)
            show_df["Kullanıcı 2"] = show_df["user2ID"].apply(uid_to_name)
            show_df["Durum"]       = show_df["status"].map(
                {"accepted":"✅ Kabul","pending":"⏳ Bekleyen","removed":"❌ Kaldırıldı"}
            )
            st.dataframe(
                show_df[["Kullanıcı 1","Kullanıcı 2","Durum"]],
                use_container_width=True, height=350
            )
