# Cavira — Architecture & phased build document
### Single source of truth for constraints, phased work, and repo decisions (`archeticturedoc.md`)

**Maintenance:** Whenever you change behaviour, models, services, or navigation, update this file so the project stays traceable (**Build progress** table, **Repo snapshot**, phase prompts, and “decisions” sections).

---

## Repo snapshot — what’s in the build today

Use this with the **Build progress** table below. Major additions: **Phase 15 Home collections**, **collection viewer toolbar architecture**, **Settings data controls**, **theme picker chip colors**.

| Area | In repo / working |
|------|-------------------|
| **Models** | SwiftData: `PhotoEntry` (incl. `mediaKind`, `isLivePhoto`, `localIdentifier`, **`isInHomeAlbum`**, **`homeCollection`**, **`collectionMemberOrder`** for ordered membership), **`HomeCollection`** (`title`, `homeOrderIndex`, `createdDate`, ordered `entries`, `coverEntry` / `orderedEntries` helpers), `Story`, `StorySlide`, tags, `AppSettings` (`defaultHomeView`, `appearanceMode`, `defaultStorageMode`, **`themePalette?`**, legacy migration flag), `PhotoAssetKind`, `HomeViewMode` (`.grid`, `.timeline`, `.videos`, legacy-only cases kept for migration). **Legacy in repo (intentional, migration-only):** `Event` + any `PhotoEntry.event` / `Story.event` wiring — product is Stories-first (see **Decision: Retire legacy second tab concept** below). |
| **Theme** | **`CaviraTheme`** / **`ThemePalette`**. **ThemePickerSheet** uses **`themePickerSwatchColor`** per palette so chips read as light vs dark (e.g. Cloud vs Midnight). **`swatchColor`** remains for global `.tint()`. **UIKit chrome** via **`CaviraTheme.applyGlobalChrome()`**. |
| **Services** | `AppServices` + `Environment` (`AppServices?`); photo library + image loader + import; **`DataService`** incl. **`resetSettingsToDefaults`**, **`deleteAllCaviraData`** (deletes **`HomeCollection`** and clears members per dissolve semantics), **`nextHomeOrderIndex`** for merged Home ordering. |
| **Shell** | `RootView` `TabView` (5 tabs); one **`NavigationStack`** per tab. |
| **Home** | **Grid \| Timeline \| Videos**. **Unified album rows:** standalone photos (`isInHomeAlbum == true` and `homeCollection == nil`) **plus** **`HomeCollection`** tiles (`HomeAlbumRow`); members do not get their own tiles. **Import:** **`ImportOptionsSheet`** — single-item **Title***; **2+** photos/Lives → one **Collection *** field + Location/People + **Add** (`runCollectionImport`). Collection cells: cover + **stack badge**. **Navigation:** **`HomeDestination`** (photo vs collection UUID); **`HomeCollectionViewer`** (paging `TabView`). **Context menu:** Edit + Remove; **collection** remove **dissolves** the whole group (same as spec). **Reorder:** merged list of standalone + collections. |
| **Photo detail** | **`PhotoDetailView`**: principal **date + location** (`PhotoDetailNavChrome`), trailing **⋯** (Edit, place people tags, Share, Remove / **Delete collection**). **Share / delete-from-home** logic in **`PhotoDetailCommandHelpers`**. **Collection pager:** each page uses **`isEmbeddedInCollectionPager`** + **`SpatialTapGesture`** (so `TabView` paging wins); **no toolbar on tab pages** — **`HomeCollectionViewer`** owns **`.toolbar`** (principal + **`1 / N`** + **`PhotoDetailPagerOverflowMenu`**). **`externalPlacingPeopleTag`** binds “place tags” mode to the parent menu. **Delete collection** from detail removes the whole **`HomeCollection`** and all members from Home (not one photo only). |
| **Photo / import UI** | `Views/Photo/`; `Views/Home/` incl. **`HomeCollectionViewer`**, **`HomeDestination`**, **`HomeAlbumRow`**. |
| **Calendar tab** | Unchanged pattern from prior snapshot (month, day grid, recap, shared import/builder). |
| **Search** | Album + **collections** browse (`PhotoEntry.isInHomeAlbum == true` **or** `homeCollection != nil` where applicable); collection navigation to **`HomeCollectionViewer`**. |
| **Settings** | Display + storage; **Reset settings** and **Delete all Cavira data** with confirmations; **About** without version row (per product choice); theme picker as above. |

**Schema changes:** adding SwiftData properties historically required **simulator delete app** or a migration; keep a **VersionedSchema** / migration story in mind before App Store.

---

## Upcoming work (roadmap)

| When | Focus |
|------|--------|
| **Next** | **Phase 13** — Video-first Home refinements (Grid/Timeline photos-only, segment-aware import); **Phase 14** — Videos in Stories — see Build progress (**Phase 15 collections** shipped). |
| **Then** | Continue **Phase 12** polish backlog as needed. |
| **Late v1** | Ongoing polish per **Phase 12** backlog items. |
| **Close v1** | **Phase 12** — Polish & QA: missing-asset UI, **import flow GUI**, **sticky timeline months** (if not done earlier), empty states everywhere, animations, app icon, memory, full walkthrough; **optional** polish: dark-mode **tint** tuning, **SwiftUI-only** tab/nav chrome (see Phase 12). |
| **Backlog** (see **Additional improvements** + UX notes) | Centre tab **`+`** global import; Calendar **day detail** strip; Stories **~10 s** clips. |

---

## Phase 13 — Video-first Home refinements (planned)
**Build tracker:** 🟡 Planned

### Goal
Make Home’s **Videos** segment a **first-class video-only surface**:
- **Grid** and **Timeline** become **photos-only** (including Live Photos as still posters).
- **Videos** becomes **videos-only** with the same grid layout and per-item actions as photos.
- Import from Home adapts to the current segment: in **Videos**, the add route is **video-only**.

### Product rules (locked for Phase 13)
- **Source of truth**: Videos stay **reference-only** (`localIdentifier`) in Apple Photos (no Cavira-owned video store).
- **Exclusive surfaces**:
  - **Grid / Timeline**: show only `PhotoEntry.mediaKind == .image` (Live Photos count as images).
  - **Videos**: show only `PhotoEntry.mediaKind == .video`.
- **Album membership (Option A)**: Keep **one** membership flag: `PhotoEntry.isInHomeAlbum == true` means the item is in Cavira’s curated Home album (photos **and** videos). Each Home segment filters by `mediaKind` to enforce exclusivity.
- **Import route (Home)**:
  - When Home is in **Videos**, the `+` picker defaults to **videos-only selection**.
  - When Home is in **Grid** or **Timeline**, the `+` picker defaults to **photos-only selection** (images + Live Photos).
- **Import options**: Use the **same** `ImportOptionsSheet` flow for photos and videos (Title/Location/People) — no video-specific metadata screen in v1.
- **Thumbnail**: Videos show a **poster frame** (still thumbnail) in the grid, plus a play badge (no autoplay in v1).
- **Actions parity**: Video items support the **same album actions** as photos (Edit tags, Share, Remove from album, reorder where applicable).
- **Ordering**: Photos and videos have **separate ordering** (independent reorder for Grid/Timeline vs Videos).
- **Calendar**: Calendar is **photos-only** (counts/day grids do not include videos; “Add to Home” from Calendar is image-only).
- **Legacy guardrail**: If any video entries were previously imported into the Home album, the app should **remove them from Home** (v1 should not show videos in Grid/Timeline at all).

### Engineering notes
- iOS videos are represented by `PHAsset` with `mediaType == .video` (Photos library API; same reference model as stills).
- `PHPickerViewController` supports media-type filtering; implement segment-based filters in the Home import flow.
- Separate ordering likely requires a second index (e.g. `PhotoEntry.videoOrderIndex`) or a small ordering model keyed by `(entryID, segment)`; avoid breaking existing `homeOrderIndex` migration.

### Phase 13 Test Checklist
- [ ] Grid shows photos only; Timeline shows photos only (no video rows).
- [ ] Videos shows videos only; empty state copy remains “No videos yet” when album has photos but no videos.
- [ ] In Videos mode, tapping `+` shows a **videos-only** picker.
- [ ] In Grid/Timeline mode, tapping `+` shows a **photos-only** picker (images + Live Photos).
- [ ] Imported video entries appear only in Videos mode (and never in Grid/Timeline).
- [ ] Video thumbnail shows poster + play badge; detail plays via Photos-backed player; share exports video resource.
- [ ] Remove from album toggles `isInHomeAlbum = false` (does not delete from Apple Photos).
- [ ] Reordering photos does not affect video order; reordering videos does not affect photo order.
- [ ] Calendar counts/day views are photos-only; “Add to Home” from Calendar only adds images/Live Photos.
- [ ] Any previously-imported videos are removed from Home automatically (no manual cleanup required).

---

## Phase 14 — Videos in Stories (planned)
**Build tracker:** 🟡 Planned

### Goal
Allow users to add **photos and videos** to Stories (builder + viewer) while keeping Home’s Grid/Timeline photos-only and keeping media **reference-only** from Apple Photos.

### Product rules (locked for Phase 14)
- **Mixed media slides**: a Story can contain slides referencing `PhotoEntry` where `mediaKind == .image` or `.video`.
- **Reference-only**: Story slides point to Apple Photos via `localIdentifier` (no Cavira-owned media files).
- **Viewer timing**:
  - **Photos**: 10 seconds per slide (as today).
  - **Videos**: use the **full video duration** for auto-advance.
- **Calendar → Add to Story stays photos-only**: the Calendar entry point remains scoped to photos captured on that day (even after Phase 14).
- **Home exclusivity stays**: Videos still do not appear in Grid/Timeline; Stories is the only non-Videos surface allowed to show videos.

### Phase 14 Test Checklist
- [ ] Story builder picker (normal entry) shows photos + videos and can select either as slides.
- [ ] Calendar → Add to Story remains photos-only.
- [ ] Viewer plays video slides and auto-advances at the end of the video (photos still advance at 10s).
- [ ] Missing video asset handling matches Phase 12 resilience patterns.
- [ ] No Cavira disk copy is created; share/export uses Photos resources.

---

## Phase 15 — Home collections
**Build tracker:** ✅ Complete

### Goal
Introduce **Home collections**: user-curated **groups of library items** that appear on **Grid** and **Timeline** as **first-class tiles** (same density and ordering model as standalone photos), with a **single collection title** at import time, **no per-item titles** in that flow, and an **Instagram-style** drill-in viewer (swipe between members + **index indicator** top-trailing, e.g. `3 / 12`). **Stories are unchanged** — no new coupling between collections and `Story` / `StorySlide`.

Product language: use **collection** everywhere the UI or copy previously implied an unnamed **batch**.

### Relationship to existing surfaces
- **Stories:** Independent. A `PhotoEntry` may appear in a Home collection **and** in Story slides (or Story-only without Home). **No** automatic Story creation when saving a collection.
- **Videos (Home segment):** **Phase 15 collections are created only from the Grid/Timeline photo import path** (same picker filter as today: **images + Live Photos**, not the Videos-only picker). Mixed “video collections” are **out of scope** for this phase unless product revisits after Phase 13/14 stabilise.
- **Calendar → Add to Home:** When the user selects **more than one** still/Live asset and confirms, use the **same branched flow** as Home (`ImportOptionsSheet` → **Collection add** step) so behaviour stays consistent.

### Data model (hybrid A + B)
1. **New `@Model` type: `HomeCollection`**
   - `id: UUID`
   - `title: String` (user-facing collection name; **one** field for the whole group)
   - `homeOrderIndex: Int?` — participates in the **same manual ordering space** as standalone `PhotoEntry` rows on Home (see **Ordering** below)
   - Optional: `createdDate` / `lastEditedDate` for debugging or timeline tie-breakers
   - **Ordered membership** to `PhotoEntry` (implementation: ordered relationship array **or** explicit per-member `order: Int`; v1 must preserve **user-visible order** as picked in the collection flow and in reorder — default **picker order** at creation)

2. **`PhotoEntry` extension (B)**
   - Optional relationship: `homeCollection: HomeCollection?` (inverse of membership)
   - **Exclusivity:** An asset may belong to **at most one** `HomeCollection`. Enforce at import and when moving items (v1: **no** “move into collection” UI unless added later).
   - **Home visibility rules:**
     - **Standalone row on Grid/Timeline:** `isInHomeAlbum == true` **and** `homeCollection == nil`.
     - **Member of a collection:** `homeCollection != nil`. Members **do not** appear as their **own** tiles on Grid/Timeline (even if `isInHomeAlbum` were true — implementation should pick **one** rule and keep it consistent; recommended: members use `isInHomeAlbum == false` and **only** the parent `HomeCollection` consumes a Home slot; **Search** may still index member metadata as “in Cavira” via membership).
   - **Conflict rule:** If a `PhotoEntry` is already a **member** of a Home collection, the **standalone** import path must **not** add that asset as its **own** Home tile (surface a clear message: already part of a collection). **Stories** ignore this rule for membership — Story slides can still reference that `PhotoEntry`.

3. **Deduping / idempotency**
   - Still **one `PhotoEntry` per `localIdentifier`** in SwiftData. Creating a collection **links** existing or newly imported rows; never duplicate rows for the same library id.

### Import UX (single flow, branched — no separate top-level menu)
1. User taps **`+`** → **same** `PHPicker` as today (segment-aware per Phase 13: **photos-only** on Grid/Timeline).
2. **`ImportOptionsSheet`** (single “Add” form):
   - **1 item:** **Title*** required; Location / People as today.
   - **2+ items:** **Collection *** (required) on the **same** sheet — shared **Location** and **People** applied to every member; **Add** creates **`HomeCollection`** and links members (no separate `CollectionAddSheet`).
