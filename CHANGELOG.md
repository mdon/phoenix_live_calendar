# Changelog

## 0.2.0

### Added

- `respect_hours` mode (month view): timed events cover only the hours they occupy — single-day events become inset bars sized to their duration; multi-day bars trim their boundary days to their start/end hours. Very short events keep a 1-hour minimum width so they stay visible. Opt-in (default off); all-day events and a custom `:event` slot are unaffected. Threaded through `CalendarComponent`.
- `Event.spans_multiple_dates?/1` and `Event.last_date/1` — the date-occupancy source of truth for bar rendering.

### Changed

- Month view renders any event spanning 2+ calendar dates as one continuous bar, including overnight timed events (e.g. 10pm→2am), instead of a chip per day.

### Fixed

- No stray stub on the day after a multi-day timed event ends (the last day is capped to the date the event actually ends on).
- Color-less events get a legible default background instead of an unreadable inherited one.
- Duplicate DOM ids when a single event renders across multiple day cells.

## 0.1.0

- Initial release
- Layer 0: Pure Elixir/HEEx calendar views (month, week, day, N-day, year, agenda, timeline, resource)
- Layer 1: Optional JS hooks (drag-to-select, drag-to-move, resize, responsive container, marker ticker)
- Layer 2: Optional PubSub integration for real-time updates
- Layer 3: Booking constraints (availability, slots, buffers, validation)
- Layer 4: Optional Ecto persistence layer
- Core data structures: Event, Resource, Availability, BookingConfig, DayMarker
- Accessibility-focused: ARIA grid roles + semantic labels (arrow-key grid navigation and focus restoration are on the roadmap)
- RTL support
- i18n via default English labels + an override translations map (supply your app's Gettext strings directly)
- Tailwind CSS / daisyUI compatible styling
- Responsive month view tuned for small screens (single-letter day headers, equal-width columns that never overflow). The other views are functional but less polished — the time-grid views are not yet optimised for phone widths
