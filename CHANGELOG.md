# Changelog

## 0.1.0 (unreleased)

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