3. On save: create **`HomeCollection`**, attach ordered members (`collectionMemberOrder`), set **`homeOrderIndex`**, persist, dismiss.

### Grid & Timeline presentation
- **Parity with standalone photos:** A collection appears as **one cell** with the **same** outer layout as a normal photo tile (thumbnail fills the cell).
- **Cover:** Always the **first** member in the collection’s ordered list (not user-changeable in v1).
- **Badge:** Small **collection** indicator **top-trailing** on the thumbnail (icon only; subtle, does not obscure the whole image).
- **Timeline:** Interleave collection cells with standalone photo cells using the **unified sort** (see **Ordering**). Same badge treatment.

### Drill-in viewer (collection detail)
- Tapping a collection pushes **`HomeCollectionViewer`** (`TabView` paging, `.page`, index display hidden).
- **Navigation bar (standard layout):** inline **`navigationTitle(collection.title)`**; **toolbar** on the **viewer** (not on each paged `PhotoDetailView`): **`.principal`** = shared **`PhotoDetailNavChrome.principalToolbarContent(for: currentEntry)`**; **`.topBarTrailing`** = **`1 / N`** + **`PhotoDetailPagerOverflowMenu`** (same actions as standalone detail). This avoids SwiftUI/`TabView` coupling where **per-page toolbars** slide or flicker during paging.
- **Gestures:** Paged **`PhotoDetailView`** sets **`isEmbeddedInCollectionPager`** and uses **`SpatialTapGesture`** + **`simultaneousGesture`** for media chrome (people overlays / place flow); standalone detail keeps **`DragGesture(minimumDistance: 0)`** for tap-to-toggle overlays. **`externalPlacingPeopleTag`** syncs “place people tags” from the parent menu to the visible page.
- **Helpers:** **`PhotoDetailCommandHelpers`** (share export, delete collection, remove standalone from Home); **`PhotoDetailNavChrome`** (centered date/location stack for toolbar).
- **Detail destructive action:** When `entry.homeCollection != nil`, the menu offers **Delete collection** (entire group removed from Home per dissolve semantics), not “remove only this photo” from that menu.

### Reordering (Home reorder sheet)
- **One row per Home slot:** either a **standalone** `PhotoEntry` **or** a **`HomeCollection`** — never an expanded list of collection members in the reorder UI.
- **Shared index space:** Both `PhotoEntry.homeOrderIndex` (standalone only) and `HomeCollection.homeOrderIndex` participate in a **single** merged ordering pass when the user saves reorder (renumber `0…n-1` across the merged list).
- **Implementation sketch:** Fetch standalone entries + collections, merge-sort by current `(homeOrderIndex, fallback capturedDate)`, present one list, on save write contiguous indices back to the appropriate entities.

### Search & other queries
- **Search** should treat a collection’s **`title`** as searchable; optionally include member **titles/notes/tags** when indexing “Home album” content (spec detail when implementing).
- **`DataService.deleteAllCaviraData`:** extend to delete **`HomeCollection`** rows (and nullify / delete members per chosen dissolve semantics).

### Dissolve / remove (v1 default — refine if product disagrees)
- **Remove collection from Home:** Delete the **`HomeCollection`** record, set all members `homeCollection = nil` and **`isInHomeAlbum = false`** (items remain in SwiftData for Stories / history). **Do not** delete `PhotoEntry` rows unless the user uses a separate destructive action.
- **Standalone “Remove from album”** on a collection tile: same as above (remove grouping from Home).

### Non-goals (Phase 15)
- Changing **Story** builder, viewer, or schema.
- User-pickable **cover** image for a collection.
- **Video** collections on the Videos segment.
- Nesting collections or cross-app iCloud sync of grouping metadata beyond SwiftData.

### Phase 15 Test Checklist
- [x] Picker multi-select on Grid/Timeline → **one Add form** with **Collection *** required; import succeeds.
- [x] Single select → **per-item Title*** behaviour unchanged.
- [x] Collection appears in **Grid** and **Timeline** with **cover = first ordered image member** and **top-trailing** collection badge.
- [x] Tap collection → pager; **toolbar** shows date, **`1 / N`**, ⋯; swipe between members without toolbar flicker (chrome hosted on **`HomeCollectionViewer`**).
- [x] Reorder sheet lists collections **once** alongside standalone photos; saved order matches Home.
- [x] Member asset **cannot** also appear as a **standalone** Home tile; import blocked with clear messaging.
- [x] Same asset may still be used in **Stories** regardless of Home collection membership.
- [x] Remove collection from Home / **Delete collection** from detail **dissolves** grouping per spec without deleting Apple Photos assets.

### Open questions (minor — defaults above apply until product revisits)
- Whether **dissolve** should offer “promote members to standalone Home tiles” (not in v1 default).
- Exact **iconography** for the collection badge (SF Symbol vs custom).

---

## How to use this document

1. **Work through phases in order.** Each phase builds on the last. Do not skip ahead.
2. **One phase at a time in Cursor.** ask user before moving on
3. **If Cursor gets confused**, bring it to user with option and questions
4. **Each phase has a checklist.** Run through it with user
5. **If something breaks in a later phase**, it almost always traces back to a model or service from an earlier phase. Check those first.

---

## Build progress (repo tracker)

Keep this table in sync with the Cavira codebase as phases finish. Each phase section below repeats the same status on its own **Build tracker** line.

| Phase | Status |
|:-----:|--------|
| 1 — Project setup & models | ✅ Complete |
| 2 — Core services | ✅ Complete |
| 3 — Tab shell & navigation | ✅ Complete |
| 4 — Photo / video import (reference, dedupe) | ✅ Complete |
| 5 — Home (grid & timeline) | ✅ Complete |
| 5.5 — CaviraTheme (Ranger) | ✅ Complete |
| 6 — Calendar (month counts + day drill-in + recap) | ✅ Complete |
| 6.1 — Calendar year/month navigation | ✅ Complete |
| 7 — Tagging | ✅ Complete |
| 8 — Search | ✅ Complete |
| 9 — Stories | ✅ Complete |
| 10 — Settings & storage | ✅ Complete |
| 11 — Pinning (no ProfileView) | ✅ Complete |
| 12 — Polish & QA | ✅ Complete |
| 13 — Video-first Home refinements | 🟡 Planned |
| 14 — Videos in Stories | 🟡 Planned |
| 15 — Home collections | ✅ Complete |

---

## App Name: Cavira
**Platform:** iOS 18+ (iPhone only in v1 — `TARGETED_DEVICE_FAMILY = 1`)  
**Language:** Swift / SwiftUI  
**Database:** SwiftData  
**Photo access:** PHPhotoLibrary  
**Contacts:** CNContactStore  
**Location search:** MapKit (`MKLocalSearchCompleter` + `MKLocalSearch`)

### Cavira v1 product constraints (read before Phase 2+)
- **Digital album (Home):** the **Home** tab shows **only** the **user-curated subset** of photos/videos the user wants in Cavira’s album — **not** the entire Photos library by default (see **Cavira UX direction**).
- **Stories can include library items without adding to Home:** A user must be able to add a photo/video to a **Story** without also adding it to the **Home** album. Implementation-wise, treat “in Home album” as a **flag/filter**, not as “exists in SwiftData vs not”.
- **Photos organiser only:** metadata, tags, events, and stories live in SwiftData; **pixels always come from the user’s Photos library** (reference / `localIdentifier`). No private image vault outside Photos in v1.
- **Reference-only = no Cavira duplicate library:** Cavira **does not** copy full-resolution images or videos into Application Support for v1. Each `PhotoEntry` is a **pointer** to an asset already on the device (`localIdentifier`). The `StorageMode.localCopy` enum case remains for a **future** optional feature; imports and loaders are **reference-only** for now.
- **One row per library asset in the album:** the user must **not** end up with multiple `PhotoEntry` rows for the same `localIdentifier` when adding to the digital album — treat import as **idempotent** (skip or update-in-place if that asset is already in SwiftData). This matches “one reference per gallery item,” not duplicate rows.
- **Remove from Cavira ≠ delete from Apple Photos:** any “remove from album” / delete `PhotoEntry` action **only** deletes the SwiftData row (and Cavira metadata). **Cavira never deletes or edits assets inside the user’s Apple Photos library** in v1; deleting originals remains a **Photos** app concern.
- **No duplicate on-disk library:** same as above — **no double storage** on disk in v1.
- **Format:** when loading **still** originals from Photos, use **`PHImageManager.requestImageDataAndOrientation`** (or equivalent) so the system returns the asset’s native data (typically **HEIF**; JPEG/PNG where stored). **Video** assets use **Photos-backed playback** (e.g. `PHImageManager` / `AVPlayerItem` with the asset) — no transcoding to a Cavira-owned file in v1.
- **Photos permission timing:** request library access **early at app launch** (e.g. first scene appearance of `RootView` / app root), **before** the user needs import or calendar counts. **Authorisation is persisted by iOS**; the app may also persist lightweight UX flags in **`AppSettings`** (e.g. whether we have shown a one-time explanation) — do **not** confuse that with duplicating photo data.
- **Full library access (product):** Cavira is designed around **accurate read-only calendar counts** and frictionless import. **iOS does not allow apps to force “All Photos” programmatically**; we request **`readWrite`** access at launch, explain the need in **`NSPhotoLibraryUsageDescription`**, and refresh **`PHAuthorizationStatus`** when the app returns to **`.active`** (`scenePhase`) so **Limited → All Photos** changes in Settings show up without relaunching.
- **Services:** prefer **`@Observable` + `@MainActor`** and **dependency injection** via `AppServices` and SwiftUI’s `Environment` (not singletons). Phase 3 wires this through the tab shell.

### Cavira v1 UI & shell decisions (Phase 3 — keep in sync with repo)

- **Device focus:** **iPhone only** for v1 (Xcode target **`TARGETED_DEVICE_FAMILY = 1`**). No iPad-specific sidebar shell in this guide unless scope changes.
- **Navigation (HIG):** **One `NavigationStack` per tab** in each `*Tab.swift`; inner screens (`HomeScreen`, calendar screens, etc.) **do not** wrap a second `NavigationStack`.
- **Root view:** The tab shell lives in **`RootView.swift`** with **`init(appServices:)`**. **`CaviraApp`** uses `WindowGroup { RootView(appServices: appServices).modelContainer(...) }`. **`RootView`** applies **`.environment(\.appServices, appServices)` on the `TabView`**. The **`AppServices`** type is **`@MainActor` only** (not `@Observable`); nested services stay `@Observable`.
- **Environment typing:** `EnvironmentValues.appServices` is **`AppServices?`** (matches `EnvironmentKey` storage). Do **not** add a non-optional façade with `preconditionFailure` — SwiftUI can read the key during `TabView` merge before the value appears, which used to crash. Call sites use `if let` / `guard let` when unwrapping.
- **`AppSettings` bootstrap:** **`RootView`** reads `@Environment(\.modelContext)` and in `.onAppear` calls `DataService.getOrCreateSettings(context:)`. **`DataService`** calls **`try? context.save()`** immediately after inserting the first `AppSettings` row so defaults hit disk without waiting on implicit flush — this follows Apple’s SwiftData pattern of using **`ModelContext.save()`** when you want changes committed.
- **Home mode switcher:** Segmented **`Picker`** in the nav bar: **Grid \| Timeline \| Videos**. **Current build:** Grid/Timeline show the full album; Videos is video-only. **Planned refinement:** see **Phase 13** to make Grid/Timeline **photos-only** and to make the `+` import route segment-aware (photo-only vs video-only).
- **Copy & localization:** **English UI strings only** in v1 placeholders (no `String(localized:)` / strings tables until we add locales).
- **Chrome:** **Phase 5.5** applies the **Ranger** palette via **`CaviraTheme`** + **UIKit global appearances** (`CaviraTheme.applyGlobalChrome()`). There is **no** user-selectable light/dark or multi-palette theme in v1; optional refinements are **Phase 12** only.
- **Global “add to album” (+):** **Home** and **Calendar** use the **same** top-trailing toolbar control — **`AlbumImportToolbarButton`** (`plus.circle.fill`, accent + tertiary ring) beside the nav title / segmented control. **Not** a bottom-right FAB on Home. **Product stretch goal:** a **centre tab-bar `+`** for import from any tab — keep **one `NavigationStack` per tab** unchanged.
- **No deep links:** **No URL schemes, Universal Links, or external tab routing** for Cavira content in v1. **Exception:** opening **system Settings** via `UIApplication.openSettingsURLString` (e.g. after Photos denial) is allowed and is **not** considered an app “deep link.”
- **Previews:** **`CaviraPreviewSupport.swift`** defines **`caviraPreviewContainer()`** (in-memory SwiftData) and **`caviraPreviewShell()`** (container + `AppServices` via `environment`). **`RootView`** previews use **`RootView(appServices:).caviraPreviewContainer()`** so services are not duplicated.
- **Accessibility:** Placeholder screens use **combined accessibility** / labels where it clarifies empty states.

### Cavira UX direction (product — agreed decisions)

