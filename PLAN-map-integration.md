# Plan: flutter_map Integration — Servio Mobile App

Generated: 2026-05-16
Branch: mostafabdelaal/mobile-backend-test

---

## Phase 0: Documentation Discovery (COMPLETE)

### Allowed APIs

**flutter_map v8.3.0** (latest stable)

```yaml
# pubspec.yaml additions
flutter_map: ^8.3.0
latlong2: ^0.9.0
geolocator: ^13.0.2      # GPS — verify latest on pub.dev
geocoding: ^3.0.0        # text address → LatLng — verify latest
permission_handler: ^12.0.0  # runtime permissions — verify latest
```

**Core widget signature:**
```dart
FlutterMap(
  options: MapOptions(
    initialCenter: LatLng(lat, lng),
    initialZoom: 13.0,
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.servio', // use actual package name
    ),
    MarkerLayer(markers: [...]),
  ],
)
```

**Marker signature:**
```dart
Marker(
  point: LatLng(lat, lng),
  width: 80,
  height: 80,
  child: Icon(Icons.location_pin, color: Colors.red, size: 40),
  alignment: Alignment.topCenter,
)
```

**Android INTERNET permission** required in `android/app/src/main/AndroidManifest.xml`.
**iOS** needs `NSLocationWhenInUseUsageDescription` in `Info.plist` for GPS features.

**Anti-patterns to avoid:**
- Do NOT construct `NetworkTileProvider()` inside `build()` — cache as class field
- Do NOT use `tileSize` (v7) — v8 uses `tileDimension`
- Do NOT use `MapOptions.center` / `.zoom` (v6) — use `initialCenter` / `initialZoom`
- Do NOT use `MapCamera.point*` methods — v8 uses `MapCamera.offset*`

### Current App State

- **No** lat/lng in any model (CustomerAddress, BackendBooking, BackendWorker all text-only)
- **No** geocoding or GPS infrastructure
- State management: Provider (ChangeNotifier)
- Flutter SDK: >=3.3.0
- Package: verify in `android/app/build.gradle` for `applicationId`

### Priority Screens for Map

| Priority | Screen | File | Map Use |
|----------|--------|------|---------|
| CRITICAL | Create Address | `lib/src/features/customer/create_address_screen.dart` | Map picker to set lat/lng |
| CRITICAL | Booking Step 2 | `lib/src/features/booking/booking_step_two_screen.dart` | Show selected address on map |
| HIGH | Job Details (tech) | `lib/src/features/technician/job_details_screen.dart` | Show customer address; route hint |
| MEDIUM | Technician Listing | `lib/src/features/customer/technician_listing_screen.dart` | Show tech proximity |
| LOW | My Addresses | `lib/src/features/customer/my_addresses_screen.dart` | Address overview map |

---

## Phase 1: Dependencies + Platform Config

**Goal:** All packages installed and platform permissions configured. App builds and runs.

### Tasks

1. Add to `mobile-app/pubspec.yaml` under `dependencies:`:
   ```yaml
   flutter_map: ^8.3.0
   latlong2: ^0.9.0
   geolocator: ^13.0.2
   geocoding: ^3.0.0
   permission_handler: ^12.0.0
   ```
   Run: `flutter pub get`

2. **Android** — `mobile-app/android/app/src/main/AndroidManifest.xml`:
   Add inside `<manifest>` (before `<application>`):
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
   ```

3. **iOS** — `mobile-app/ios/Runner/Info.plist`:
   Add inside root `<dict>`:
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>Servio needs your location to help find nearby technicians and show your service address on the map.</string>
   ```

4. **Android compile SDK** — check `android/app/build.gradle` has `compileSdkVersion 34` or higher (geolocator requirement).

### Verification
- `flutter pub get` exits with no errors
- `flutter build apk --debug` succeeds
- No `Unresolved package` errors in IDE

### Anti-pattern Guards
- Do NOT add `google_maps_flutter` — using flutter_map (OSM) only
- Do NOT add conflicting location packages (e.g., `location` AND `geolocator`) — pick one

---

## Phase 2: Location + Geocoding Service

**Goal:** Reusable service layer for GPS + address→LatLng conversion, so screens don't call APIs directly.

