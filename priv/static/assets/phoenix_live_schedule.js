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
  // SyncAnimations — keep the overdue overlay consistent across cells
  // ============================================================
  // Two jobs, both so a striped/animated overlay reads as one continuous thing
  // across separately-rendered day-cells:
  //
  //  1. Phase: CSS animations begin when their element is first rendered, so
  //     cells patched in at different times (e.g. paging a calendar) drift out
  //     of phase. We re-anchor every animation in the subtree to the same start
  //     time (0 = the document timeline origin); per-element `animation-delay` is
  //     preserved, so a staggered wave stays staggered AND synced.
  //
  //  2. Alignment: a per-cell background gradient normally restarts at each
  //     cell's own box, so diagonal stripes don't line up cell-to-cell. We set
  //     `--pk-bg-x/y` on each `.pk-overdue` to its offset from this container's
  //     origin, so every cell shows its slice of ONE shared pattern. The offset
  //     is relative (not viewport-fixed), so it stays correct on scroll.
  //
  // Recomputed on mount, on subtree changes (MutationObserver — paging) and on
  // size changes (ResizeObserver — window resize + becoming visible after a tab
  // switch). Progressive enhancement: without it the CSS still renders, the
  // stripes just don't line up / animations can drift after a re-render.
  window.PhoenixLiveScheduleHooks.SyncAnimations = {
    mounted() {
      this._apply();

      if (typeof MutationObserver !== "undefined") {
        this._observer = new MutationObserver(() => this._apply());
        this._observer.observe(this.el, { childList: true, subtree: true });
      }

      if (typeof ResizeObserver !== "undefined") {
        this._resize = new ResizeObserver(() => this._apply());
        this._resize.observe(this.el);
      }
    },

    _apply() {
      if (this._scheduled) return;
      this._scheduled = true;
      requestAnimationFrame(() => {
        this._scheduled = false;
        this._alignStripes();
        this._syncAnimations();
      });
    },

    // Anchor each overdue cell's gradient to this container's origin so the
    // diagonals line up across cells/rows.
    _alignStripes() {
      const root = this.el.getBoundingClientRect();
      this.el.querySelectorAll(".pk-overdue").forEach((el) => {
        const r = el.getBoundingClientRect();
        el.style.setProperty("--pk-bg-x", Math.round(root.left - r.left) + "px");
        el.style.setProperty("--pk-bg-y", Math.round(root.top - r.top) + "px");
      });
    },

    _syncAnimations() {
      if (!this.el.getAnimations) return;
      this.el.getAnimations({ subtree: true }).forEach((a) => {
        try {
          a.startTime = 0;
        } catch (e) {
          /* animation not yet ready / no settable startTime — ignore */
        }
      });
    },

    destroyed() {
      if (this._observer) this._observer.disconnect();
      if (this._resize) this._resize.disconnect();
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
})();
