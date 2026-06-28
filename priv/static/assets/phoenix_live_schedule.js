/**
 * PhoenixLiveSchedule JS Hooks
 *
 * Optional JavaScript hooks for enhanced interactions.
 * The calendar works without these — they add drag-to-select,
 * drag-to-move, drag-to-resize, and responsive container detection.
 *
 * Usage in your app.js:
 *
 *   import "../../deps/phoenix_live_schedule/priv/static/assets/phoenix_live_schedule.js"
 *
 *   let liveSocket = new LiveSocket("/live", Socket, {
 *     hooks: { ...window.PhoenixLiveScheduleHooks, ...myHooks }
 *   })
 */

(function () {
  "use strict";

  window.PhoenixLiveScheduleHooks = window.PhoenixLiveScheduleHooks || {};

  // ============================================================
  // TimeRangeSelect — drag to select a time range on a time grid
  // ============================================================
  window.PhoenixLiveScheduleHooks.TimeRangeSelect = {
    mounted() {
      this.selecting = false;
      this.startSlot = null;
      this.endSlot = null;

      this._onPointerDown = (e) => {
        const slot = e.target.closest("[data-slot]");
        if (!slot) return;

        e.preventDefault();
        this.selecting = true;
        this.startSlot = slot.dataset.slot;
        this.endSlot = slot.dataset.slot;
        this.startDate = slot.closest("[data-date]")?.dataset.date;

        // Capture pointer for tracking outside element
        this.el.setPointerCapture(e.pointerId);
        this._highlightRange();
      };

      this._onPointerMove = (e) => {
        if (!this.selecting) return;

        const el = document.elementFromPoint(e.clientX, e.clientY);
        const slot = el?.closest("[data-slot]");
        if (slot && slot.dataset.slot !== this.endSlot) {
          this.endSlot = slot.dataset.slot;
          this._highlightRange();
        }
      };

      this._onPointerUp = (e) => {
        if (!this.selecting) return;
        this.selecting = false;

        // Clear visual highlight
        this._clearHighlight();

        // Determine the ordered range
        const start = this.startSlot < this.endSlot ? this.startSlot : this.endSlot;
        const end = this.startSlot < this.endSlot ? this.endSlot : this.startSlot;

        // Push final selection to server
        this.pushEventTo(this.el, "lc_range_select", {
          date: this.startDate,
          start_time: start,
          end_time: end,
        });
      };

      this._onKeyDown = (e) => {
        if (e.key === "Escape" && this.selecting) {
          this.selecting = false;
          this._clearHighlight();
        }
      };

      this.el.addEventListener("pointerdown", this._onPointerDown);
      this.el.addEventListener("pointermove", this._onPointerMove);
      this.el.addEventListener("pointerup", this._onPointerUp);
      document.addEventListener("keydown", this._onKeyDown);

      // Prevent scroll on touch during selection
      this.el.style.touchAction = "none";
    },

    _highlightRange() {
      const slots = this.el.querySelectorAll("[data-slot]");
      const start = this.startSlot < this.endSlot ? this.startSlot : this.endSlot;
      const end = this.startSlot < this.endSlot ? this.endSlot : this.startSlot;

      slots.forEach((slot) => {
        const t = slot.dataset.slot;
        if (t >= start && t <= end) {
          slot.classList.add("cal-selecting");
        } else {
          slot.classList.remove("cal-selecting");
        }
      });
    },

    _clearHighlight() {
      this.el.querySelectorAll(".cal-selecting").forEach((el) => {
        el.classList.remove("cal-selecting");
      });
    },

    destroyed() {
      this.el.removeEventListener("pointerdown", this._onPointerDown);
      this.el.removeEventListener("pointermove", this._onPointerMove);
      this.el.removeEventListener("pointerup", this._onPointerUp);
      document.removeEventListener("keydown", this._onKeyDown);
    },
  };

  // ============================================================
  // EventDrag — drag to move an event to a new time/date
  // ============================================================
  window.PhoenixLiveScheduleHooks.EventDrag = {
    mounted() {
      this._dragging = null;
      this._ghost = null;
      this._startX = 0;
      this._startY = 0;

      this._onPointerDown = (e) => {
        const eventEl = e.target.closest("[data-event-id]");
        if (!eventEl || eventEl.dataset.editable === "false") return;

        // Require minimum movement before starting drag
        this._startX = e.clientX;
        this._startY = e.clientY;
        this._pendingDrag = eventEl;
        this._pointerId = e.pointerId;
      };

      this._onPointerMove = (e) => {
        if (this._pendingDrag && !this._dragging) {
          const dx = Math.abs(e.clientX - this._startX);
          const dy = Math.abs(e.clientY - this._startY);

          // Min 5px movement to start drag
          if (dx + dy > 5) {
            this._startDrag(this._pendingDrag, e);
            this._pendingDrag = null;
          }
          return;
        }

        if (!this._dragging) return;

        // Move ghost element
        if (this._ghost) {
          this._ghost.style.left = e.clientX - this._offsetX + "px";
          this._ghost.style.top = e.clientY - this._offsetY + "px";
        }

        // Highlight drop target
        const target = document.elementFromPoint(e.clientX, e.clientY);
        const slot = target?.closest("[data-slot]");
        const dateCol = target?.closest("[data-date]");

        this.el.querySelectorAll(".cal-drop-target").forEach((el) =>
          el.classList.remove("cal-drop-target")
        );

        if (slot) slot.classList.add("cal-drop-target");
        else if (dateCol) dateCol.classList.add("cal-drop-target");
      };

      this._onPointerUp = (e) => {
        this._pendingDrag = null;

        if (!this._dragging) return;

        // Find drop target
        if (this._ghost) {
          this._ghost.style.display = "none";
        }
        const target = document.elementFromPoint(e.clientX, e.clientY);
        if (this._ghost) {
          this._ghost.style.display = "";
        }

        const slot = target?.closest("[data-slot]");
        const dateCol = target?.closest("[data-date]");

        // Clean up
        this._cleanupDrag();

        // Push event to server
        if (slot || dateCol) {
          this.pushEventTo(this.el, "lc_event_drop", {
            event_id: this._dragging,
            new_date: dateCol?.dataset.date,
            new_time: slot?.dataset.slot,
            resource_id:
              dateCol?.dataset.resourceId || slot?.closest("[data-resource-id]")?.dataset.resourceId,
          });
        }

        this._dragging = null;
      };

      this.el.addEventListener("pointerdown", this._onPointerDown);
      document.addEventListener("pointermove", this._onPointerMove);
      document.addEventListener("pointerup", this._onPointerUp);
    },

    _startDrag(eventEl, e) {
      this._dragging = eventEl.dataset.eventId;

      // Create ghost
      this._ghost = eventEl.cloneNode(true);
      this._ghost.classList.add("cal-ghost");
      this._ghost.style.position = "fixed";
      this._ghost.style.zIndex = "9999";
      this._ghost.style.opacity = "0.7";
      this._ghost.style.pointerEvents = "none";
      this._ghost.style.width = eventEl.offsetWidth + "px";

      const rect = eventEl.getBoundingClientRect();
      this._offsetX = e.clientX - rect.left;
      this._offsetY = e.clientY - rect.top;
      this._ghost.style.left = rect.left + "px";
      this._ghost.style.top = rect.top + "px";

      document.body.appendChild(this._ghost);

      // Dim original
      eventEl.classList.add("cal-dragging");

      // Capture pointer
      this.el.setPointerCapture(this._pointerId);
    },

    _cleanupDrag() {
      if (this._ghost) {
        this._ghost.remove();
        this._ghost = null;
      }

      this.el.querySelectorAll(".cal-dragging").forEach((el) =>
        el.classList.remove("cal-dragging")
      );
      this.el.querySelectorAll(".cal-drop-target").forEach((el) =>
        el.classList.remove("cal-drop-target")
      );
    },

    destroyed() {
      this._cleanupDrag();
      this.el.removeEventListener("pointerdown", this._onPointerDown);
      document.removeEventListener("pointermove", this._onPointerMove);
      document.removeEventListener("pointerup", this._onPointerUp);
    },
  };

  // ============================================================
  // EventResize — drag event edge to resize duration
  // ============================================================
  window.PhoenixLiveScheduleHooks.EventResize = {
    mounted() {
      this._resizing = null;

      this._onPointerDown = (e) => {
        const handle = e.target.closest("[data-resize-handle]");
        if (!handle) return;

        e.preventDefault();
        e.stopPropagation();

        const eventEl = handle.closest("[data-event-id]");
        if (!eventEl || eventEl.dataset.editable === "false") return;

        this._resizing = {
          eventId: eventEl.dataset.eventId,
          edge: handle.dataset.resizeHandle, // "top" or "bottom"
          startY: e.clientY,
          originalHeight: eventEl.offsetHeight,
          originalTop: eventEl.offsetTop,
          element: eventEl,
        };

        this.el.setPointerCapture(e.pointerId);
        eventEl.classList.add("cal-resizing");
      };

      this._onPointerMove = (e) => {
        if (!this._resizing) return;

        const dy = e.clientY - this._resizing.startY;

        if (this._resizing.edge === "bottom") {
          const newHeight = Math.max(20, this._resizing.originalHeight + dy);
          this._resizing.element.style.height = newHeight + "px";
        } else if (this._resizing.edge === "top") {
          const newHeight = Math.max(20, this._resizing.originalHeight - dy);
          const newTop = this._resizing.originalTop + dy;
          this._resizing.element.style.height = newHeight + "px";
          this._resizing.element.style.top = newTop + "px";
        }
      };

      this._onPointerUp = (e) => {
        if (!this._resizing) return;

        // Find the nearest slot to the new edge position
        const rect = this._resizing.element.getBoundingClientRect();
        const targetY =
          this._resizing.edge === "bottom" ? rect.bottom : rect.top;

        const allSlots = this.el.querySelectorAll("[data-slot]");
        let nearestSlot = null;
        let nearestDist = Infinity;

        allSlots.forEach((slot) => {
          const slotRect = slot.getBoundingClientRect();
          const dist = Math.abs(slotRect.top - targetY);
          if (dist < nearestDist) {
            nearestDist = dist;
            nearestSlot = slot;
          }
        });

        this._resizing.element.classList.remove("cal-resizing");
        // Reset inline styles — server will re-render
        this._resizing.element.style.height = "";
        this._resizing.element.style.top = "";

        if (nearestSlot) {
          this.pushEventTo(this.el, "lc_event_resize", {
            event_id: this._resizing.eventId,
            edge: this._resizing.edge,
            new_time: nearestSlot.dataset.slot,
          });
        }

        this._resizing = null;
      };

      this.el.addEventListener("pointerdown", this._onPointerDown);
      this.el.addEventListener("pointermove", this._onPointerMove);
      this.el.addEventListener("pointerup", this._onPointerUp);
    },

    destroyed() {
      this.el.removeEventListener("pointerdown", this._onPointerDown);
      this.el.removeEventListener("pointermove", this._onPointerMove);
      this.el.removeEventListener("pointerup", this._onPointerUp);
    },
  };

  // ============================================================
  // ResponsiveContainer — reports container width for adaptive views
  // ============================================================
  window.PhoenixLiveScheduleHooks.ResponsiveContainer = {
    mounted() {
      this._lastWidth = null;

      this._observer = new ResizeObserver((entries) => {
        for (const entry of entries) {
          const width = Math.round(entry.contentRect.width);

          // Only push if width changed meaningfully (>10px)
          if (
            this._lastWidth === null ||
            Math.abs(width - this._lastWidth) > 10
          ) {
            this._lastWidth = width;
            this._debouncedPush(width);
          }
        }
      });

      this._observer.observe(this.el);

      // Debounce helper
      this._timer = null;
      this._debouncedPush = (width) => {
        clearTimeout(this._timer);
        this._timer = setTimeout(() => {
          this.pushEventTo(this.el, "lc_container_resized", { width: width });
        }, 150);
      };
    },

    destroyed() {
      if (this._observer) {
        this._observer.disconnect();
      }
      clearTimeout(this._timer);
    },
  };

  // ============================================================
  // TouchHandler — long-press detection for mobile drag
  // ============================================================
  window.PhoenixLiveScheduleHooks.TouchHandler = {
    mounted() {
      this._longPressDelay = parseInt(this.el.dataset.longPressDelay || "500");
      this._timer = null;

      this._onTouchStart = (e) => {
        const target = e.target.closest("[data-event-id]");
        if (!target) return;

        this._timer = setTimeout(() => {
          target.classList.add("cal-long-press");
          // Trigger a custom event that EventDrag can pick up
          target.dispatchEvent(
            new PointerEvent("pointerdown", {
              clientX: e.touches[0].clientX,
              clientY: e.touches[0].clientY,
              pointerId: 0,
              bubbles: true,
            })
          );
        }, this._longPressDelay);
      };

      this._onTouchMove = () => {
        clearTimeout(this._timer);
      };

      this._onTouchEnd = () => {
        clearTimeout(this._timer);
        this.el.querySelectorAll(".cal-long-press").forEach((el) =>
          el.classList.remove("cal-long-press")
        );
      };

      this.el.addEventListener("touchstart", this._onTouchStart, {
        passive: true,
      });
      this.el.addEventListener("touchmove", this._onTouchMove, {
        passive: true,
      });
      this.el.addEventListener("touchend", this._onTouchEnd);
    },

    destroyed() {
      clearTimeout(this._timer);
      this.el.removeEventListener("touchstart", this._onTouchStart);
      this.el.removeEventListener("touchmove", this._onTouchMove);
      this.el.removeEventListener("touchend", this._onTouchEnd);
    },
  };

  // ============================================================
  // PopoverPause — pauses tickers while a popover/modal is open
  // ============================================================
  window.PhoenixLiveScheduleHooks.PopoverPause = {
    mounted() {
      window.dispatchEvent(
        new CustomEvent("lc:ticker-pause", { detail: { paused: true } })
      );
    },
    destroyed() {
      window.dispatchEvent(
        new CustomEvent("lc:ticker-pause", { detail: { paused: false } })
      );
    },
  };

  // ============================================================
  // MarkerTicker — cycles through day marker labels one at a time
  // ============================================================
  window.PhoenixLiveScheduleHooks.MarkerTicker = {
    mounted() {
      this._items = this.el.querySelectorAll("[data-ticker-index]");
      this._count = this._items.length;
      this._current = 0;
      this._paused = false;
      this._interval = parseInt(this.el.dataset.interval || "3000");

      if (this._count <= 1) return;

      this._timer = setInterval(() => {
        if (this._paused) return;
        this._advance();
      }, this._interval);

      // Pause on hover so user can read
      this.el.addEventListener("mouseenter", () => {
        this._paused = true;
      });
      this.el.addEventListener("mouseleave", () => {
        this._paused = true;
        // Resume after a short delay to avoid jarring immediate switch
        setTimeout(() => { this._paused = false; }, 500);
      });

      // Listen for external pause (e.g., popover open)
      this._onPause = (e) => {
        if (e.detail && e.detail.paused !== undefined) {
          this._paused = e.detail.paused;
        }
      };
      window.addEventListener("lc:ticker-pause", this._onPause);
    },

    _advance() {
      this._items[this._current].classList.remove("opacity-100");
      this._items[this._current].classList.add("opacity-0", "pointer-events-none");
      this._current = (this._current + 1) % this._count;
      this._items[this._current].classList.remove("opacity-0", "pointer-events-none");
      this._items[this._current].classList.add("opacity-100");
    },

    destroyed() {
      clearInterval(this._timer);
      window.removeEventListener("lc:ticker-pause", this._onPause);
    },
  };

  // ============================================================
  // PhoenixLiveScheduleContainer — composite hook for the main container
  // ============================================================
  window.PhoenixLiveScheduleHooks.PhoenixLiveScheduleContainer = {
    mounted() {
      // Initialize sub-hooks on the same element
      var hooks = [
        "TimeRangeSelect",
        "EventDrag",
        "EventResize",
        "ResponsiveContainer",
        "TouchHandler",
      ];
      this._subHooks = [];

      hooks.forEach((name) => {
        var hook = Object.create(window.PhoenixLiveScheduleHooks[name]);
        hook.el = this.el;
        hook.pushEvent = this.pushEvent.bind(this);
        hook.pushEventTo = this.pushEventTo.bind(this);
        hook.handleEvent = this.handleEvent.bind(this);
        hook.liveSocket = this.liveSocket;

        if (hook.mounted) hook.mounted();
        this._subHooks.push(hook);
      });
    },

    updated() {
      this._subHooks.forEach((hook) => {
        if (hook.updated) hook.updated();
      });
    },

    destroyed() {
      this._subHooks.forEach((hook) => {
        if (hook.destroyed) hook.destroyed();
      });
    },
  };

  // ============================================================
  // WaterfallAutoScroll — center the today marker horizontally
  // ============================================================
  //
  // Attached to the Waterfall scroll container when
  // `enable_hooks={true}`. Behaviors:
  //
  //   • On mount: if `data-auto-scroll-today="true"` and a today marker
  //     (.cal-waterfall-today) is present, scroll so the marker is
  //     horizontally centered in the viewport.
  //
  //   • Listens for custom event `lc:wf-scroll-today` — the built-in
  //     toolbar today button dispatches this via JS.dispatch. Consumers
  //     can also dispatch it from their own buttons.
  //
  // Scroll calculations use getBoundingClientRect() + scrollLeft rather
  // than offsetLeft so they're correct regardless of the bar column's
  // offset parent chain (label column width varies).
  window.PhoenixLiveScheduleHooks.WaterfallAutoScroll = {
    mounted() {
      this._onScrollToday = () => this._scrollToToday(true);
      this.el.addEventListener("lc:wf-scroll-today", this._onScrollToday);

      if (this.el.dataset.autoScrollToday === "true") {
        // Wait one frame so layout is settled before we measure.
        requestAnimationFrame(() => this._scrollToToday(false));
      }
    },
    destroyed() {
      this.el.removeEventListener("lc:wf-scroll-today", this._onScrollToday);
    },
    updated() {
      // Re-scroll on LiveView patches that replace the today marker
      // (e.g. date range navigation moves the marker to a new x).
      // Only if the marker is present AND auto-scroll is still on.
      if (this.el.dataset.autoScrollToday === "true") {
        requestAnimationFrame(() => this._scrollToToday(false));
      }
    },
    _scrollToToday(smooth) {
      const marker = this.el.querySelector(".cal-waterfall-today");
      if (!marker) return;

      const markerRect = marker.getBoundingClientRect();
      const containerRect = this.el.getBoundingClientRect();

      // Marker's x relative to the scrollable content (includes current scroll).
      const markerOffset =
        markerRect.left - containerRect.left + this.el.scrollLeft;

      // Exclude the sticky-ish label column from the visible timeline width
      // so "center" means center of the bar area, not center of the whole
      // viewport (which would land today too far right).
      const labelHeader = this.el.querySelector(".cal-waterfall-label-header");
      const labelWidth = labelHeader ? labelHeader.offsetWidth : 0;

      const visibleTimelineWidth = this.el.clientWidth - labelWidth;
      const targetScroll =
        markerOffset - labelWidth - visibleTimelineWidth / 2;

      this.el.scrollTo({
        left: Math.max(0, targetScroll),
        behavior: smooth ? "smooth" : "auto",
      });
    },
  };

  // ============================================================
  // WaterfallBarPopover — click bar to open a popover anchored to
  // the bar with full title + custom action buttons. Click anywhere
  // outside the popover (or on a different bar) to close.
  // ============================================================
  //
  // Wired automatically via `phx-hook` on bar elements that have
  // `event.extra.actions` configured. Each hooked bar carries a
  // `data-popover-target="<id>"` pointing to its sibling popover div
  // (rendered next to the bar so the bar's overflow-hidden doesn't
  // clip the popover).
  //
  // Touch devices: a normal `click` event fires on tap, so this hook
  // works for both desktop click and mobile tap with no special-case
  // pointer handling.
  window.PhoenixLiveScheduleHooks.WaterfallBarPopover = {
    mounted() {
      this._onClick = (e) => {
        // Clicks inside the popover itself shouldn't toggle / close
        // (action button clicks bubble through and would otherwise
        // immediately close the popover they live in).
        const popover = this._popover();
        if (popover && popover.contains(e.target)) return;

        // Clicks on the sub-project expand/collapse chevron must
        // pass through to LiveView's phx-click. We do NOT toggle
        // the popover AND do NOT call stopPropagation, so the
        // chevron's `phx-click` fires normally.
        if (e.target.closest(".cal-waterfall-subproject-chevron")) return;

        e.stopPropagation();
        this._toggle();
      };

      this.el.addEventListener("click", this._onClick);

      // Track this bar in the document-level registry so the global
      // outside-click handler can find every open popover and close
      // them in one pass.
      window.PhoenixLiveScheduleHooks.WaterfallBarPopover._installGlobal();
      window.PhoenixLiveScheduleHooks.WaterfallBarPopover._bars.add(this.el);
    },

    destroyed() {
      this.el.removeEventListener("click", this._onClick);
      window.PhoenixLiveScheduleHooks.WaterfallBarPopover._bars.delete(this.el);
      this._close();
    },

    _popover() {
      const id = this.el.dataset.popoverTarget;
      return id ? document.getElementById(id) : null;
    },

    _isOpen() {
      const p = this._popover();
      return p && !p.classList.contains("hidden");
    },

    _open() {
      const p = this._popover();
      if (!p) return;
      window.PhoenixLiveScheduleHooks.WaterfallBarPopover._closeAll();
      p.classList.remove("hidden");
      this.el.dataset.popoverOpen = "true";

      // Highlight the active task's dependency tree; fade everything else.
      // Walks the connector graph in BOTH directions from the active task,
      // so ancestors AND descendants stay full color.
      const eventId = this.el.dataset.eventId;
      if (eventId) {
        window.PhoenixLiveScheduleHooks.WaterfallBarPopover._applyTreeFade(this.el, eventId);
      }

      // Push bottom-corner badges of the active task down so the
      // expanded popover doesn't sit on top of them. Measured AFTER
      // the popover becomes visible (`requestAnimationFrame` ensures
      // layout is settled), so we get the popover's actual height.
      requestAnimationFrame(() => {
        window.PhoenixLiveScheduleHooks.WaterfallBarPopover._pushBottomBadges(this.el, p);
      });
    },

    _close() {
      const p = this._popover();
      if (!p) return;
      p.classList.add("hidden");
      delete this.el.dataset.popoverOpen;

      // Restore everything else.
      window.PhoenixLiveScheduleHooks.WaterfallBarPopover._clearTreeFade(this.el);
      window.PhoenixLiveScheduleHooks.WaterfallBarPopover._restoreBottomBadges(this.el);
    },

    _toggle() {
      this._isOpen() ? this._close() : this._open();
    },
  };

  // Document-wide outside-click + Escape handlers, installed once.
  // Tracks every mounted bar so a single listener handles all of
  // them (avoids registering N document listeners).
  window.PhoenixLiveScheduleHooks.WaterfallBarPopover._bars = new Set();
  window.PhoenixLiveScheduleHooks.WaterfallBarPopover._globalInstalled = false;

  window.PhoenixLiveScheduleHooks.WaterfallBarPopover._installGlobal = function () {
    if (this._globalInstalled) return;
    this._globalInstalled = true;

    document.addEventListener("click", (e) => {
      this._bars.forEach((bar) => {
        if (bar.dataset.popoverOpen !== "true") return;

        const popoverId = bar.dataset.popoverTarget;
        const popover = popoverId ? document.getElementById(popoverId) : null;

        // Click inside this bar OR its popover is fine — keep open.
        if (bar.contains(e.target)) return;
        if (popover && popover.contains(e.target)) return;

        // Click landed elsewhere — close + restore the faded tree
        // and any shifted bottom badges.
        if (popover) popover.classList.add("hidden");
        delete bar.dataset.popoverOpen;
        this._clearTreeFade(bar);
        this._restoreBottomBadges(bar);
      });
    });

    document.addEventListener("keydown", (e) => {
      if (e.key !== "Escape") return;
      this._closeAll();
    });
  };

  window.PhoenixLiveScheduleHooks.WaterfallBarPopover._closeAll = function () {
    this._bars.forEach((bar) => {
      if (bar.dataset.popoverOpen !== "true") return;
      const popoverId = bar.dataset.popoverTarget;
      const popover = popoverId ? document.getElementById(popoverId) : null;
      if (popover) popover.classList.add("hidden");
      delete bar.dataset.popoverOpen;
      this._clearTreeFade(bar);
      this._restoreBottomBadges(bar);
    });
  };

  // Walk the connector graph BACKWARD from `activeId` to collect every
  // task that's required to reach it — i.e., its transitive ancestors.
  // Descendants (things that depend on this task) are NOT included;
  // they aren't required for THIS task's completion.
  //
  // For tasks inside a sub-project we also walk the parent_id chain
  // and the parent sub-project's own incoming connectors. A nested
  // task implicitly inherits everything its container sub-project
  // depends on, so those should stay full color too.
  window.PhoenixLiveScheduleHooks.WaterfallBarPopover._collectTree = function (chartEl, activeId) {
    // Reverse adjacency: for each task, who points INTO it.
    const reverse = new Map();
    chartEl.querySelectorAll("[data-from-id][data-to-id]").forEach((c) => {
      const f = c.dataset.fromId;
      const t = c.dataset.toId;
      if (!reverse.has(t)) reverse.set(t, new Set());
      reverse.get(t).add(f);
    });

    // Parent chain: each task → its parent_id (if any). Multiple DOM
    // nodes (bar + label + milestone) carry the same data-parent-id;
    // the Map dedupes them by event id.
    const parentOf = new Map();
    chartEl.querySelectorAll("[data-event-id][data-parent-id]").forEach((el) => {
      const id = el.dataset.eventId;
      const pid = el.dataset.parentId;
      if (id && pid) parentOf.set(id, pid);
    });

    const tree = new Set([activeId]);
    const queue = [activeId];
    while (queue.length) {
      const id = queue.shift();

      // Incoming connector edges (predecessors).
      const incoming = reverse.get(id);
      if (incoming) {
        incoming.forEach((from) => {
          if (!tree.has(from)) {
            tree.add(from);
            queue.push(from);
          }
        });
      }

      // Walk up parent_id — the sub-project containing this task
      // contributes its OWN required chain too.
      const parent = parentOf.get(id);
      if (parent && !tree.has(parent)) {
        tree.add(parent);
        queue.push(parent);
      }
    }
    return tree;
  };

  // Add `cal-wf-faded` to every bar/label/connector NOT in the active
  // task's dependency tree. Scoped to the chart that contains the
  // active bar so multiple charts on one page don't interfere.
  window.PhoenixLiveScheduleHooks.WaterfallBarPopover._applyTreeFade = function (activeEl, activeId) {
    const chartEl = activeEl.closest(".cal-waterfall-wrap");
    if (!chartEl) return;

    const tree = this._collectTree(chartEl, activeId);

    // Pass 1: bars + labels + milestones + bar-badges (anything carrying
    // data-event-id). Build up the set of groups that have at least one
    // task in the tree so we know which group headers stay full color.
    const groupsInTree = new Set();
    chartEl.querySelectorAll("[data-event-id]").forEach((el) => {
      if (tree.has(el.dataset.eventId)) {
        if (el.dataset.group) groupsInTree.add(el.dataset.group);
      } else {
        el.classList.add("cal-wf-faded");
      }
    });

    // Pass 2: group headers (label-side) + group spacers (timeline-side).
    // Fade if NO event in their group is in the tree.
    chartEl
      .querySelectorAll(".cal-waterfall-group[data-group], .cal-waterfall-group-spacer[data-group]")
      .forEach((el) => {
        if (!groupsInTree.has(el.dataset.group)) {
          el.classList.add("cal-wf-faded");
        }
      });

    // Pass 3: connectors — keep only edges where BOTH endpoints are in
    // the tree.
    chartEl.querySelectorAll("[data-from-id][data-to-id]").forEach((c) => {
      const inTree = tree.has(c.dataset.fromId) && tree.has(c.dataset.toId);
      if (!inTree) {
        c.classList.add("cal-wf-faded");
      }
    });

    // Pass 4: PIN the active task's elements (bar, label, badges) with
    // `cal-wf-pinned` so they're guaranteed full color even if some
    // other rule later tries to dim them. The active task isn't faded
    // by pass 1 anyway, but pinning gives a hard guarantee.
    chartEl
      .querySelectorAll(`[data-event-id="${CSS.escape(activeId)}"]`)
      .forEach((el) => el.classList.add("cal-wf-pinned"));
  };

  // Strip every `cal-wf-faded` mark inside the chart that owns
  // `activeEl`. Called on popover close + before opening a different
  // popover (so transitions are clean).
  window.PhoenixLiveScheduleHooks.WaterfallBarPopover._clearTreeFade = function (activeEl) {
    const chartEl = activeEl.closest(".cal-waterfall-wrap");
    if (!chartEl) return;
    chartEl
      .querySelectorAll(".cal-wf-faded")
      .forEach((el) => el.classList.remove("cal-wf-faded"));
    chartEl
      .querySelectorAll(".cal-wf-pinned")
      .forEach((el) => el.classList.remove("cal-wf-pinned"));
  };

  // When the popover opens it can extend far below the bar
  // (title + subtitle + actions row). Any bottom-corner badge of
  // the active task would then sit inside the popover's visual
  // footprint and feel like it belongs to the popup, not the row
  // below it. Slide every bottom-corner badge down by exactly the
  // overflow amount so it lands clear of the open popover.
  window.PhoenixLiveScheduleHooks.WaterfallBarPopover._pushBottomBadges = function (activeEl, popover) {
    const chartEl = activeEl.closest(".cal-waterfall-wrap");
    if (!chartEl) return;

    const eventId = activeEl.dataset.eventId;
    if (!eventId) return;

    // How much the popover extends below the bar's row. Popover sits
    // at top: 4px in the row container; row height comes from the
    // badge's data-row-px (set at render time). Negative or zero
    // means the popover fits inside the row → no push needed.
    const popoverHeight = popover.offsetHeight;
    const popoverTop = 4; // matches `popover_top_inset` on the server

    chartEl
      .querySelectorAll(
        `[data-event-id="${CSS.escape(eventId)}"][data-badge-corner^="bottom_"]`,
      )
      .forEach((badge) => {
        const rowPx = parseInt(badge.dataset.rowPx || "40", 10);
        // The badge's natural bottom edge sits at `rowPx` (top: rowPx-16,
        // height: 16). Shift it so it lands just below the popover
        // bottom — `popoverTop + popoverHeight + small gap`.
        const targetTop = popoverTop + popoverHeight + 4;
        const naturalBottom = rowPx;
        const shift = Math.max(0, targetTop - naturalBottom);
        badge.style.transform = `translateY(${shift}px)`;
      });
  };

  // Reset transforms on bottom-corner badges so they slide back to
  // their natural position when the popover closes.
  window.PhoenixLiveScheduleHooks.WaterfallBarPopover._restoreBottomBadges = function (activeEl) {
    const chartEl = activeEl.closest(".cal-waterfall-wrap");
    if (!chartEl) return;

    chartEl
      .querySelectorAll('.cal-waterfall-bar-badge[data-badge-corner^="bottom_"]')
      .forEach((badge) => {
        badge.style.transform = "";
      });
  };

  // Log initialization
  var hookCount = Object.keys(window.PhoenixLiveScheduleHooks).length;
  if (typeof console !== "undefined" && console.debug) {
    console.debug(
      "[PhoenixLiveSchedule] Initialized with " + hookCount + " hook(s):",
      Object.keys(window.PhoenixLiveScheduleHooks)
    );
  }
})();
