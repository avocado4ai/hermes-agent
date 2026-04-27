# מדריך הפעלה וקונפיגורציה — Hermes Agent

## מה זה Hermes Agent?

סוכן AI עצמאי עם מערכת למידה — יוצר skills מניסיון, שומר זיכרון בין שיחות, ותומך בממשקים מרובים (Telegram, Discord, Slack, CLI).
הפרויקט פורק מ-[avocado4ai/hermes-agent](https://github.com/avocado4ai/hermes-agent).

---

## הפעלה מהירה

```bash
cd /Users/yaronel/ai-tools/hermes-agent
./run.sh          # שולח הודעת Telegram + פותח CLI אינטראקטיבי
./stop.sh         # עוצר ומוחק containers
```

---

## מבנה הקבצים

```
hermes-agent/
├── Dockerfile              # הגדרת image (upstream)
├── docker-compose.yml      # הגדרות container — provider, model, volume
├── .env                    # מפתחות API
├── run.sh                  # הפעלה + שליחת Telegram
├── stop.sh                 # עצירה
├── SETUP.md                # תיעוד אנגלית
└── GUIDE-HE.md             # המדריך הזה
```

---

## הגדרות נוכחיות

| פרמטר | ערך |
|-------|-----|
| LLM Provider | Ollama (מקומי על host) |
| מודל ברירת מחדל | `gemma4:e4b` |
| Fallback LLM | Gemini (מפתח `GOOGLE_API_KEY` ב-`.env`) |
| נפח נתונים | `hermes-agent_hermes-data` (Docker named volume) |
| Telegram Bot | `nanoMacClaw_bot` → יארון (`217441497`) |

---

## פקודות שימושיות ב-CLI

לאחר `./run.sh` תיכנס לממשק אינטראקטיבי. אפשר גם להריץ ישירות:

```bash
./run.sh doctor         # בדיקת תקינות מלאה
./run.sh model          # החלפת מודל LLM
./run.sh setup          # אשף הגדרות מלא
./run.sh skills         # ניהול skills
./run.sh skills list    # רשימת כל ה-skills המותקנות (79 built-in)
./run.sh memory         # ניהול זיכרון
./run.sh sessions       # היסטוריית שיחות
./run.sh cron           # ניהול משימות מתוזמנות
./run.sh gateway        # הפעלת Telegram / Discord / Slack
```

---

## שינוי מודל LLM

### אפשרות א — דרך CLI (הכי פשוט)
```bash
./run.sh model
```

### אפשרות ב — ב-docker-compose.yml
```yaml
environment:
  HERMES_INFERENCE_PROVIDER: ollama
  HERMES_MODEL: llama3.1:8b        # שנה כאן
```

### אפשרות ג — ישירות ב-config בתוך ה-volume
```bash
docker compose run --rm --entrypoint bash hermes \
  -c "sed -i 's/default:.*/default: \"llama3.1:8b\"/' /opt/data/config.yaml"
```

### מודלים זמינים ב-Ollama המקומי

```
gemma4:e4b            ← ברירת מחדל נוכחית
gemma3:12b
gemma3:4b
llama3.1:8b
llama3.2:latest
qwen3.5:latest
qwen2.5-coder:1.5b-base
gpt-oss:20b
```

---

## מעבר ל-Gemini (כשה-Ollama כבוי)

ב-`docker-compose.yml`, שנה:
```yaml
environment:
  HERMES_INFERENCE_PROVIDER: gemini
```
המפתח `GOOGLE_API_KEY` כבר קיים ב-`.env`.

---

## הגדרת סוכן חדש

### שלב 1 — הגדרת זהות (SOUL)

בתוך ה-volume יש קובץ `SOUL.md` שמגדיר את אישיות הסוכן.
לעריכה:

```bash
docker compose run --rm --entrypoint bash hermes \
  -c "cat /opt/data/SOUL.md"
```

לכתיבה:
```bash
docker compose run --rm --entrypoint bash hermes \
  -c "echo 'אתה עוזר AI אישי בשם הרמס...' > /opt/data/SOUL.md"
```

### שלב 2 — הגדרת provider ומודל

ב-`docker-compose.yml`:
```yaml
environment:
  HERMES_INFERENCE_PROVIDER: ollama     # או: gemini, anthropic, openrouter
  HERMES_MODEL: gemma4:e4b              # מודל ספציפי
```

### שלב 3 — הגדרת channels (Telegram, Discord וכו')

```bash
./run.sh gateway
```

לחיבור Telegram ספציפי — הוסף ל-`.env`:
```env
TELEGRAM_BOT_TOKEN=<הטוקן שלך>
```

ואז:
```bash
./run.sh gateway
# בחר Telegram → הזן bot token
```

### שלב 4 — הוספת Skills

Skills הם יכולות שמוסיפים לסוכן. 79 built-in כבר מותקנות.
להוספת skill מהHub:

```bash
./run.sh skills install <skill-name>
```

או כתיבת skill מותאמת אישית — צור תיקייה `~/.hermes/skills/<skill-name>/SKILL.md` עם הוראות.

---

## ניהול הנתונים (Volume)

כל הנתונים — שיחות, זיכרון, skills, קונפיגורציה — שמורים ב-Docker volume:

```bash
# כניסה לבדיקה ידנית
docker run --rm -it -v hermes-agent_hermes-data:/data alpine sh

# קבצים מרכזיים:
# /data/config.yaml       — קונפיגורציה ראשית
# /data/.env              — מפתחות API (מועתק בהפעלה ראשונה)
# /data/SOUL.md           — אישיות הסוכן
# /data/memories/         — זיכרון בין שיחות
# /data/skills/           — skills מותאמות אישית
# /data/sessions/         — היסטוריית שיחות
```

**איפוס מלא** (מוחק הכל):
```bash
docker volume rm hermes-agent_hermes-data
```

---

## תיוג הודעות Telegram בהפעלה

`run.sh` שולח הודעה אוטומטית לפני כל הפעלה:

```bash
# לשינוי הטקסט — ערוך run.sh שורה:
-d text="Hello from Hermes! Starting up..."
```

Bot: `nanoMacClaw_bot` | Chat ID: `217441497`

---

## פתרון בעיות

```bash
./run.sh doctor              # בדיקת תקינות כוללת
./run.sh doctor --fix        # תיקון אוטומטי של בעיות
docker compose logs          # לוגים של ה-container
```

**Ollama לא מגיב:**
```bash
curl http://localhost:11434/api/tags   # בדיקה שה-host מגיב
# אם לא — הפעל Ollama: ollama serve
```

**volume פגום:**
```bash
docker volume rm hermes-agent_hermes-data
./run.sh   # יצור volume חדש
```
