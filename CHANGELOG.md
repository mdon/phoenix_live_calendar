# Changelog

## 0.1.0 (unreleased)

- Initial release
- Layer 0: Pure Elixir/HEEx calendar views (month, week, day, N-day, year, agenda)
- Layer 1: Optional JS hooks (drag-to-select, drag-to-move, resize, responsive container)
- Layer 2: Optional PubSub integration for real-time updates
- Layer 3: Booking constraints (availability, slots, buffers, validation)
- Layer 4: Optional Ecto persistence layer
- Core data structures: Event, Resource, Availability, BookingConfig
- Full accessibility (WCAG AA): ARIA grid, roving tabindex, keyboard navigation
- RTL support
- i18n with Gettext + override translations map
- Tailwind CSS / daisyUI compatible styling