#### Home tab (Instagram-style “digital album”)
- **Source of truth:** Home shows **only the user-created subset** the user has chosen for their Cavira **digital album** — **not** the whole Apple Photos library. **This curation is the main point of the app.**
- **Collections (Phase 15 — shipped):** Users may group **multiple stills / Live Photos** into a **named Home collection** that appears as **one tile** (cover = first ordered image member, badge top-trailing). **Stories** do not use this grouping. See **Phase 15 — Home collections**.
- **Photos + videos:** the same digital album holds **still images and videos** side by side (Instagram-style: user can add either from the library into the same grid / timeline). **`PhotoEntry`** records the asset kind (see **Phase 1 / `PhotoEntry`** — `mediaKind` + Live flag).
- **Live Photos:** on **Grid** and **Timeline**, show the **still poster frame** only (like a normal photo cell). The **Videos** segment lists **video assets only** (no Live Photo rows there). In **Photo detail**, support **Live Photo playback** (press-and-hold / motion like **Apple Photos**) using `PHLivePhoto` / `PHLivePhotoView` where the asset is live — still no duplicate files; all motion data stays in the system library.
- **Grid \| Timeline \| Videos:** **Grid** and **Timeline** show **photos-only**. **Videos** shows **videos-only** (see Phase 13 for the locked rules and segment-aware import).
- **Header toggle:** **Grid**, **Timeline**, and **Videos** — **Profile** is not shown (see historical note below).
- **What “Profile” meant (historical):** `HomeViewMode.profile` was a **placeholder third layout** (Instagram-like **“your grid of posts”**), not account settings. **Not** a third home segment going forward; remove from UI and retire from the enum in a small model pass when convenient.

#### Calendar tab (second tab)
- **Name:** Tab + nav title **Calendar**.
- **Two layers (do not conflate):**
  1. **System library calendar (read-only):** “What did I capture on this day?” comes from **Apple Photos** — query **`PHAsset`** by **creation date** when building the month / day UI. This includes **everything** in the library the OS exposes for that day, **whether or not** the user added those items to the **Home digital album**. **No bulk import into SwiftData on app launch** — that would bloat the store and contradict curation; the Calendar surface **reads the library live** (with optional small in-memory cache later if profiling demands it).
  2. **Cavira `PhotoEntry` rows:** only assets the user explicitly **adds to the album** (import flow) get a row. Optional UI can show “already in Cavira” vs not when picking from a day — Phase 6+.
- **Month view — counts:** Per-day counts and thumbnails use **`PHPhotoLibrary` / `PHAsset`** (**photos only**) by creation date, same read-only tooling as above.
- **Day drill-in:** Tapping a day opens a **grid of that day’s captured items** (read-only, Photos-backed). From there, the user can optionally **import selected items into Cavira’s album** (creating `PhotoEntry` rows) — still no bulk import.
- **Day popup interaction (v1):** tap a day → present a **grid popup/screen** of that date’s photos. Tapping an item opens an **Options** sheet (full height) with two actions:
  - **Add to Home**: presents **the same Home Add form** (`ImportOptionsSheet`) and writes to the same `PhotoEntry` fields (title, location, people). This guarantees UI stays consistent if the Home Add form changes later.
  - **Add to Story**: presents **the same Stories builder** (`StoryBuilderView`) but **scoped to only that day’s captures** (so the user isn’t browsing the whole library from this entry point).
- **Recap surface (below calendar):** A lightweight “recap” module cycles through old photos:
  - **On this date**: show assets from the same day/month in prior years (if any).
  - **This month** (fallback): show assets from the same month across years.
  - **Playback:** auto-advance every ~5 seconds with a soft fade.
  - **Source:** read-only `PHAsset` (not required to be in Cavira album).
- **No planned-event layer**: the calendar is about *captured activity*, not scheduling.

---

### Decision: Retire legacy second tab concept — migrate history into Stories

**Why:** A second “event/occasion” bucket didn’t match the product direction. Stories is the better mental model for narrative recap, and Calendar is strictly a read-only “what did I capture” surface.

**New model:**
- **Calendar** = Photos-backed activity counts + day drill-in + recap carousel.
- **Stories** = the only narrative/grouping feature inside Cavira.
- **No legacy tab UI** and no “Occasions” section in Calendar.

**Migration (so we don’t lose history):**
- Convert each existing `Event` into a `Story`:
  - **Story title** = `Event.title`
  - **Story slides** = the `Event.photos` entries (or their `PhotoEntry` references) sorted by `capturedDate` ascending
  - **Cover** = `Event.coverPhotoId` if set, else first slide
  - **Story date** = `Event.startDate` (single date; end date dropped)
  - **Created/edited dates** = conversion timestamp
- For `PhotoEntry.event`, either drop the relationship entirely or rewrite it into Story membership by creating slides.

**Hard constraint:** Stories are **past/present only**. We do not create future-dated “plans” anywhere in the app.

#### Stories tab
- **Shelf layout:** **Horizontal row of cards** (like a shelf), **separated** visually between stories.
- **Card chrome:** **Background image stretches edge-to-edge** on the card; **user-chosen title text** draws **on top** of that image (readable contrast / safe areas in implementation).
- **Create entry point:** **`+`** button **top-right** in the navigation area to create a new story.
- **Viewer:** Instagram-style **tap-through** slides (**photos and videos**) with **10 s** per slide unless the user manually advances.
- **Capture into story:** from the Story builder, allow **capturing a photo/video** and adding it as a slide. The capture must **save into Apple Photos** (no Cavira-private media store) and then import the new asset into Cavira as a `PhotoEntry` reference.
- **Cover / poster:** **Default** = **first slide**; user must be able to **pick another** image as cover later.

#### Search tab
- **Name:** **Search** (keep).
- **Purpose (expanded):** Search Cavira’s organised library by **metadata** — e.g. **location**, **person**, “**all photos I’ve ever included** with this person”, **family** groupings, **selfies** (via tags / smart labels / future face or album heuristics as product allows). Same technical direction as **Phase 8**; shell is still a placeholder until that phase.

#### Theme & appearance (Phase 12.9 — shipped)
- **Theme palettes (colors only):** Cavira supports **Ranger (default)** plus **Cloud / Midnight / Arctic / Ember** via `ThemePalette`.
- **User control:** **Settings → Display → Theme** opens `ThemePickerSheet` showing **swatches** + a checkmark for the selected theme.
- **No layout changes:** Theme affects **only** colour tokens (background/surface/accent/text/border), not view hierarchy or interaction.
- **Chrome implementation:** UIKit global appearances are applied via `CaviraTheme.applyGlobalChrome()` at launch and re-applied when palette changes. `RootView` forces a `TabView` refresh on palette change to ensure the tab bar reflects the new colours.
- **Colour scheme:** When `appearanceMode == .system`, `RootView` uses the palette’s default scheme (**Cloud → light**, others → dark).

#### Theme palettes — options + hex codes (implemented)

**Where it lives (code):**
- `Cavira/Models/Enums.swift`: `ThemePalette` enum (options + swatch + default scheme)
- `Cavira/Theme/CaviraTheme.swift`: palette token definitions + `applyGlobalChrome()`
- `Cavira/Theme/ThemeStore.swift`: runtime palette store + applies palette + re-applies chrome
- `Cavira/Views/Settings/ThemePickerSheet.swift`: swatch-based picker UI
- `Cavira/RootView.swift`: applies palette at launch and refreshes tab chrome on change

**Theme options (user-facing):**
- Ranger (default)
- Cloud
- Midnight
- Arctic
- Ember

**Palette tokens (hex):** values below match `Cavira/Theme/CaviraTheme.swift`.

- **Ranger**
  - backgroundPrimary `#2B2A20`, backgroundSecondary `#332F23`
  - surfaceCard `#4E4936`, surfaceElevated `#6B6448`, surfacePhoto `#3D3828`
  - accent `#D4B96A` (pressed `#B8994E`)
  - textPrimary `#E2D5B0`, textSecondary `#C4B48A`, textTertiary `#8B8060`
  - border `#4E4936`, borderStrong `#6B6448`

- **Cloud**
  - backgroundPrimary `#FFFFFF`, backgroundSecondary `#F4F1EA`
  - surfaceCard `#EEE9DF`, surfaceElevated `#E6E0D4`, surfacePhoto `#F0ECE3`
  - accent `#111111` (pressed `#000000`)
  - textPrimary `#141414`, textSecondary `#2C2C2C`, textTertiary `#6A6A6A`
  - border `#E1DBCF`, borderStrong `#D2CBBE`

- **Midnight**
  - backgroundPrimary `#000000`, backgroundSecondary `#0B0B0B`
  - surfaceCard `#121212`, surfaceElevated `#1A1A1A`, surfacePhoto `#0F0F0F`
  - accent `#F4F4F4` (pressed `#D9D9D9`)
  - textPrimary `#F2F2F2`, textSecondary `#D6D6D6`, textTertiary `#8B8B8B`
  - border `#1C1C1C`, borderStrong `#2A2A2A`

- **Arctic**
  - backgroundPrimary `#0B1626`, backgroundSecondary `#0F1D33`
  - surfaceCard `#12243F`, surfaceElevated `#162B4B`, surfacePhoto `#0F1F35`
  - accent `#5FA8FF` (pressed `#3E8FF2`)
  - textPrimary `#E6F0FF`, textSecondary `#C8DAF7`, textTertiary `#7F97B8`
  - border `#1A2D4D`, borderStrong `#244066`

- **Ember**
  - backgroundPrimary `#1A120D`, backgroundSecondary `#21160F`
  - surfaceCard `#2A1B12`, surfaceElevated `#352114`, surfacePhoto `#24170F`
  - accent `#FF8A3D` (pressed `#E8742E`)
  - textPrimary `#F4E7DD`, textSecondary `#E2CFC1`, textTertiary `#A58B78`
  - border `#3A2416`, borderStrong `#4A2D1B`

### Additional improvements (schedule into a phase when ready)

| Item | Notes |
|------|--------|
| **Calendar day detail** | Thumbnail strip / preview for **library** photos on a date (read from `PHAsset`, not mass SwiftData import). |
| **Home — month-scoped recap strip** | Optional later: on **Home**, surface a small “On this date / This month” recap module (Photos-backed) aligned with Calendar’s recap logic. |
| **Import — post-pick cover** | When importing **multiple** assets into an occasion in one go, optional step: **“Which photo is the cover?”** after import. **Backlog** unless folded into **Phase 12** import polish. |
| **Centre tab `+`** | Global import entry from any tab (see **Global “add to album” (+)**); implement with Phase 4 / shell refactors. |
| **Import UI polish** | Picker + `ImportOptionsSheet` presentation and copy — scheduled in **Phase 12** (“Import flow UI”). |
| **Settings — Reset Cavira** | Add a destructive **Reset** action in Settings with a **confirmation dialog**. Reset should wipe Cavira’s **SwiftData** (album `PhotoEntry` rows, tags/stories if present) and restore **`AppSettings`** defaults, but **never delete anything from Apple Photos**. |
| **Home timeline — sticky month headers** | Current **`AlbumTimelineView`** uses **non-sticky** month titles; upgrade via **`List`/`Section`** or custom stickies in **Phase 12** (or earlier if product pulls it forward). |
| **SwiftData migrations** | As models evolve, plan **lightweight migrations** or **VersionedSchema** so TestFlight / App Store users are not forced to delete the app. |
| **Theme tokens** | **Canonical code** is **`Cavira/Theme/CaviraTheme.swift`**. Theme palettes and their hex tokens are documented in this architecture doc under **Theme palettes — options + hex codes (implemented)**. |
| **Retire `HomeViewMode.profile`** | UI already hides **Profile**; remove the enum case (and any stored defaults migration) when safe — small cleanup pass, not blocking Phase 6. |
| **Stories — timed clips** | **~10 s** story segments (capture or trim). |

---

---

# PHASE 1 — Project Setup & Data Models
**Build tracker:** ✅ Complete — repo includes **`PhotoAssetKind`**, **`PhotoEntry.mediaKind`**, **`PhotoEntry.isLivePhoto`** (aligned with Phases 4–5).

### Goal: A compiling project with all data models defined. No UI yet.

---

**Why first:** Everything else depends on the data models being correct. If models change later, SwiftData migrations become painful. Get these locked in before writing a single view.

---

### Cursor Prompt — Phase 1

```
Create a new iOS 17 SwiftUI project called "Cavira" with SwiftData.

Set up the following:

## 1. Project structure — create these folders:
Cavira/
├── Theme/
├── Models/
├── Services/
├── Views/
│   ├── Home/
│   ├── Photo/
│   ├── Calendar/
│   ├── Stories/
│   ├── Search/
│   ├── Settings/
│   └── Components/
└── Resources/
    └── Stickers/

## 2. Create all data models in the Models/ folder:

### Enums.swift
```swift
enum StorageMode: String, Codable { case reference, localCopy }
// Legacy cases kept for SwiftData migration; Home UI is Grid | Timeline | Videos.
enum HomeViewMode: String, Codable { case grid, timeline, videos, events, profile }
enum AppearanceMode: String, Codable { case system, light, dark }

/// Library asset kind for a `PhotoEntry` (still vs video). Live Photos use `.image` + `isLivePhoto == true`.
enum PhotoAssetKind: String, Codable { case image, video }
```

### TextOverlay.swift (Codable struct, NOT @Model)
```swift
struct TextOverlay: Codable, Identifiable {
    var id: UUID = UUID()
    var text: String
    var fontName: String = "System"
    var fontSize: CGFloat = 24
    var colour: String = "#FFFFFF"     // hex string
    var positionX: CGFloat = 0.5       // normalised 0–1
    var positionY: CGFloat = 0.5
    var rotation: CGFloat = 0
    var isBold: Bool = false
}
```

### StickerOverlay.swift (Codable struct, NOT @Model)
```swift
struct StickerOverlay: Codable, Identifiable {
    var id: UUID = UUID()
    var stickerName: String            // asset name or SF Symbol name
    var positionX: CGFloat = 0.5
    var positionY: CGFloat = 0.5
    var scale: CGFloat = 1.0
    var rotation: CGFloat = 0
}
```

### LocationTag.swift (@Model)
```swift
@Model class LocationTag {
    var id: UUID
    var name: String
    var latitude: Double?
    var longitude: Double?
    var mapKitPlaceID: String?
    