**Doc references:**
- geolocator: `Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)`
- geocoding: `locationFromAddress(String address)` → `List<Location>`
- permission_handler: `Permission.location.request()`

### Create: `lib/src/core/services/location_service.dart`

```dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong2.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  // Cache provider — do not create inside widget build
  static final LocationService _instance = LocationService._();
  LocationService._();
  factory LocationService() => _instance;

  Future<LatLng?> getCurrentLocation() async {
    final status = await Permission.location.request();
    if (!status.isGranted) return null;
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return LatLng(pos.latitude, pos.longitude);
  }

  /// Convert text address to LatLng for map display.
  /// Returns null if geocoding fails (show fallback).
  Future<LatLng?> geocodeAddress(String address) async {
    try {
      final results = await locationFromAddress(address);
      if (results.isEmpty) return null;
      return LatLng(results.first.latitude, results.first.longitude);
    } catch (_) {
      return null;
    }
  }
}
```

### Verification
- `flutter analyze` shows no errors in new file
- Unit test (optional): mock `locationFromAddress` and assert non-null LatLng returned

---

## Phase 3: Reusable Map Widget

**Goal:** Single `ServioMapWidget` component used by all screens. Avoids duplicating TileLayer config.

### Create: `lib/src/shared/widgets/servio_map_widget.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong2.dart';

class ServioMapWidget extends StatefulWidget {
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final bool interactive; // false = static display, true = tappable
  final void Function(LatLng)? onTap;

  const ServioMapWidget({
    super.key,
    required this.center,
    this.zoom = 14.0,
    this.markers = const [],
    this.interactive = false,
    this.onTap,
  });

  @override
  State<ServioMapWidget> createState() => _ServioMapWidgetState();
}

