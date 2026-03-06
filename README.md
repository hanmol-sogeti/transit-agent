# ReseAgenten

**ReseAgenten** är en AI-driven kollektivtrafikassistent för Sverige, byggd som en Flutter-skrivbordsapplikation. Appen kombinerar Trafiklabs API:er med Azure OpenAI för ett naturligt samtalsgränssnitt för att söka hållplatser, planera resor, se avgångar i realtid och simulera biljettköp.

---

## Funktioner

- **Fritext-sökning** – Fråga på svenska: "Hur tar jag mig från Flogsta till Centralstationen kl. 08:30?"
- **Reseplanering** – Hämtar upp till 3 reseförslag via Trafiklabs ResRobot v2.1
- **Realtidsavgångar** – Visar aktuella avgångar och förseningar för valfri hållplats
- **Kartintegration** – Interaktiv karta med OpenStreetMap och färgkodade reslinjer
- **Biljettbokning** – Simulerad bokning med bokningsreferens och avbokningshantering
- **AI-agent (MCP)** – Agentic loop med Azure OpenAI function calling och interna MCP-verktyg
- **Fliken Bokningar** – Historik med kvitton och avbokningsmöjlighet
- **Inställningar & debug** – Konfigurationsöversikt, integritetsinformation och MCP-anropslogg

---

## Krav

- [Flutter](https://flutter.dev/) ≥ 3.10 med skrivbordsstöd aktiverat
- Windows 10/11, macOS 12+ eller Linux
- Nätverksåtkomst till Trafiklabs API:er och Azure OpenAI

### Flutter skrivbordsplattform

Säkerställ att skrivbordsstöd är aktiverat:

```bash
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
```

---

## Konfiguration

Applikationen läser konfiguration från en `.env`-fil placerad på:

```
C:\Users\<användarnamn>\source\env\transit-ai.env
```

Skapa filen med följande variabler:

```env
# Trafiklab API-nycklar (https://www.trafiklab.se/api/trafiklab-apis/resrobot-v21/)
TRAFIKLAB_REALTIME_KEY=din_nyckel_här
TRAFIKLAB_STOPS_KEY=din_nyckel_här
TRAFIKLAB_ROUTE_KEY=din_nyckel_här

# Azure OpenAI (https://portal.azure.com/)
AZURE_OPENAI_ENDPOINT=https://<din-resurs>.openai.azure.com/
AZURE_OPENAI_KEY=din_nyckel_här
AZURE_OPENAI_MODEL=gpt-4o
AZURE_OPENAI_API_VERSION=2024-02-15-preview

# Karttjänst (OpenStreetMap eller annan WMTS-kompatibel tjänst)
MAP_TILE_ENDPOINT=https://tile.openstreetmap.org/{z}/{x}/{y}.png
MAP_ATTRIBUTION=© OpenStreetMap-bidragsgivare

# Ruttmotor för gångvägar (OSRM eller Valhalla)
ROUTING_ENGINE_ENDPOINT=https://router.project-osrm.org

# Valfritt: aktivera debug-panel i inställningar
# DEBUG_MCP=true
```

> **Obs!** Dela aldrig din `.env`-fil. Filen är listad i `.gitignore`.

---

## Kom igång

### 1. Hämta beroenden

```bash
cd transit-agent
flutter pub get
```

### 2. Kör appen

```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

### 3. Bygg release-version

```bash
flutter build windows --release
```

---

## Preflightkontroll

Preflightsystemet verifierar att alla externa API:er och konfigurationer fungerar korrekt.

```bash
flutter run -d windows -- --preflight
```

Preflighten kontrollerar:

| Kontroll | Beskrivning |
|---|---|
| Miljövariabler | Alla obligatoriska variabler är satta |
| Skrivbehörighet | Kan skriva filer i arbetskatalogen |
| Nätverksanslutning – Trafiklab | TLS och nätverksåtkomst till `api.resrobot.se` |
| Nätverksanslutning – Azure OpenAI | TLS och nätverksåtkomst till Azure-resursen |
| Nätverksanslutning – Kartpaneler | TLS och nätverksåtkomst till kartservern |
| Nätverksanslutning – Ruttmotor | TLS och nätverksåtkomst till ruttmotorn |
| Azure OpenAI | Svarar korrekt på testförfrågan |
| Trafiklab API | Returnerar hållplatser för "Stockholm C" |
| Hållplatssökning | Hittar "Flogsta" via sökfunktionen |
| Lokalisering (sv) | Datumformatering och svenska texter fungerar |
| Loggning – hemlighetsskydd | API-nycklar visas inte i loggar |

Rapporter sparas som `preflight_report.json` och `preflight_logs.txt`.

---

## Projektstruktur

```
lib/
├── main.dart                    # Startpunkt, --preflight-stöd
├── app.dart                     # ReseAgentenApp med tema och lokalisering
├── config/env_config.dart       # Miljövariabler från .env-fil
├── models/models.dart           # Domänmodeller
├── services/                    # Trafiklab, Azure OpenAI, routing, GPS, bokning
├── mcp/                         # Agentisk loop + MCP-verktyg
├── providers/app_providers.dart # Riverpod-providers
├── preflight/                   # Preflightsystem
└── ui/                          # Tema, widgets, skärmar
```

---

## Teknikstack

| Komponent | Teknik |
|---|---|
| UI-ramverk | Flutter 3.x (Dart) |
| Tillståndshantering | flutter_riverpod |
| Kartor | flutter_map + OpenStreetMap |
| AI-modell | Azure OpenAI (GPT-4o) |
| Kollektivtrafikdata | Trafiklab ResRobot v2.1 |
| Gångvägar | OSRM / Valhalla |
| Fönsterhantering | window_manager |

---

## Integritet

- Resefrågor skickas till Azure OpenAI för AI-behandling
- Hållplats- och resdata hämtas från Trafiklabs öppna API:er
- API-nycklar lagras lokalt i din `.env`-fil
- Bokningar är simulerade och lagras enbart i minnet under sessionen

---

## Licens

MIT – se [LICENSE](LICENSE) för detaljer.