    init(id: UUID = UUID(), name: String, latitude: Double? = nil, longitude: Double? = nil, mapKitPlaceID: String? = nil) { ... }
}
```

### PersonTag.swift (@Model)
```swift
@Model class PersonTag {
    var id: UUID
    var contactIdentifier: String
    var displayName: String
    var thumbnailData: Data?
    
    init(id: UUID = UUID(), contactIdentifier: String, displayName: String, thumbnailData: Data? = nil) { ... }
}
```

### PhotoEntry.swift (@Model)
```swift
@Model class PhotoEntry {
    var id: UUID
    var localIdentifier: String?       // PHAsset identifier (reference mode) — unique in the digital album (see product constraints)
    var storedFilename: String?        // reserved for a future optional on-disk copy feature; nil in v1
    var storageMode: StorageMode
    var mediaKind: PhotoAssetKind      // `.image` or `.video` (from PHAsset at import)
    var isLivePhoto: Bool              // true → grid shows still only; detail uses Live Photo playback (Phase 5)
    var isInHomeAlbum: Bool            // true → appears in Home Grid/Timeline/Videos; false → can still be used in Stories
    var capturedDate: Date             // from PHAsset.creationDate (creation / EXIF intent)
    var loggedDate: Date               // date added to Cavira
    var notes: String?
    var locationTag: LocationTag?
    @Relationship(deleteRule: .nullify) var peopleTags: [PersonTag] = []
    var customTags: [String] = []
    
    // Store overlays as JSON-encoded Data
    var textOverlaysData: Data?        // encodes [TextOverlay]
    var stickerOverlaysData: Data?     // encodes [StickerOverlay]
    
    // Computed helpers
    var textOverlays: [TextOverlay] { get/set using JSONDecoder/Encoder on textOverlaysData }
    var stickerOverlays: [StickerOverlay] { get/set using JSONDecoder/Encoder on stickerOverlaysData }
    
    init(...) { ... }
}
```

**Repo note:** If the on-disk model predates `mediaKind` / `isLivePhoto`, add them when implementing **Phase 4** (with a lightweight migration / dev reset as appropriate for your branch).

**Repo (Phase 15):** `PhotoEntry` includes optional **`homeCollection`** (inverse of **`HomeCollection.entries`**) and **`collectionMemberOrder: Int?`** for stable paging/reorder. Members typically **`isInHomeAlbum == false`**; the collection tile holds the Home slot.

### HomeCollection.swift (@Model) — Phase 15 (shipped)
```swift
@Model final class HomeCollection {
    var id: UUID
    var title: String
    var homeOrderIndex: Int?
    var createdDate: Date
    @Relationship(deleteRule: .nullify) var entries: [PhotoEntry] = []
    // Helpers: coverEntry, orderedEntries — see repo
}
```

### StorySlide.swift (@Model)
```swift
@Model class StorySlide {
    var id: UUID
    var order: Int
    var photo: PhotoEntry?
    var backgroundColour: String?
    var textOverlaysData: Data?        // encodes [TextOverlay]
    var stickerOverlaysData: Data?     // encodes [StickerOverlay]
    
    var textOverlays: [TextOverlay] { get/set }
    var stickerOverlays: [StickerOverlay] { get/set }
    
    @Relationship(inverse: \Story.slides) var story: Story?
    
    init(...) { ... }
}
```

### Story.swift (@Model)
```swift
@Model class Story {
    var id: UUID
    var title: String
    var storyDescription: String?
    var storyDate: Date
    var locationTag: LocationTag?
    @Relationship(deleteRule: .nullify) var peopleTags: [PersonTag] = []
    var coverPhotoId: UUID?
    @Relationship(deleteRule: .cascade) var slides: [StorySlide] = []
    var isPinned: Bool = false
    var createdDate: Date
    var lastEditedDate: Date
    
    // Computed: sorted slides
    var orderedSlides: [StorySlide] { slides.sorted { $0.order < $1.order } }
    
    init(...) { ... }
}
```

### AppSettings.swift (@Model)
SwiftData’s `@Model` macro does not support shorthand enum defaults (like `= .reference`) on stored properties. Set defaults in `init` instead:
```swift
@Model class AppSettings {
    var id: UUID
    var defaultStorageMode: StorageMode
    var defaultHomeView: HomeViewMode
    var appearanceMode: AppearanceMode
    
    init() {
        id = UUID()
        defaultStorageMode = .reference
        defaultHomeView = .grid
        appearanceMode = .system
    }
}
```

## 3. Update CaviraApp.swift:
Set up the SwiftData modelContainer with all models:
```swift
.modelContainer(for: [PhotoEntry.self, Story.self, StorySlide.self, LocationTag.self, PersonTag.self, AppSettings.self])
```

## 4. Root placeholder (historical name in early repos: `ContentView.swift`):
Just a minimal single-screen placeholder (e.g. centred title text) until Phase 3 replaces it with **`RootView`** and the tab shell.

## 5. Add to Info.plist:
- NSPhotoLibraryUsageDescription: "Cavira needs access to your photo library to let you import and organise your photos."
- NSContactsUsageDescription: "Cavira uses your contacts so you can tag people in your photos."
- NSLocationWhenInUseUsageDescription: "Cavira can use your location to suggest place tags."

Do not create any views beyond that single placeholder root. Just models, enums, and the container setup. Make sure the project compiles with zero errors.
```

---

### Phase 1 Test Checklist
- [ ] Project compiles with zero errors and zero warnings
- [ ] All model files exist in the Models/ folder
- [ ] All enum types are defined and accessible
- [ ] CaviraApp.swift has the modelContainer with all 7 model types
- [ ] Info.plist has all 3 permission strings
- [ ] App runs on simulator (Phase 1: single-label placeholder; after Phase 3, the tab shell is the expected launch UI)

---

---

# PHASE 2 — Core Services
**Build tracker:** ✅ Complete

### Goal: All backend logic working before any real UI exists.

---

**Why before UI:** Views will call these services. If services are wrong, the views built on top of them will be wrong too. Test services independently first.

---

### Cursor Prompt — Phase 2

```
Implement core services under Services/ with iOS 18+ conventions: async/await, @MainActor where UI-adjacent state is published, Observation (@Observable) instead of ObservableObject where practical, and NO singletons — use dependency injection (see AppServices below). Do not create any new feature views beyond what already exists.

## AppServices.swift + Environment
- Define @MainActor @Observable final class AppServices holding: photoLibrary, photoImageLoader, photoStorage, locationSearch, contacts.
- Initialiser accepts optional overrides for tests/previews (nil = production implementation).
- Expose services through SwiftUI Environment (EnvironmentKey); root scene uses .appServices(AppServices()).
- Previews must inject .appServices(AppServices(...)).

## PhotoStorageService.swift (protocol + v1 stub)
- protocol PhotoStorageServing: totalStorageUsed(), deleteFile(named:)
- struct NoOpPhotoStorage: PhotoStorageServing — v1 does not write duplicate photos to disk (returns 0 bytes; delete is no-op).
- (Future phase) A real disk implementation may write to Application Support/CaviraPhotos/ for an optional localCopy mode — not part of v1.

## PhotoLibraryService.swift
- @MainActor @Observable
- authorizationStatus updated for authorised / limited / denied / restricted / notDetermined
- requestAuthorization() async -> PHAuthorizationStatus using PHPhotoLibrary.requestAuthorization(for: .readWrite)
- **Phase 4+ alignment:** `fetchAllAssets()` (or companion helpers) should be able to return **images and/or videos** as needed by Calendar / pickers — not images-only if the product requires video everywhere (see **Cavira UX direction**).
- asset(for localIdentifier:) -> PHAsset?

## PhotoImageLoader.swift
- @MainActor @Observable; init(photoLibrary: PhotoLibraryService)
- NSCache for decoded UIImages; clearCache()
- v1: **reference mode only** — load via PHImageManager. For thumbnails use requestImage (~200pt). For **still** full library pixels use requestImageDataAndOrientation (native HEIF/JPEG/etc. as in Photos). **Video:** load poster / first frame or use AVFoundation-backed playback from the **`PHAsset`** without writing to Application Support. **Live Photo:** grid/thumbnail uses still image request; detail uses **`PHLivePhoto`** request path (Phase 5). **localCopy:** return nil (no Cavira disk files in v1).
- loadImage(for:targetSize:), loadThumbnail(for:), loadFullLibraryImage(for:) — all async, never crash on missing asset

## LocationSearchService.swift
- Instagram-style on Apple’s stack only (no Google Places API in v1): **MKLocalSearchCompleter** for suggestions as the user types, debounced ~280ms with Task cancellation when the query changes.
- results: [LocationResult] where each row has stable **UUID** id; name/subtitle from MKLocalSearchCompletion; lat/lon 0 until resolved.
- resolveSelection(id:) async -> LocationResult? uses **MKLocalSearch.Request(completion:)** to fetch coordinates and, on iOS 18+, MKMapItem.identifier?.rawValue as mapKitPlaceID when available.
- clear() resets completer and results.

## ContactsService.swift
- @MainActor @Observable; CNContactStore; published authorizationStatus
- requestAuthorization() async
- search(query:) using CNContact.predicateForContacts(matchingName:) + unifiedContacts (cap ~50 results; no special huge-address-book pass for v1)
- contact(for identifier:) async -> ContactResult?

## DataService.swift
- enum DataService { static methods … }
- Same query helpers as before; deletePhotoEntry(_:context:photoStorage:) takes any PhotoStorageServing (NoOp in v1).

Compile with zero errors. No new tab/feature views.
```

---

### Phase 2 Test Checklist
- [ ] All **7** Swift files exist under `Services/` (includes `AppServices.swift`)
- [ ] Project compiles with zero errors
- [ ] `AppServices` is created in `CaviraApp` and injected with `.appServices(...)` on the root view
- [ ] `#Preview` for the root shell (e.g. `RootView`) injects **`AppServices()`** (and a preview **`modelContainer`** when SwiftData is used) so previews do not hit `preconditionFailure`
- [ ] `PhotoLibraryService` updates `authorizationStatus` after `requestAuthorization()`
- [ ] `PhotoImageLoader` returns nil for `localCopy` entries (v1)
- [ ] `NoOpPhotoStorage` reports `0` bytes used
- [ ] `LocationSearchService` builds with MapKit (Completer + resolving search)
- [ ] `ContactsService` builds with Contacts framework
- [ ] `DataService` helpers compile against SwiftData

---

---

# PHASE 3 — Tab Shell & Navigation
**Build tracker:** ✅ Complete

### Goal: The app has 5 tabs with placeholder screens. Navigation works end to end.

---

**Why before content:** Validates that the navigation structure is sound before filling it with real content. Cheaper to restructure tabs now than after 10 views are built on top.

**Implemented conventions:** See **“Cavira v1 UI & shell decisions”** above (iPhone-only, one stack per tab, `RootView`, `AppSettings` + explicit `save()`, Instagram-style home segments, English copy, preview helper, no deep links). **Product layout** evolves under **“Cavira UX direction”** (e.g. second tab label **Calendar**, Home **Grid \| Timeline \| Videos**). **Colour system:** **`CaviraTheme`** palettes + hex tokens are documented here (see **Theme palettes — options + hex codes (implemented)**).

---

### Cursor Prompt — Phase 3

```
Build the navigation shell. All tab bodies are placeholders for now. Follow the repo decisions in the guide section “Cavira v1 UI & shell decisions (Phase 3)”.

## RootView.swift
- Hosts the `TabView` with the five tabs below.
- `@Environment(\.modelContext)` + `.onAppear { _ = DataService.getOrCreateSettings(context:) }` so a default `AppSettings` row exists (see DataService note on `save()` after first insert).

## CaviraApp.swift
- `WindowGroup { RootView(appServices: appServices).modelContainer(for: [...]) }` (same model list as previews); `RootView` applies `.environment(\\.appServices, appServices)` on the `TabView`.

## TabView (inside RootView)
Mirror `RootView`: `HomeTab`, `CalendarTab`, `StoriesTab`, `SearchTab`, `SettingsTab`; `Label` text for the second tab should read **Calendar** (system image `calendar` is fine).

## One NavigationStack per tab (no nesting)
- **`*Tab.swift`:** each file is ONLY `NavigationStack { <Screen>() }`.
- **Inner screens** (`HomeScreen`, calendar month placeholder view, …): **no** inner `NavigationStack`; use `.navigationTitle` / toolbar on the content inside the tab’s stack.

### Views/Home/HomeScreen.swift
- Centred `Text("Home")` (or equivalent placeholder).
- `.navigationTitle("Home")`, `.navigationBarTitleDisplayMode(.inline)`.
- **Instagram-style** segmented `Picker` for **Grid \| Timeline \| Videos** (drop Profile segment per **Cavira UX direction**); bind to `HomeViewMode` until enum is trimmed.

### Views/Calendar/ (Calendar shell until refactor)
- User-facing title **Calendar**; placeholder body until Phase 4–6 (month grid + counts from Photos).

### Views/Stories/StoriesListView.swift
- `Text("No stories yet")`, `.navigationTitle("Stories")`.

### Views/Search/SearchView.swift
- `Text("Search placeholder")`, `.navigationTitle("Search")`.

### Views/Settings/SettingsView.swift
- `Text("Settings placeholder")`, `.navigationTitle("Settings")`.

## CaviraPreviewSupport.swift
- Shared in-memory `ModelContainer` for all `@Model` types.
- `caviraPreviewShell()` = `modelContainer(...)` + `.environment(\\.appServices, AppServices())` (optional `AppServices?` in `EnvironmentValues`).
- Every `#Preview` for a tab or screen that needs SwiftData + services uses `.caviraPreviewShell()`.