class _ServioMapWidgetState extends State<ServioMapWidget> {
  // Cached — do NOT construct inside build()
  final _tileProvider = NetworkTileProvider();

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.zoom,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all
              : InteractiveFlag.none,
        ),
        onTap: widget.onTap != null
            ? (_, latLng) => widget.onTap!(latLng)
            : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.servio.app', // verify against build.gradle applicationId
          tileProvider: _tileProvider,
        ),
        if (widget.markers.isNotEmpty)
          MarkerLayer(markers: widget.markers),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors',
                onTap: () {}),
          ],
        ),
      ],
    );
  }
}
```

**Helper** — create in same file or separate:
```dart
Marker buildPinMarker(LatLng point, {Color color = Colors.red}) => Marker(
  point: point,
  width: 40,
  height: 40,
  alignment: Alignment.topCenter,
  child: Icon(Icons.location_pin, color: color, size: 40),
);
```

### Verification
- Create a test route/screen that renders `ServioMapWidget(center: LatLng(30.044, 31.235))` — Cairo
- Map tiles load; no tile errors in console
- `flutter analyze` passes

---

## Phase 4: Backend — Add lat/lng to CustomerAddress

**Goal:** Backend stores lat/lng on address create/update. Mobile model reads them back.

**Why needed:** Without stored coordinates, every screen must geocode text on every render (slow, API limits, offline fails).

### 4a. Backend: Update CustomerAddress Schema

File: `backend/src/modules/customers/` (find `customerAddress.model.js` or similar — grep for `zipCode` to locate)

Add fields to Mongoose schema:
```js
lat: { type: Number, default: null },
lng: { type: Number, default: null },
```

### 4b. Backend: Update Address Routes

In address create/update route handler, accept `lat` and `lng` from request body and save to document.
Ensure GET endpoints return `lat` and `lng` in response.

### 4c. Mobile: Update CustomerAddress Model

File: `mobile-app/lib/src/core/models/customer_address.dart`

Add fields:
```dart
final double? lat;
final double? lng;
```

Update `fromJson` and `toJson`:
```dart
lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
```
```dart
if (lat != null) 'lat': lat,
if (lng != null) 'lng': lng,
```

### Verification
- POST address with `{"lat": 30.044, "lng": 31.235, ...}` → GET returns lat/lng
- Mobile `CustomerAddress.fromJson` parses lat/lng without null errors
- Existing addresses (no lat/lng) parse without crash (nullable fields)

---

## Phase 5: Interactive Map Address Picker (Create Address Screen)

**Goal:** User taps map to set address coordinates instead of or alongside text fields.

**File:** `mobile-app/lib/src/features/customer/create_address_screen.dart`

### Changes

1. Add state variables:
   ```dart
   LatLng? _pickedLocation;
   bool _loadingLocation = false;
   ```

2. Add map picker section to form (below existing text fields):
   ```dart
   SizedBox(
     height: 250,
     child: _pickedLocation == null
         ? _buildLocationPicker()  // tap to pick
         : ServioMapWidget(
             center: _pickedLocation!,
             interactive: true,
             markers: [buildPinMarker(_pickedLocation!)],
             onTap: (latLng) => setState(() => _pickedLocation = latLng),
           ),
   )
   ```

3. Add "Use current location" button:
   ```dart
   ElevatedButton.icon(
     onPressed: _fetchCurrentLocation,
     icon: const Icon(Icons.my_location),
     label: const Text('Use my location'),
   )
   ```

4. Implement `_fetchCurrentLocation`:
   ```dart
   Future<void> _fetchCurrentLocation() async {
     setState(() => _loadingLocation = true);
     final loc = await LocationService().getCurrentLocation();
     setState(() {
       _pickedLocation = loc;
       _loadingLocation = false;
     });
   }
   ```

5. Pass lat/lng when saving address:
   ```dart
   // In submit handler, include lat/lng from _pickedLocation
   lat: _pickedLocation?.latitude,
   lng: _pickedLocation?.longitude,
   ```

### Verification
- Map renders in create address form
- Tap on map updates pin position
- "Use my location" button triggers permission prompt then centers map on GPS
- Saved address includes lat/lng in API payload (check network logs)

---

## Phase 6: Show Address on Map in Booking Step 2

**Goal:** When customer selects an existing address in booking step 2, a small static map preview appears below the address card.

**File:** `mobile-app/lib/src/features/booking/booking_step_two_screen.dart`

### Logic

1. When address is selected, check if it has `lat/lng`:
   ```dart
   final hasCoords = selectedAddress.lat != null && selectedAddress.lng != null;
   ```

2. If coordinates exist → show `ServioMapWidget` (static, `interactive: false`):
   ```dart
   if (hasCoords)
     SizedBox(
       height: 180,
       child: ClipRRect(
         borderRadius: BorderRadius.circular(12),
         child: ServioMapWidget(
           center: LatLng(selectedAddress.lat!, selectedAddress.lng!),
           interactive: false,
           markers: [buildPinMarker(LatLng(selectedAddress.lat!, selectedAddress.lng!))],
         ),
       ),
     ),
   ```

3. If no coordinates (legacy addresses) → geocode on selection, store in local state, show loading then map.
   Use `LocationService().geocodeAddress('${addr.street}, ${addr.city}')`.

### Verification
- Select address with lat/lng → map renders immediately with pin
- Select legacy address (no coords) → brief loading indicator → geocoded map appears
- Geocode failure → no map shown (graceful fallback, no crash)

---

## Phase 7: Customer Address on Map in Job Details (Technician View)

**Goal:** Technician sees customer address location on map in job details screen, especially during "En Route" status.

**File:** `mobile-app/lib/src/features/technician/job_details_screen.dart`

### Logic

1. Extract job's address from booking model (already has `addressCity`, `addressStreet`).

2. Geocode once on screen load (or use stored lat/lng if Phase 4 backend done):
   ```dart
   LatLng? _customerLatLng;

   @override
   void initState() {
     super.initState();
     _geocodeJobAddress();
   }

   Future<void> _geocodeJobAddress() async {
     final addr = '${widget.booking.addressStreet}, ${widget.booking.addressCity}';
     final latLng = await LocationService().geocodeAddress(addr);
     if (mounted) setState(() => _customerLatLng = latLng);
   }
   ```

3. Show map section (visible when status is `enRoute`, `arrived`, or always):
   ```dart
   if (_customerLatLng != null)
     SizedBox(
       height: 220,
       child: ServioMapWidget(
         center: _customerLatLng!,
         zoom: 15,
         markers: [buildPinMarker(_customerLatLng!, color: Colors.blue)],
         interactive: false,
       ),
     ),
   ```

### Verification
- Job details screen shows map with blue pin at customer location
- Geocoding failure → section hidden gracefully
- No crash if address string is empty

---

## Phase 8: Technician Distance in Listing Screen

**Goal:** Show approximate distance from customer's selected address to each technician's service area.

**File:** `mobile-app/lib/src/features/customer/technician_listing_screen.dart`

**Note:** Requires technician location data from backend (currently only `locationLabel` string). This phase may be deferred if backend doesn't provide coordinates.

### If backend provides technician lat/lng:

1. Update `BackendWorker` model to include `lat`/`lng` fields (same pattern as Phase 4).

2. Use `latlong2` `Distance` class to compute:
   ```dart
   import 'package:latlong2/latlong2.dart';

   final distance = const Distance();
   final km = distance.as(
     LengthUnit.Kilometer,
     customerLatLng,
     LatLng(worker.lat!, worker.lng!),
   );
   ```

3. Display `'${km.toStringAsFixed(1)} km away'` in technician card.

### If backend does NOT provide coordinates:
- Geocode `worker.locationLabel` string → LatLng (same `LocationService().geocodeAddress()`)
- Cache results to avoid repeated geocoding of same location

### Verification
- Distance labels appear on technician cards
- Sorting by distance works correctly
- No duplicate geocoding requests for same location

---

## Phase 9: Verification (Final)

Run after all phases complete.

### Checklist

**Build:**
- [ ] `flutter pub get` — no errors
- [ ] `flutter analyze` — no errors or warnings in new/modified files
- [ ] `flutter build apk --debug` — succeeds

**Functional:**
- [ ] Create address → map picker works → lat/lng saved to backend
- [ ] Booking Step 2 → address with coords shows static map
- [ ] Booking Step 2 → address without coords geocodes and shows map (or graceful no-map)
- [ ] Job details (technician) → customer address shows on map
- [ ] Technician listing → distance labels show (if backend supports)

**Edge cases:**
- [ ] No internet → map shows empty tiles, no crash
- [ ] Location permission denied → "Use my location" shows error message, no crash
- [ ] Geocoding fails → no map shown, form still submittable
- [ ] Address with `lat=null, lng=null` → no crash in any screen

**Anti-patterns grep:**
- [ ] `grep -r "NetworkTileProvider()" lib/` — result should only appear inside `State` class fields, not `build()` methods
- [ ] `grep -r "tileSize" lib/` — should return nothing (v8 uses `tileDimension`)
- [ ] `grep -r "MapOptions.center\|\.zoom" lib/` — should return nothing (v8 uses `initialCenter`)

---

## Execution Order

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 (backend + mobile) → Phase 5 → Phase 6 → Phase 7 → Phase 8 → Phase 9
```