## Dependency injection (Phase 2 `AppServices`)
- **Do not** introduce `static let shared` for services.
- Tab roots and children read **`@Environment(\.appServices)`** (or pass `AppServices` explicitly) when needed.
- Phase 4+ import and home screens will call `environment.appServices.photoLibrary`, `.photoImageLoader`, etc.

## Accessibility
- Use `.accessibilityElement(children: .combine)` / `.accessibilityLabel` on simple placeholder groups where it helps VoiceOver.

The app should compile and run. All 5 tabs tappable with placeholder text and correct navigation titles.
```

---

### Phase 3 Test Checklist
- [ ] App launches and shows 5 tabs at the bottom
- [ ] All 5 tabs are tappable with correct icons and labels
- [ ] Each tab shows its placeholder text
- [ ] Navigation titles display correctly (single stack per tab — no double stacks)
- [ ] Home tab shows the Instagram-style segmented control (**Grid / Timeline / Videos**) in the nav bar; selection state may be local-only until a later phase
- [ ] `RootView` `onAppear` ensures `AppSettings` exists; first-run insert is followed by **`ModelContext.save()`** inside `DataService.getOrCreateSettings`
- [ ] `AppServices` remains injected on the root scene
- [ ] `#Preview` for tab/screen files uses **`.caviraPreviewShell()`** (or equivalent) so previews do not `preconditionFailure`
- [ ] No crashes

---

---

# PHASE 4 — Photo Import Flow
**Build tracker:** ✅ Complete

### Goal: User can add **photos and videos** from Apple Photos into Cavira’s **digital album** as **`PhotoEntry` references** only — correct `mediaKind`, **Live Photo** flag, **no duplicate rows** per `localIdentifier`, and **no duplicate files** on disk.

---

**Why before displaying photos:** Can't show a grid or timeline without `PhotoEntry` rows. **Add** (picker + Add sheet) is the entry point for curated album content. **Calendar** (Phase 6) still reads the **whole library** by date separately — no mass import on launch (see **Cavira UX direction → Calendar tab**).

---

### Cursor Prompt — Phase 4

```
Build the photo import flow. This is the core content entry point for the digital album.

## Models (if not already in repo)
- Add `PhotoAssetKind` (`image`, `video`) and on `PhotoEntry`: `mediaKind`, `isLivePhoto` (see Phase 1 spec). Derive from `PHAsset.mediaType` and `PHAsset.mediaSubtypes.contains(.photoLive)` at import.

## Views/Photo/PhotoPickerRepresentable.swift (or PhotoImportFlow.swift — pick one clear name)
Wrap `PHPickerViewController` with `UIViewControllerRepresentable`.
- Multi-select enabled (no practical limit)
- Filter: **images, Live Photos, and videos** (UTType / PHPicker filter — match Instagram-style “anything from library”)
- On completion: pass `[PHPickerResult]` to SwiftUI via callback / binding

Use a small coordinator pattern; dismiss picker after confirm.

**Implementation note (sheet stability):** When the user flow is **Picker → ImportOptionsSheet**, present them as a **single sheet state machine** (e.g. an enum + `.sheet(item:)`) rather than two separate `.sheet(isPresented:)` modifiers. This avoids first-run sheet races where `ImportOptionsSheet` may briefly render with the wrong `pickerResults` or dismiss unexpectedly.

**Implementation note (sheet identity):** If you use `.sheet(item:)` with an enum-backed item, keep the `id` **stable for the lifetime of the presented sheet**. A computed `id` like `UUID()` on every render will cause the sheet (and its internal `@State`, like free-text people tags) to reset on any parent re-render.

## Views/Photo/ImportOptionsSheet.swift
After the user picks assets, show this sheet before writing SwiftData:

- Title: dynamic count — e.g. **"Add 12 items"** (photos + videos)
- **One-page Add flow order:** **Title → Location → People**
  - **Title**: only when adding **1 item** (saved to `PhotoEntry.title`) — **required**; label shows **Title*** and if the user taps **Add** with it empty, highlight the field in **red** and show a short required message
  - **Location**: MapKit search + suggestion list; selecting a row creates/reuses a `LocationTag` and will be applied to all added items
  - **People**: Contacts search (if permitted) + free-text add; selected tags are applied to all added items (with default placement)
- Primary **"Add"** and **"Cancel"**

## Add logic (ViewModel or sheet-owned):
Use `@Environment(\.appServices)` → `PhotoLibraryService` + `ModelContext`.

For each `PHPickerResult`:
1. Resolve `localIdentifier` (assetIdentifier / itemProvider patterns supported by PHPicker + your iOS target).
2. `guard let asset = photoLibrary.asset(for: id)` else skip.
3. `capturedDate = asset.creationDate ?? Date()`
4. **Dedupe:** if a `PhotoEntry` with the same `localIdentifier` already exists, update it in-place (e.g. set `isInHomeAlbum = true` if this was a Story-only item) — user must never get duplicate references to the same library asset.
5. Insert `PhotoEntry(storageMode: .reference, localIdentifier: id, storedFilename: nil, mediaKind: …, isLivePhoto: …, isInHomeAlbum: true, …)`.
6. `try` `context.save()` — surface failures to the user where reasonable (avoid silent drop of whole batch).

## Photo permission — app launch + import
- On **first launch / root appearance** (e.g. `RootView.onAppear` or `CaviraApp` task): call **`PhotoLibraryService.requestAuthorization()`** (or a thin wrapper `requestAuthorisationIfNeeded() async -> Bool` that returns **true** for `.authorized` / `.limited`). **iOS persists** the user’s choice; optional **`AppSettings`** flag only for **UX copy** (“we’ve already asked”), not for security state.
- If user denies / restricted: when they hit **Add** or `+`, show alert with **Open Settings** → `UIApplication.openSettingsURLString` (allowed; not a product “deep link”).

## HomeScreen.swift — entry point (overlay `+`, not nav bar)
- **`+`:** top-trailing on the **main content** (overlay / `ZStack`), **not** `ToolbarItem` / navigation bar. Tapping presents picker → `ImportOptionsSheet`. **Do not** use a bottom-right FAB for the primary add control.

## RootView / tab bar — optional global add
- **Stretch:** implement a **centre tab-bar `+`** that invokes the **same** picker → options → import pipeline from **any tab**, without breaking “one NavigationStack per tab”. Document in code where the shared flow lives (e.g. small `ImportCoordinator` observable, or scene-level `@State` passed via environment).

## (Removed) EventDetailView
- No separate “event” feature in the product direction; keep Story builder as the grouping mechanism.

## PhotoLibraryService
- Keep `requestAuthorization()`; add **`requestAuthorisationIfNeeded() async -> Bool`** as a convenience if useful (authorised **or** limited → true).
- Ensure helpers support resolving **video** and **live** assets.

End-to-end: after import, SwiftData contains one row per added library id; thumbnails can wait for Phase 5.
```

---

### Phase 4 Test Checklist
- [ ] Photos permission is requested **at app launch** (early root) and **not** only the first time user taps `+`
- [ ] **Top-trailing `+` on Home content** (not navigation bar) starts picker → options sheet → save
- [ ] (Optional) Centre tab **`+`** starts the same flow from another tab
- [ ] Picker supports **multi-select** of **stills, Live Photos, and videos**
- [ ] Add sheet shows **Title → Location → People** in that order (Title only for 1 item)
- [ ] When adding **1 item**, **Title is required** and the sheet provides clear red validation if the user taps **Add** while empty
- [ ] Each saved `PhotoEntry` has `storageMode == .reference`, `localIdentifier` set, `storedFilename == nil`, correct **`mediaKind`**, correct **`isLivePhoto`**
- [ ] **Re-importing the same asset** does **not** create a second `PhotoEntry`
- [ ] `capturedDate` matches library creation date for a known asset
- [ ] Denied / restricted Photos shows alert with **Open Settings**

---

---

# PHASE 5 — Home Screen (Grid, Timeline & Videos)
**Build tracker:** ✅ Complete (includes **Videos** segment: video-only grid)

### Goal (shipped): Home has **Grid**, **Timeline**, and **Videos** segments with a curated album and reference-only media. **Planned refinement:** Phase 13 makes Grid/Timeline photos-only and introduces segment-aware import (photo-only vs video-only).

---

### Cursor Prompt — Phase 5

```
Build the Home screen with working **Grid**, **Timeline**, and **Videos** views. Items imported in Phase 4 (`PhotoEntry` with `mediaKind` / `isLivePhoto`) should now be visible.

**Naming:** use **`AlbumTimelineView`** for the month-grouped timeline — **not** `TimelineView` (SwiftUI’s built-in schedule API).

**Navigation:** **`HomeTab`** already owns the lone **`NavigationStack`** per tab — **`HomeScreen` must not wrap a second stack**; use **`navigationDestination(for: UUID.self)`** (or equivalent) for **`PhotoDetailView`**, Instagram-style **push → Back** to the album.

## Views/Home/HomeScreen.swift — full implementation

State:
- `@Query` `PhotoEntry` sorted by **`capturedDate` descending**
- Home views should filter to `PhotoEntry.isInHomeAlbum == true` so Story-only items do not appear on Home.
- `@State` **Grid \| Timeline \| Videos** mode: initialise from **`AppSettings.defaultHomeView`** on appear; **persist** back to `AppSettings` whenever the user changes the segmented control (coerce `.profile` → `.grid` until the enum is removed)
- Keep Phase 4 **top-trailing content `+`** overlay (not in the nav bar)

Layout:
- **Navigation title:** **"Cavira"** (product choice)
- **Toolbar `.principal`:** segmented **Grid \| Timeline \| Videos** (no Profile segment)
- Content: **`AlbumTimelineView`** for **Timeline** (**photos-only**); **`GridView`** for **Grid** (**photos-only**) and **Videos** (`filter { $0.mediaKind == .video }`, with distinct **EmptyStateView** copy when the album has photos but no videos)
- **Remove from album:** context menu on thumbnails + detail menu; **`confirmationDialog`** copy must state removal is **Cavira-only** — **no** deletion from Apple Photos (see product constraints)

## Views/Home/GridView.swift

- LazyVGrid with 3 columns, **4pt** spacing (tight, like Instagram) **plus 4pt horizontal padding** so thumbnails have a subtle gutter at the edges too; support optional **empty title / subtitle** for reuse from **Videos** mode
- Each cell: PhotoThumbnailView(entry: photo) — square, fills cell width; **videos** show a play-badge overlay (Videos segment); **Live Photos** use **still** thumbnail only
- Sort: photos already sorted by capturedDate descending from parent
- On tap: navigate to PhotoDetailView(entry: photo)
- Empty state: **`EmptyStateView`** — title **"Import your media to start"** (photos + videos)

## Views/Home/AlbumTimelineView.swift

- `ScrollView` + **`LazyVStack`** grouped by **month + year** of `capturedDate`
- For each group: section title **"June 2024"** (bold, large) — **non-sticky** headers are acceptable for v1; **sticky month headers** (`List`/`Section` or custom) are a **Phase 12** polish item if we want parity with calendar-style scrolling
- Under each header: a **2-column** `LazyVGrid` of `PhotoThumbnailView` cells
- On tap: navigate to PhotoDetailView(entry: photo)
- Empty state: same **`EmptyStateView`** copy as Grid

## Views/Components/PhotoThumbnailView.swift

```swift
struct PhotoThumbnailView: View {
    let entry: PhotoEntry
    @State private var image: UIImage? = nil
    
    var body: some View {
        // Square ZStack
        // Load thumbnail async via @Environment(\.appServices).photoImageLoader.loadThumbnail(for: entry)
        // Show ProgressView while loading
        // Show image when loaded (fill frame, .scaledToFill, .clipped)
        // If image is nil after load attempt: show a grey placeholder with photo SF Symbol
    }
}
```

## Views/Components/EmptyStateView.swift

```swift
struct EmptyStateView: View {
    var systemImage: String = "photo.on.rectangle"
    var title: String
    var subtitle: String?
    // Centred, grey, SF Symbol above title, subtitle below
}
```

## Views/Photo/PhotoDetailView.swift — basic version (we'll add tags in Phase 7)

- **Instagram-style navigation:** push from grid/timeline; **Back** returns to the album — no swipe-to-dismiss requirement if it conflicts with horizontal paging later
- Full-screen **black** backdrop; **still** image via `PhotoImageLoader`; **Live Photo:** **`PHLivePhotoView`** via **`UIViewRepresentable`** with **`PHLivePhoto`** from `PHAsset` — **system / iOS Photos-style** interaction (long-press where appropriate)
- **Video:** **`VideoPlayer`** with `AVPlayer` / `PHImageManager.requestPlayerItem(forVideo:)` — no Cavira file copy
- Navigation title: captured date (e.g. **"12 June 2024"**)
- Notes + event name in a bottom **safe-area inset** when present
- Toolbar **⋯** menu: **Edit** (opens `EditTagsSheet`), **Share** (native iOS share sheet), **Remove from album** (same Apple Photos disclaimer as Home)
- **Do not** implement tagging yet — Phase 7

```

---

### Phase 5 Test Checklist
- [ ] **Navigation title** reads **"Cavira"**; **Grid \| Timeline \| Videos** sits in the **toolbar principal** only
- [ ] **Grid \| Timeline \| Videos** choice **persists** across launches via **`AppSettings.defaultHomeView`**
- [ ] **Grid** shows imported **photos and videos** in a 3-column grid (video cells identifiable, e.g. play badge)
- [ ] **Videos** shows **only** video `PhotoEntry` rows; empty state explains **No videos yet** when the album has items but no videos
- [ ] **Live Photos** show **still** thumbnails in grid/timeline only
- [ ] **Album timeline** shows items grouped by month with section headers (**sticky** headers optional — Phase 12)
- [ ] Toggling between **Grid / Timeline / Videos** updates the view
- [ ] Tapping an item **pushes** `PhotoDetailView`; **Back** returns to the album (Instagram-style)
- [ ] PhotoDetailView shows **still / Live / video** appropriately (Live motion in detail; **video** plays inline)
- [ ] Thumbnails load asynchronously (no UI freeze)
- [ ] Empty state uses **"Import your media to start"** when the **whole** album is empty; **Videos** uses **"No videos yet"** (+ subtitle) when the album has items but **no** video rows
- [ ] **Remove from album** (context menu / detail menu) only deletes **`PhotoEntry`**; copy confirms **Apple Photos** is untouched
- [ ] **Top-trailing content `+`** (Phase 4) still reaches import from Home; **Grid / Timeline / Videos** do not add a second conflicting FAB or duplicate `+` in the nav bar

---

---

# PHASE 5.5 — CaviraTheme (Ranger)
**Build tracker:** ✅ Complete

### Goal: One canonical dark visual system for Cavira — **Ranger** tokens in **`CaviraTheme`**, global UIKit chrome, **`AccentColor`** = **`#D4B96A`**, and SwiftUI surfaces wired to tokens (no ad-hoc colours outside `CaviraTheme.swift`). **No** light mode, **no** system appearance toggle, **no** multi-palette “theme picker” in later phases unless explicitly reopened in **Phase 12**.

---

### Cursor Prompt — Phase 5.5

```
Ship the Ranger visual system as Cavira’s only v1 skin.

## Theme/CaviraTheme.swift (new)
- Define **`enum CaviraTheme`** (or `struct` if you prefer) with token colors centralized in one place (use `Color(hex: "#……")`).
- Include nested **Typography**, **Radius**, **Spacing** per the spec.
- Add **`applyGlobalChrome()`** using `UITabBar.appearance()`, `UINavigationBar.appearance()`, `UISegmentedControl.appearance()`, `UITableView.appearance()` (and any other UIKit chrome that still shows through SwiftUI) so system controls match Ranger.
- Keep the **`Color` + hex parser** in this file only — nowhere else in the app should parse hex strings.

## CaviraApp.swift
- `import UIKit`
- Call **`CaviraTheme.applyGlobalChrome()`** from `init()` before first frame.

## RootView.swift
- Behind **`TabView`**: full-screen **`CaviraTheme.backgroundPrimary`**.
- **`.preferredColorScheme(.dark)`** — v1 is Ranger-dark only; do **not** wire **`AppSettings.appearanceMode`** yet (document as deferred to Phase 12 if product wants it).
- **`.tint(CaviraTheme.accent)`** on the root hierarchy.

## Assets.xcassets/AccentColor
- Set sRGB to **`#D4B96A`** (Ranger accent) so system **`Color.accentColor`** matches **`CaviraTheme.accent`**.

## Views
- Migrate Home (**Grid \| Timeline \| Videos**), grid, timeline, thumbnails, empty states, import sheet, placeholder tabs, and photo detail chrome to **`CaviraTheme`** tokens (backgrounds, text hierarchy, progress **`.tint(accent)`**, toolbar backgrounds where needed).
- **`ImportOptionsSheet`:** hide default form material (**`.scrollContentBackground(.hidden)`**), use **`backgroundSecondary`** / **`surfaceCard`** rows, **Cancel** = secondary text colour, **Add** = accent semibold.

## Xcode project
- Add **`Theme/CaviraTheme.swift`** to the **Cavira** target (Compile Sources).

## Explicit non-goals (do not build now)
- No **light mode** or **System** appearance from Settings.
- No **`ThemePalette`**, army green / black / white theme switcher, or second colour system.
```

---

### Phase 5.5 Test Checklist
- [ ] **`CaviraTheme`** exists; tokens are centralized and documented in this file
- [ ] **`AccentColor`** asset matches **`#D4B96A`**
- [ ] **`applyGlobalChrome()`** runs at launch; tab bar + nav bar + segmented control read as Ranger (not raw iOS defaults)
- [ ] **`RootView`** uses **`backgroundPrimary`**, **`.preferredColorScheme(.dark)`**, **`.tint(accent)`**
- [ ] Home, grid, timeline, import sheet, placeholders, and detail loaders use theme tokens (no stray `Color(red:…)` / hex outside `CaviraTheme.swift`)
- [ ] Project file includes **`CaviraTheme.swift`** in the app target

---

---

# PHASE 6 — Calendar (activity + day drill-in + recap)
**Build tracker:** ✅ Complete

### Goal: The **Calendar** tab is a read-only **activity calendar** over the user’s Apple Photos library (**photos only**):
- **Month grid** shows a **number badge per day** = how many photos were captured that day.
- Tapping a day opens a **day grid** of that day’s photos.
- **Below the calendar**, show a **Recap** module (“On this date” / “This month”) that auto-plays past photos with a fade every ~5 seconds.

Calendar stays **separate** from Cavira’s curated album: it reads `PHAsset` live and does **not** mass-import into SwiftData.

---

### Cursor Prompt — Phase 6

```
Build the Calendar month surface (tab is user-facing "Calendar") as a read-only view over `PHAsset` creation dates.

## Views/Calendar/CalendarView.swift (or keep existing file names until refactor)
- Month grid UI: each day shows a numeric badge = number of assets captured that day.
- Month navigation: prev/next chevrons + “Go to month” sheet (graphical DatePicker + Jump to today).
- Permission footnotes: Limited / Not determined messaging stays.

## Views/Calendar/DayDetailView.swift
- When user taps a day, show a grid of that day’s `PHAsset` photos.
- From this day view, user can optionally import selected items into Cavira’s album (creating `PhotoEntry` references) using the existing import pipeline.

## Views/Calendar/RecapCarouselView.swift
- Shown below the month grid.
- Data source: `PHAsset` (read-only).
- Behaviour: auto-advance every ~5 seconds with a fade transition.
- Modes:
  - “On this date” (same day/month, prior years) when available.
  - Otherwise “This month” (same month in prior years).

## PhotoLibraryService (Phase 2 extension)
- `assetCountsByDayInMonth(containing:)` returns counts per day for the month grid (photos only).
```

---

### Phase 6 Test Checklist
- [ ] Calendar month grid shows per-day capture counts (Photos-backed)
- [ ] Tapping a day opens a day grid view for that date
- [ ] Recap carousel appears under the calendar and auto-advances with a fade (~5s)
- [ ] Recap correctly chooses “On this date” when available, otherwise “This month”
- [ ] Optional: from day detail, user can import selected assets into Cavira album (no mass import)

---

---

# PHASE 6.1 — Calendar year / month navigation
**Build tracker:** ✅ Complete

### Goal: Faster navigation than **month-by-month chevrons** alone — e.g. **year picker**, **month picker**, or a compact **two-level** control so users can jump the **library activity** grid to arbitrary months without excessive tapping.

### Shipped (repo)
- **`LibraryMonthCalendarView`:** Tapping the **month title** (with chevron affordance) presents a sheet: **graphical `DatePicker`** (wide year/month jump), **Jump to today’s month**, **Cancel** / **Go**. **Prev/next month** buttons unchanged. `displayedMonth` is normalised to the **first day** of the chosen calendar month (local calendar).
- **Calendar root view:** Unchanged API; **`.task(id: displayedMonth)`** still reloads **`assetCountsByDayInMonth(containing:)`** when the user confirms a jump.

### Cursor Prompt — Phase 6.1 (outline)

```
Extend `LibraryMonthCalendarView` / the Calendar root view:
- Extend `LibraryMonthCalendarView` / the Calendar root view:
- Add UI to jump **year** and **month** explicitly (system `DatePicker` in `.compact` / `.graphical` wheels, or custom menu).
- Keep existing per-day counts behaviour; refresh counts when `displayedMonth` changes.
- Stay on **read-only `PHAsset`** counts (no SwiftData bulk import).
```

### Phase 6.1 Test Checklist
- [ ] User can change **year** without tapping prev-month 12 times
- [ ] User can change **month** within the selected year intuitively
- [ ] Counts refresh correctly after jumps (`assetCountsByDayInMonth`)

---

---

# PHASE 7 — Tagging (Location + People)
**Build tracker:** ✅ Complete

### Goal: Users can tag photos with **places** and **people** (Contacts-backed or free text). Tags are searchable (Phase 8).

---

### Cursor Prompt — Phase 7

```
Build the full tagging system. Tags are applied to PhotoEntry records.

## Views/Photo/EditTagsSheet.swift

A sheet that slides up from PhotoDetailView (**photo detail only**). This is the user’s **Edit** sheet for a photo and includes:
- **Details**: a short **Title** field (saved on `PhotoEntry.title`)
- **Location**: MapKit-powered place search (saved as `LocationTag`)
- **People**: Contacts-backed or free-text people tags (saved as `PersonTag` + per-photo placements)

### Section 1: Location Tag
- Search field bound to `@Environment(\.appServices).locationSearch`
- As user types, `LocationSearchService.search(query:)` updates suggestions (Completer + debounce from Phase 2)
- Each row shows place name + subtitle; coordinates fill in after **`resolveSelection(id:)`** runs when the user taps a row (Instagram-style: suggestion first, then MapKit resolution)
- Tap resolved row → create or reuse a `LocationTag` (name, lat/lon, `mapKitPlaceID` when iOS 18+ provides it), assign to `photo.locationTag`
- Show currently applied tag as a chip with an "×" remove button
- "Search powered by Apple Maps" attribution (required by MapKit terms)

### Section 2: People Tags
- Search field bound to `@Environment(\.appServices).contacts`
- Results show contact avatar (from thumbnailData or initials fallback) + name
- Tap to add — multiple people can be tagged
- Show applied people as a horizontal scroll of chips with avatar + name + "×"
- If Contacts permission not granted: show "Allow Contacts access" button that calls ContactsService.requestAuthorization()
- Also allow **free-text people tags** (not saved as Contacts): user types a name and taps **Add** (or return) to create a PersonTag with no `contactIdentifier`.
- People tags are **placed on the image** (Instagram-style): tags are **hidden by default** and appear only when the user taps the photo.

## Views/Components/TagChipView.swift

```swift
struct TagChipView: View {
    var label: String
    var icon: String? = nil     // SF Symbol name, optional
    var onRemove: (() -> Void)? = nil  // if nil, chip is non-interactive (display only)
    // Pill shape, grey background, small font, optional remove button
}
```

## Update PhotoDetailView:
- **Edit** menu action opens `EditTagsSheet`.
- **Location display:** show location on a **new line under the date** in the header when set.
- **People display:** render people tags as **overlays on the photo** at saved positions; **hidden until the user taps the image**, then they fade/appear.
- Tag editing happens in the sheet; placement can be updated from the detail view (tap-to-place/update).

## LocationSearchService (Phase 7 wiring):
Reuse the Phase 2 implementation; ensure list rows call `resolveSelection` before persisting a `LocationTag`. If the query is empty, `clear()` runs immediately.

## Contacts permission handling:
If the user denies Contacts, show a non-blocking banner in the People section explaining how to enable it in Settings. Do not block the rest of the sheet.
```

---

### Phase 7 Test Checklist
- [ ] EditTagsSheet opens from PhotoDetailView
- [ ] Location search returns real results from MapKit
- [ ] Selecting a location creates a LocationTag and assigns it to the photo
- [ ] Location appears under the date in PhotoDetailView when set
- [ ] Removing a location tag clears it from the photo
- [ ] Contacts search works (requires Contacts permission)
- [ ] Multiple people can be tagged on one photo
- [ ] Free-text people tags can be added (no Contacts permission required)
- [ ] People tags are hidden until tapping the image, then appear as overlays
- [ ] All tags persist after closing and reopening the sheet

---

---

# PHASE 8 — Search
**Build tracker:** ✅ Complete

### Goal: Users can search across their **Cavira digital album** and metadata — e.g. **location**, **person**, “**everything with this person**”, **family**-style groupings, **selfies** (via tags / future heuristics), custom tags, notes, dates, and Stories.

---

### Cursor Prompt — Phase 8