Phases 2 and 3 can be done in same session.
Phase 4 backend changes can be done in parallel with Phases 5–7 if backend developer available.
Phase 8 depends on Phase 4 backend delivering technician coordinates.

---

## Files to Create

| File | Phase |
|------|-------|
| `mobile-app/lib/src/core/services/location_service.dart` | 2 |
| `mobile-app/lib/src/shared/widgets/servio_map_widget.dart` | 3 |

## Files to Modify

| File | Phase | Change |
|------|-------|--------|
| `mobile-app/pubspec.yaml` | 1 | Add 5 dependencies |
| `mobile-app/android/app/src/main/AndroidManifest.xml` | 1 | Add permissions |
| `mobile-app/ios/Runner/Info.plist` | 1 | Add location description |
| `mobile-app/lib/src/core/models/customer_address.dart` | 4 | Add lat/lng fields |
| `mobile-app/lib/src/features/customer/create_address_screen.dart` | 5 | Map picker UI |
| `mobile-app/lib/src/features/booking/booking_step_two_screen.dart` | 6 | Static map preview |
| `mobile-app/lib/src/features/technician/job_details_screen.dart` | 7 | Customer location map |
| `mobile-app/lib/src/features/customer/technician_listing_screen.dart` | 8 | Distance labels |
| Backend CustomerAddress schema | 4 | lat/lng fields |
| Backend address routes | 4 | Accept/return lat/lng |