```
Build the Search feature. Users can find photos by location, person, custom tag, date range, and other metadata (see Goal — support rich recall like family sets and selfies where tagging allows).

## Views/Search/SearchView.swift — full implementation

Layout:
- Search bar at top (**custom**, always visible; **not** SwiftUI `.searchable`) with:
  - Inline clear for just the query text
  - A trailing **X** button that resets **query + filters + sort**
- Filter chips row below search bar: "Location" | "People" | "Date" | "Story" (tappable)
- Sorting: toggle **Newest** / **Oldest**
- Results grid below (same PhotoThumbnailView 3-column grid)
- Result count label: "X photos found"

Search logic:
- Scope: search only Cavira’s **album** (`PhotoEntry` in SwiftData), not the full Photos library.
- Text input searches across: `photo.title`, `photo.notes`, `locationTag.name`, `personTag.displayName`, story title (via slide → story relationship)
- Text input searches across: `photo.title`, `photo.notes`, `locationTag.name`, `personTag.displayName`, story title (via slide → story relationship)
- Filter chips narrow results further
- "Location" chip: pick from existing `LocationTag` rows (quick picker)
- "People" chip: pick from existing `PersonTag` rows (includes free-text people, not only Contacts)
- "Date" chip: show a date range picker (start date + end date)
- "Story" chip: pick from existing `Story` rows

All filtering happens client-side using SwiftData @Query or in-memory filter on fetched results. For v1, fetch all photos and filter in Swift — do not use complex NSPredicate unless the dataset is clearly too large.

## Views/Search/FilterResultsView.swift
Reuse the same 3-column grid pattern from GridView. On photo tap → PhotoDetailView.

## Views/Components/DateHeaderView.swift
(Reusable for both **`AlbumTimelineView`**-style grouping and any grouped search results)
```swift
struct DateHeaderView: View {
    var date: Date
    var style: DateHeaderStyle = .monthYear  // .monthYear | .fullDate
    // Displays "June 2024" or "12 June 2024" as a bold section label
}
```

Search should feel instant for typical library sizes (up to ~2000 photos). No loading spinner needed unless filtering takes >200ms.
```

---

### Phase 8 Test Checklist
- [ ] Typing in search bar filters photos in real time
- [ ] Location filter picker filters correctly
- [ ] People filter picker filters correctly
- [ ] Date range filter works
- [ ] Story filter works
- [ ] Sorting toggle (Newest/Oldest) works
- [ ] Tapping a result photo opens PhotoDetailView
- [ ] Result count label is accurate
- [ ] Clearing search shows all photos again
- [ ] Empty state shown if no results match

---

---

# PHASE 9 — Stories (Viewer & Builder)
**Build tracker:** ✅ Complete

### Goal: Users can create Instagram-style Stories (photos) that play like a slideshow of a single memory (holiday / day out / graduation) without creating a separate media store. (Mixed photo+video slides are shipped in **Phase 14**.)

**List UX (current implementation):** **StoriesListView** is a **vertical scroll** of **110pt-tall horizontal cards** using `StoryCardView` (cover on the left, metadata on the right), split into **Pinned** and **Recent** sections when pinned stories exist. Toolbar `+` creates a new story; tapping a card opens `StoryViewerView`. Each card has an anchored **actions menu** (iOS-style) on a **pencil-circle** button with a larger hit target (Edit / Pin / Delete).

**Details UX (current implementation):** Story details (`StorySaveView`) shows **Title*** as required and uses **inline red validation** (“Title is required.”) when the user taps **Save** without a title.

**Product decisions (locked for v1):**
- Stories are the only narrative/grouping layer in v1.
- **No photo-less slides** in v1.
- **Slide order:** fixed by **date taken** (asset creation date); **no manual reorder** in v1.
- **Playback timing:** **10 seconds per slide** by default; user can advance manually.
- **Exit gesture:** **swipe up** exits the viewer (like Instagram). Close (×) remains available.
- **Pinning:** defer all story pinning + Profile bubbles to **Phase 11** (not Phase 9).

---

**This is the most complex phase. Take it slowly and test after each sub-step.**

---

### Cursor Prompt — Phase 9

```
Build the Stories feature. This is the most complex part of the app. Build it in this order:

Product layout reminders (see Cavira UX direction):
- Shelf of story cards; cover defaults to first slide but user can pick another.
- Stories are the only narrative/grouping layer; no linking to a separate “events” concept.

## Step 9a — Story Viewer first (simpler, validates data model)

### Views/Stories/StoryViewerView.swift
- Full screen, black background
- Displays slides in order using TabView with .tabViewStyle(.page) and indexDisplayMode .never
- Each slide: **photo or video** fills screen (.scaledToFill), text overlays and stickers rendered on top
- Progress bar at top: thin line segmented into N segments (one per slide), current fills from left to right
- Auto-advance: each slide shows for **10 seconds** then moves to next (use Timer)
- Tap left half: go back one slide. Tap right half: go forward one slide.
- Pause on long press (hold finger down)
- Close button (×) in top-right
- Story title shown at top-left with a subtle gradient behind it
- Swipe up: exit the viewer (dismiss)

### Views/Stories/SlideRenderView.swift (reusable component)
Renders a single StorySlide:
- Background: photo/video (reference or copy, loaded via PhotoImageLoader / Photos-backed video playback) fills frame
- Text overlays: positioned using normalised coordinates (positionX * frameWidth, positionY * frameHeight)
- Sticker overlays: same positioning, scale applied
- In viewer mode: all overlays are non-interactive (display only)
- In editor mode: overlays are draggable/resizable (see Step 9b)

## Step 9b — Story Builder

### Views/Stories/StoryBuilderView.swift
Navigation flow:
1. SlidePickerView — pick photos → creates StorySlide records
2. For each slide: SlideEditorView — add overlays
3. StoryPreviewView — preview before saving
4. Save → creates Story record in SwiftData

### Views/Stories/SlidePickerView.swift
- Grid of the user’s **Photos library** photos for selection (Photos-backed, not limited to Home album). (Normal story building adds videos in **Phase 14**; Calendar-scoped builder stays photos-only.)
- **Grid layout:** **uniform 3-column** square cells (Instagram-style crop), with tight spacing; no uneven / spanning cells.
- Multi-select enabled — tap to select/deselect; selected cells show a **numbered** badge that reflects selection order.
- **Selected strip:** a horizontal strip of selected items appears at the top with **numbered thumbnails**; user can **remove** items and **drag-to-reorder** the strip (grid badges update live).
- **Sort toggle:** **Date taken** ascending / descending only; grid re-sorts immediately.
- **Album switcher label:** show an **Albums** affordance in the header (even if it’s a no-op in v1) so there’s a clear future entry point for switching sources (especially for **videos** / future album filtering).
- "Next" button → proceeds to slide editors
- Capture button (camera): take a photo/video and add it to the current story
  - Must save into **Apple Photos** first (no Cavira-private capture store), then include it as a selectable library item.

### Views/Stories/SlideEditorView.swift
Per-slide editor — this is the core creative screen:

Layout:
- Slide preview fills top ~65% of screen (SlideRenderView in edit mode)
- Bottom toolbar has:
  - "Text" button → adds a new TextOverlay with default position centre
  - "Sticker" button → opens sticker picker sheet
  - "Background colour" button → colour picker for slides without photos (optional in v1)
  - Navigation: "< Prev Slide" | slide counter "2 / 5" | "Next Slide >"

Text overlay interaction:
- Tap a text overlay to select it (show handles)
- DragGesture to move (update positionX/Y as normalised values)
- Double-tap to edit the text (inline on-canvas editor; no full-screen edit flow)
- Pinch gesture to resize (update fontSize or scale)
- Rotation gesture to rotate
- Selected overlay shows a delete button (trash icon)

Sticker overlay interaction:
- Same as text: drag to move, pinch to scale, rotate gesture
- Delete button when selected

### Views/Stories/StickerPickerSheet.swift
- Grid of available stickers
- For v1: use a curated set of SF Symbols rendered as images (sun.max, heart.fill, star.fill, camera.fill, map.fill, airplane, fork.knife, figure.walk, moonphase.full.moon, cloud.sun, music.note, flame, leaf, snowflake — at minimum 20)
- Tap sticker → adds a StickerOverlay to the current slide at centre position

### Views/Stories/StoryPreviewView.swift
- Runs the full StoryViewerView in preview mode (no auto-advance, manual only)
- "Edit" button to go back
- "Save Story" button:
  - Shows a sheet to set:
    - **Title** (required)
    - **Location** (optional)
    - **Description** (optional)
    - **People** (optional)
    - **Date** (single date picker; no end date)
    - **Cover** picker:
      - default = first slide
      - user can pick another image from **their library** (does not need to be in slides)
      - **Important:** do not override the user's chosen cover on sheet dismiss / re-appear; only default to the first slide when `coverPhotoId` is still nil.
  - Saves Story + all StorySlide records to SwiftData

## Update StoriesListView.swift (Phase 3 placeholder):
- `@Query` stories sorted by `lastEditedDate` descending.
- Render two sections:
  - **Pinned** (only if any `story.isPinned == true`)
  - **Recent** (all non-pinned stories)
- Each row uses `StoryCardView`:
  - Left: cover photo with overlays (**play**, **slide count**, **pin badge** when pinned)
  - Right: title + optional event name, optional location, optional people, mini slide thumbnail strip, created date, and an anchored actions menu button (pencil-circle)
- Tap → `StoryViewerView` (full-screen cover)
- "+" → `StoryBuilderView`
- Long press shows context menu: Pin/Unpin, Edit, Delete (confirm delete; photos are not deleted)

## Profile integration:
- Defer **Profile pinned stories strip** and all story pinning UX to **Phase 11**.
```

---

### Phase 9 Test Checklist
- [ ] StoryViewerView auto-advances slides every **10 seconds**
- [ ] Progress bar advances correctly
- [ ] Tap left/right to navigate slides manually
- [ ] Long press pauses auto-advance
- [ ] Swipe up exits StoryViewerView
- [ ] Text overlays render at correct positions in viewer
- [ ] Sticker overlays render at correct positions in viewer
- [ ] SlidePickerView multi-select works
- [ ] Selected slides show in a top strip and can be **drag-reordered**; grid badges update to match the new order
- [ ] Capture button saves to Apple Photos and the new asset can be added as a slide
- [ ] Text overlay can be added, dragged, rotated, resized, deleted in editor
- [ ] Sticker overlay can be added, dragged, rotated, resized, deleted in editor
- [ ] Story saves correctly with title and cover photo
- [ ] StoriesListView shows saved stories
- [ ] Tapping a story opens the viewer
- [ ] (Deferred to Phase 11) Pinned stories appear in ProfileView story bubbles
- [ ] (Deferred to Phase 11) Profile view shows correct counts

---

---

# PHASE 10 — Settings & Storage Management
**Build tracker:** ✅ Complete

### Goal: Settings screen fully functional for **storage** and **non-appearance** preferences. **Visual identity stays `CaviraTheme` / Ranger** — Phase 10 does **not** add light mode, system appearance, or alternate colour palettes (those belong in **Phase 12** only if product reopens them).

---

### Cursor Prompt — Phase 10

```
Build the full Settings screen and wire up app-wide settings.

## Views/Settings/SettingsView.swift — full implementation

Sections:

### Storage
- **v1:** Hide or grey out a "Copy to Cavira" default — imports are **reference-only**. Optionally show a short note: "Photos stay in your library; Cavira does not duplicate full-resolution files in v1."
- "On-device copy storage" — show `appServices.photoStorage.totalStorageUsed()` (via `Environment`); with `NoOpPhotoStorage` this reads **0 MB** until a future disk-backed implementation exists.
- "Manage stored photos" → `StorageSettingsView` (mostly empty state in v1; keep the navigation row for future phases)

### Display  
- "Default home view" picker: **Grid / Timeline / Videos** (remove Profile option per Cavira UX direction; migrate `AppSettings.defaultHomeView` if it was `.profile`).
- **Do not** add an **Appearance** (Light / Dark / System) picker or **App theme** palette picker in Phase 10 — **`CaviraTheme`** is the only v1 skin (**Phase 5.5**). If `AppSettings.appearanceMode` still exists in the model, leave it **unused** in UI or hide the field until Phase 12.

### About
- App name: Cavira
- Version: read from Bundle.main.infoDictionary
- "Built for privacy. Everything stays on your device."

## Views/Settings/StorageSettingsView.swift
- **v1:** If there are no `localCopy` rows, show a single empty state: "Cavira is not storing duplicate photo files on this device."
- (Future phase, when `localCopy` exists again): list `localCopy` entries, sizes, swipe actions, and bulk "convert to reference" as originally designed.

## Wire up default home view:
In HomeScreen.swift, initialise selectedView from AppSettings.defaultHomeView on appear.

## Wire up default import mode:
In v1, `AppSettings.defaultStorageMode` should remain `.reference` (or the UI omits the picker). If you still surface the setting for forward compatibility, it must not enable disk copies until a future phase implements `PhotoStorageServing` with real file I/O.
```

---

### Phase 10 Test Checklist
- [ ] Settings screen shows all sections as specified (Storage, Display without appearance/theme pickers, About)
- [ ] Import behaviour stays reference-only in v1; any `defaultStorageMode` UI matches that constraint
- [ ] **No** regression: app chrome still follows **`CaviraTheme`** + **`applyGlobalChrome()`** — Phase 10 does not introduce a second theme system
- [ ] Changing default home view is reflected when switching to the Home tab
- [ ] On-device copy storage line shows the value from injected `photoStorage` (0 MB in v1)
- [ ] StorageSettingsView shows the v1 empty state when there are no `localCopy` entries
- [ ] (Deferred) Deleting a future on-disk copy would go through `PhotoStorageServing` — not required in v1
- [ ] App version shows correctly

---

---

# PHASE 11 — Pinning (no ProfileView)
**Build tracker:** ✅ Complete

### Goal: Pinning works for Stories. **ProfileView is out of scope for v1** and is removed from this update.

---

### Shipped (repo)
- **Stories pin/unpin:** `Story.isPinned` is toggled from `StoriesListView` (anchored actions menu + context menu).
- **Pinned badge:** `StoryCardView` shows a pin badge when `story.isPinned == true`.

### Deferred / removed
- **ProfileView:** intentionally removed from v1 scope (no pinned bubbles strip, no profile stats, no profile grid).

---

### Phase 11 Test Checklist
- [ ] Stories can be pinned/unpinned from `StoriesListView`
- [ ] Pinned stories render with a pin badge on their story card

---

---

# PHASE 12 — Polish, Edge Cases & Final QA
**Build tracker:** ✅ Complete (see 12.x tracker below)

### Goal: App is stable, handles edge cases, and feels complete for v1. **Optional** product/engineering items that were explicitly deferred from v1: **appearance** (light / system) and **dark-mode tint** fine-tuning for Ranger, plus an unlikely migration from **UIKit global appearances** to **SwiftUI-only** tab/nav chrome — all **only** if you choose to schedule them here.

---

### Phase 12 breakdown (work one at a time)

Treat each mini-phase below as a **standalone PR-sized chunk**. When you say “start 12.x”, I’ll ask the questions in that mini-phase first, then implement it.

**Phase 12.x tracker (repo):**
- **12.1 — Missing asset handling**: ✅ Complete
- **12.2 — Empty states + copy pass**: ✅ Complete
- **12.3 — Import flow UX polish**: ✅ Complete
- **12.4 — Loading states tuning**: ✅ Complete
- **12.5 — Data integrity edge cases**: ✅ Complete
- **12.6 — Animations + transitions**: ✅ Complete
- **12.7 — Performance + memory**: ✅ Complete
- **12.8 — App icon + walkthrough QA**: ✅ Complete
- **12.9 — Appearance + Ranger tuning (Optional)**: ✅ Complete

#### PHASE 12.1 — Missing asset handling (Photos-backed references)
**Goal:** Never show broken UI or crashes when a `PhotoEntry.localIdentifier` no longer exists in Apple Photos.

**Scope:**
- Thumbnail placeholders (`PhotoThumbnailView`) for missing assets
- Detail banner / empty state (`PhotoDetailView`) with “Remove from Cavira” action
- Stories: slide renderer placeholder for missing slide media (if not already perfect)

**Questions to confirm:**
- Should **missing assets auto-remove** from Home/Stories, or **only on user action**?
- In `PhotoDetailView`, do you want **“Open Photos”** as a second action?

**Done checklist:**
- [ ] Missing thumbnails show an exclamation placeholder
- [ ] Detail view shows a clear banner and offers removal
- [ ] Stories viewer/editor never crash on missing slide media

#### PHASE 12.2 — Empty states + copy pass
**Goal:** Every list/grid/screen has a consistent empty state with Ranger styling and correct copy.

**Questions to confirm:**
- Any copy tone preference (minimal vs more descriptive)?
- Should Search empty state include a “Clear filters” affordance?

**Done checklist:**
- [ ] Home (Grid/Timeline/Videos) empty states correct
- [ ] Calendar empty / permission messaging consistent
- [ ] Stories empty state consistent
- [ ] Search empty results state consistent

**Locked decisions (this build):**
- **Guiding tone** for empty screens (tell the user what to do next).
- **Search empty results**: text-only **“Nothing found”** (no “clear filters” CTA).
- **Calendar permission blocked**: show an **Open Settings** button.

#### PHASE 12.3 — Import flow UX polish (Picker → `ImportOptionsSheet`)
**Goal:** Import feels intentional and polished: stable sheets, clear hierarchy, clear duplicate feedback, and a good experience for large selections.

**Questions to confirm:**
- For duplicates: prefer **toast**, **alert**, or **inline message**?
- For large selections: do you want a **progress indicator** or just a loading spinner?

**Done checklist:**
- [ ] Sheet transitions feel smooth and predictable
- [ ] Duplicate/“already in album” messaging is clear
- [ ] Large selections don’t feel frozen

#### PHASE 12.4 — Loading states tuning (thumbnails, story slides)
**Goal:** No black frames / janky loading; spinners and placeholders feel intentional.

**Questions to confirm:**
- Should Stories **preload next slide** (lightweight) or keep simple?

**Done checklist:**
- [ ] Thumb loading doesn’t block scrolling
- [ ] Story slide loading never shows a harsh black flash

#### PHASE 12.5 — Data integrity edge cases
**Goal:** No crashes or corrupt UX for weird states (zero slides, deleted photo references, etc.).

**Questions to confirm:**
- If a story has 0 slides, should it be **auto-deleted**, or shown with a **“No slides”** state?

**Done checklist:**
- [ ] Story with zero slides handled
- [ ] Deleting PhotoEntry referenced by slides handled gracefully

**Notes (implemented):**
- Photo detail “Remove from album” no longer deletes `PhotoEntry` (prevents breaking Story slide references); it toggles `isInHomeAlbum = false`.

#### PHASE 12.6 — Animations + transitions pass
**Goal:** Small motion polish only (nothing that risks correctness).

**Questions to confirm:**
- Any specific animations you want (Home mode switch, sheet transitions)?

**Done checklist:**
- [ ] Home mode switch animates cleanly
- [ ] Sheets have drag handles and look consistent

#### PHASE 12.7 — Performance + memory pass
**Goal:** Keep scrolling smooth, keep memory bounded (especially image caching).

**Questions to confirm:**
- What library sizes are you targeting for “feels fast” (500 / 2k / 10k items)?

**Done checklist:**
- [ ] Thumbnail requests are sized appropriately
- [ ] Cache limits are reasonable and documented in code (briefly)

#### PHASE 12.8 — App icon + final walkthrough QA
**Goal:** App icon is set, and the core flows are walked end-to-end with no sharp edges.

**Questions to confirm:**
- Do you want a **temporary icon** (simple) or should we wait for a real design asset?

**Done checklist:**
- [x] App icon appears in simulator/device (provided by product)
- [x] End-to-end walkthrough passes (import → tag → story → search → settings) — static QA pass + consistency fixes

#### PHASE 12.9 (Optional) — Appearance + Ranger tuning
**Goal:** Only if you explicitly want it: wire `AppSettings.appearanceMode` and/or adjust Ranger tokens.

**Questions to confirm:**
- Are we keeping **forced dark** for v1?
- If enabling appearance: do you want **System / Light / Dark** all supported?

**Done checklist:**
- [ ] Appearance wiring is consistent across all screens (if enabled)
- [ ] Ranger contrast looks correct in all supported modes

---

### Cursor Prompt — Phase 12 (legacy)

```
Final polish pass. Address edge cases, add missing feedback, and ensure a consistent experience.

## Optional — appearance & Ranger tuning (only if product approves)
- **`AppSettings.appearanceMode`:** if light / system / dark becomes a product requirement, wire **`.preferredColorScheme`** from settings and audit **every** screen for contrast (today the app assumes **forced dark** + Ranger tokens).
- **Dark-mode tint pass:** optional small adjustments to **`CaviraTheme`** tokens/materials — keep hex discipline by updating `CaviraTheme.swift` and the documented palette tokens section together.
- **SwiftUI-only chrome:** optional experiment to replace UIKit **`appearance()`** styling with pure SwiftUI tab/nav styling if global side effects (e.g. previews) become painful — low priority.

## Optional — Stories builder UI polish (deferred)
- **SlidePickerView album switcher label:** keep the **Albums** affordance visible in the picker header (even if it’s a no-op in v1), so the UI has a clear place to support **album switching** and **video-specific sources** in a future pass.

## Missing asset handling:
In PhotoImageLoader, if a PHAsset referenced by localIdentifier no longer exists in the Photos library:
- Return nil image
- In PhotoThumbnailView: show a placeholder view with a "photo.badge.exclamationmark" SF Symbol and grey background
- In PhotoDetailView: show a banner **"This photo is no longer in your Photos library."** with actions: **Remove from Cavira** (delete `PhotoEntry`) and, if helpful, **Open Photos** — v1 does **not** offer "make a private copy" (no duplicate storage).

## Empty states — ensure every list/grid view has an appropriate EmptyStateView:
- GridView / Album timeline / Videos-only grid: align with shipped copy — **"Import your media to start"** / **"No videos yet"** (or tuned variants) plus short subtitle where helpful
- **Home album — sticky month headers:** if v1 shipped **non-sticky** timeline headers, evaluate **`List`/`Section`** or custom sticky chrome for the month-grouped timeline (parity with calendar-style apps)
- Calendar list / month placeholder: copy matches **Calendar** tab intent (month + counts in Phase 6).
- StoriesListView: "No stories yet. Create your first story."
- SearchView (no results): "No photos match your search."
// Removed: ProfileView is out of scope for v1.

## Loading states:
- PhotoThumbnailView: show a grey placeholder during async load (already implemented, confirm it's smooth)
- StoryViewerView: if slide photo hasn't loaded yet, show a subtle spinner — don't show a black frame

## Import flow UI (polish pass on Phase 4 — picker + `ImportOptionsSheet`):
The functional import pipeline ships in **Phase 4**; **Phase 12** refines how it *feels*:
- **`PHPicker` / sheet presentation:** presentation style, safe areas, dismiss affordance, and transition into the follow-up sheet so it does not feel abrupt or “system default only.”
- **`ImportOptionsSheet`:** clearer hierarchy (title, counts, reference-only explanation), spacing and typography aligned with the rest of the app, tappable row layout if useful, **accessibility** labels/hints, and feedback when **zero new** rows were added (duplicates skipped) — friendly copy, not only an alert.
- **Large selections:** optional lightweight progress or “Importing…” state if many assets are saved in one go.
- **Contrast:** verify materials and text on import screens against **`CaviraTheme`** (v1 remains Ranger-dark only unless optional appearance work above ships).

## Transitions & animations:
- HomeScreen view switcher: animate the transition between Grid / Timeline / Videos with `.animation(.easeInOut)`
- Story viewer slide transition: use the default page swipe, ensure it's smooth
- Sheet presentations: ensure all sheets have a visible drag handle

## Data integrity:
- If a Story has zero slides (edge case if user deleted all photos that were in slides): show a "This story has no photos" state in StoryViewerView instead of crashing
// (No legacy “events” concept.)
- Ensure deleting a PhotoEntry that is used in StorySlides handles gracefully (set slide.photo = nil, show placeholder)

## Performance:
- Ensure LazyVGrid thumbnail loading is smooth — thumbnails should be 200x200 max
- NSCache in PhotoImageLoader should have a reasonable limit (e.g. 50MB) to avoid memory pressure

## App icon placeholder:
Add a simple placeholder app icon (a gradient square with the letter "F" or a simple camera shape) to Assets.xcassets so the app doesn't show a blank icon in the simulator.

Review the entire app for any obvious UI inconsistencies — font sizes, spacing, button sizes — and fix them. The app should feel like a polished v1.
```

---

### Phase 12 Final QA Checklist
- [ ] **Home timeline:** optional **sticky** month headers implemented or explicitly deferred with good UX on long feeds
- [ ] **Import flow:** picker + `ImportOptionsSheet` GUI feels polished (layout, copy, transitions, duplicate-skip feedback) per **Import flow UI** above
- [ ] Deleted photo shows placeholder with exclamationmark icon
- [ ] All list/grid views have appropriate empty states
- [ ] No crashes when deleting photos that appear in stories
- [ ] Story with no photos shows graceful state
- [ ] Animations between views are smooth
- [ ] Thumbnail loading doesn't block UI
- [ ] App icon appears in simulator
- [ ] App reads correctly in the **shipped Ranger-dark** configuration; if optional **Phase 12** appearance work is **not** done, confirm **`.preferredColorScheme(.dark)`** + **`CaviraTheme`** still hold across all flows
- [ ] All sheets have drag handles and can be dismissed
- [ ] No memory warnings during normal use
- [ ] App passes a full end-to-end walkthrough: import → tag → build story → search → settings (no Events, no ProfileView)

---

---

## Quick Reference — Phase Order

| Phase | What gets built | Depends on |
|---|---|---|
| 1 | Models & project setup | Nothing |
| 2 | Services | Phase 1 |
| 3 | Tab shell & navigation | Phase 1 |
| 4 | Photo & video import (reference-only, dedupe) | Phases 2, 3 |
| 5 | Grid, `AlbumTimelineView`, **Videos** (video-only `GridView`), `PhotoDetailView`, album-only remove | Phase 4 |
| 5.5 | `CaviraTheme` (Ranger), global UIKit chrome, `AccentColor`, themed surfaces | Phases 3–5 |
| 6 | Calendar (month grid, day drill-in, recap) | Phases 4, 5 |
| 6.1 | Calendar year/month navigation | Phase 6 |
| 7 | Tagging | Phase 2, 5, 6 |
| 8 | Search | Phases 5, 7 |
| 9 | Stories | Phases 4, 5 |
| 10 | Settings & storage (no alternate themes) | All prior phases |
| 11 | Pinning (no ProfileView) | Phase 9 |
| 12 | Polish & QA (+ optional appearance / tint / SwiftUI chrome) | All phases |


*Document version 1.13 — Cavira iOS App. **Shipped:** Phases 1–11 (see **Repo snapshot**). **Next:** Phase **12** (Polish & QA). **Close v1:** Phase 12 + **Additional improvements** backlog. **Design note:** **`CaviraTheme`** is the canonical colour system; palettes and hex tokens are documented in this file. **Home:** toolbar segments **Grid \| Timeline \| Videos**; Calendar is capture-counts + day drill-in + recap; Stories are the only narrative/grouping layer.*