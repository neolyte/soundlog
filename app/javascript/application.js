import "@hotwired/turbo-rails"

const TIMER_COLLAPSED_STORAGE_KEY = "soundlog.timerWidgetCollapsed"
const TIMER_AUTOSAVE_DELAY = 500

const formatTimer = (totalSeconds) => {
  const seconds = Math.max(0, totalSeconds)
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const remainingSeconds = seconds % 60

  return [hours, minutes, remainingSeconds]
    .map((value) => String(value).padStart(2, "0"))
    .join(":")
}

const formatTimerHoursMinutes = (totalSeconds) => {
  const seconds = Math.max(0, totalSeconds)
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)

  return [hours, minutes]
    .map((value) => String(value).padStart(2, "0"))
    .join(":")
}

const editableTimerValue = (totalSeconds) => formatTimerHoursMinutes(totalSeconds)

const csrfToken = () => document.querySelector('meta[name="csrf-token"]')?.content

const showTimerFeedback = (widget, message) => {
  const feedback = widget.querySelector("[data-timer-feedback]")
  if (!feedback) return

  if (message) {
    feedback.textContent = message
    feedback.hidden = false
  } else {
    feedback.textContent = ""
    feedback.hidden = true
  }
}

const serializeAutosaveFields = (form, extraFields = {}) => {
  const formData = new FormData(form)

  Object.entries(extraFields).forEach(([key, value]) => {
    formData.set(key, value)
  })

  return JSON.stringify(
    Array.from(formData.entries()).filter(([key]) => key !== "commit" && key !== "timer_action")
  )
}

const syncTimerData = (widget, timer) => {
  widget.querySelectorAll("[data-timer-display]").forEach((display) => {
    display.dataset.timerState = timer.state
    display.dataset.timerAccumulatedSeconds = timer.accumulated_seconds
    display.dataset.timerStartedAt = timer.started_at || ""
  })

  const projectName = timer.project_name || "No project selected"
  const clientName = timer.client_name || "No Client"
  const subtitle = timer.client_name || ""

  const expandedProject = widget.querySelector("[data-timer-project-name]")
  const collapsedProject = widget.querySelector("[data-timer-project-name-collapsed]")
  const expandedSubtitle = widget.querySelector("[data-timer-project-subtitle]")
  const collapsedClient = widget.querySelector("[data-timer-client-name]")
  const descriptionField = widget.querySelector('[data-timer-autosave-field="description"]')
  const projectField = widget.querySelector('[data-timer-autosave-field="project_id"]')

  if (expandedProject) expandedProject.textContent = projectName
  if (collapsedProject) collapsedProject.textContent = projectName
  if (expandedSubtitle) {
    expandedSubtitle.textContent = subtitle
    expandedSubtitle.hidden = subtitle === ""
  }
  if (collapsedClient) collapsedClient.textContent = clientName
  if (descriptionField) descriptionField.value = timer.description || ""
  if (projectField) projectField.value = timer.project_id || ""
}

const submitTimerUpdate = async (form, extraFields = {}) => {
  const widget = form.closest("[data-timer-widget]")
  if (!widget) return null

  const token = csrfToken()
  const signature = serializeAutosaveFields(form, extraFields)

  if (signature === form.dataset.lastSubmittedSignature) {
    return null
  }

  const formData = new FormData(form)
  Object.entries(extraFields).forEach(([key, value]) => {
    formData.set(key, value)
  })

  const response = await fetch(form.action, {
    method: "PATCH",
    headers: {
      Accept: "application/json",
      "X-CSRF-Token": token
    },
    body: formData,
    credentials: "same-origin"
  })

  const payload = await response.json()

  if (!response.ok) {
    throw new Error(payload.error || "Unable to update timer")
  }

  syncTimerData(widget, payload.timer)
  form.dataset.lastSubmittedSignature = serializeAutosaveFields(form)
  showTimerFeedback(widget, "")
  return payload.timer
}

const readCollapsedState = () => {
  try {
    return window.localStorage.getItem(TIMER_COLLAPSED_STORAGE_KEY) === "true"
  } catch {
    return false
  }
}

const writeCollapsedState = (collapsed) => {
  try {
    window.localStorage.setItem(TIMER_COLLAPSED_STORAGE_KEY, String(collapsed))
  } catch {
    // Ignore storage access issues and keep the current page functional.
  }
}

const syncWidgetState = (widget, collapsed) => {
  widget.classList.toggle("is-collapsed", collapsed)

  const toggle = widget.querySelector("[data-timer-toggle]")
  const collapsedPanel = widget.querySelector("[data-timer-collapsed]")

  if (toggle) {
    toggle.setAttribute("aria-expanded", String(!collapsed))
    toggle.setAttribute("aria-label", collapsed ? toggle.dataset.expandedLabel : toggle.dataset.collapsedLabel)
  }

  if (collapsedPanel) {
    collapsedPanel.hidden = !collapsed
  }
}

const mountTimerWidgetToggle = () => {
  const widget = document.querySelector("[data-timer-widget]")
  if (!widget) return

  const toggle = widget.querySelector("[data-timer-toggle]")
  if (!toggle) return

  syncWidgetState(widget, readCollapsedState())

  toggle.onclick = () => {
    const collapsed = !widget.classList.contains("is-collapsed")
    syncWidgetState(widget, collapsed)
    writeCollapsedState(collapsed)
  }
}

const mountTimerWidget = () => {
  const displays = document.querySelectorAll("[data-timer-display]")

  if (!displays.length) return

  if (window.soundlogTimerInterval) {
    clearInterval(window.soundlogTimerInterval)
  }

  const render = () => {
    displays.forEach((display) => {
      const accumulatedSeconds = Number(display.dataset.timerAccumulatedSeconds || 0)
      const startedAt = display.dataset.timerStartedAt ? Date.parse(display.dataset.timerStartedAt) : null
      const state = display.dataset.timerState

      let totalSeconds = accumulatedSeconds

      if (state === "running" && startedAt) {
        totalSeconds += Math.floor((Date.now() - startedAt) / 1000)
      }

      display.textContent = formatTimer(totalSeconds)
    })
  }

  render()
  window.soundlogTimerInterval = window.setInterval(render, 1000)
}

const mountTimerAutosave = () => {
  const form = document.querySelector("[data-timer-autosave-form]")
  if (!form) return

  const descriptionField = form.querySelector('[data-timer-autosave-field="description"]')
  const projectField = form.querySelector('[data-timer-autosave-field="project_id"]')

  form.dataset.lastSubmittedSignature = serializeAutosaveFields(form)

  let descriptionTimeout = null

  const runAutosave = async (extraFields = {}) => {
    try {
      await submitTimerUpdate(form, extraFields)
    } catch (error) {
      showTimerFeedback(form.closest("[data-timer-widget]"), error.message)
    }
  }

  if (projectField) {
    projectField.addEventListener("change", () => {
      runAutosave()
    })
  }

  if (descriptionField) {
    descriptionField.addEventListener("input", () => {
      window.clearTimeout(descriptionTimeout)
      descriptionTimeout = window.setTimeout(() => runAutosave(), TIMER_AUTOSAVE_DELAY)
    })

    descriptionField.addEventListener("blur", () => {
      window.clearTimeout(descriptionTimeout)
      runAutosave()
    })
  }
}

const mountElapsedEditor = () => {
  const widget = document.querySelector("[data-timer-widget]")
  const form = document.querySelector("[data-timer-autosave-form]")
  if (!widget || !form) return

  const toggle = widget.querySelector("[data-timer-edit-toggle]")
  const editor = widget.querySelector("[data-timer-editor]")
  const input = widget.querySelector("[data-timer-elapsed-input]")
  const display = widget.querySelector(".timer-widget__clock-button")
  const formatHint = widget.querySelector("[data-timer-format-hint]")
  if (!toggle || !editor || !input || !display || !formatHint) return

  let isEditing = false

  const closeEditor = () => {
    isEditing = false
    editor.hidden = true
    display.hidden = false
    formatHint.textContent = "HH : MM : SS"
  }

  const openEditor = () => {
    const activeDisplay = widget.querySelector(".timer-widget__clock [data-timer-display]")
    const accumulatedSeconds = Number(activeDisplay?.dataset.timerAccumulatedSeconds || 0)
    const startedAt = activeDisplay?.dataset.timerStartedAt ? Date.parse(activeDisplay.dataset.timerStartedAt) : null
    const state = activeDisplay?.dataset.timerState

    let totalSeconds = accumulatedSeconds
    if (state === "running" && startedAt) {
      totalSeconds += Math.floor((Date.now() - startedAt) / 1000)
    }

    isEditing = true
    input.value = editableTimerValue(totalSeconds)
    editor.hidden = false
    display.hidden = true
    formatHint.textContent = "HH : MM"
    input.focus()
    input.select()
  }

  const saveEditor = async () => {
    if (!isEditing) return

    try {
      await submitTimerUpdate(form, { "timer[elapsed_input]": input.value })
      closeEditor()
      mountTimerWidget()
    } catch (error) {
      showTimerFeedback(widget, error.message)
      input.focus()
      input.select()
    }
  }

  toggle.addEventListener("click", openEditor)
  document.addEventListener("click", (event) => {
    if (!isEditing) return
    if (editor.contains(event.target) || toggle.contains(event.target)) return

    showTimerFeedback(widget, "")
    closeEditor()
  })

  input.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault()
      saveEditor()
    }

    if (event.key === "Escape") {
      event.preventDefault()
      showTimerFeedback(widget, "")
      closeEditor()
    }
  })

  input.addEventListener("blur", () => {
    saveEditor()
  })
}

const mountTimerUi = () => {
  mountTimerWidgetToggle()
  mountTimerWidget()
  mountTimerAutosave()
  mountElapsedEditor()
}

const formatDisplayDate = (value) => {
  if (!value) return ""

  const [year, month, day] = value.split("-")
  if (!year || !month || !day) return value

  return `${day}/${month}/${year}`
}

const showTimeEntryFeedback = (form, message) => {
  const editorRow = form.closest("[data-time-entry-editor-row]")
  const feedbackRow = editorRow?.nextElementSibling
  if (!feedbackRow?.matches("[data-time-entry-feedback-row]")) return

  if (message) {
    feedbackRow.textContent = message
    feedbackRow.hidden = false
  } else {
    feedbackRow.textContent = ""
    feedbackRow.hidden = true
  }
}

const syncTimeEntryDisplay = (form, payload) => {
  const editorRow = form.closest("[data-time-entry-editor-row]")
  const displayRow = editorRow?.previousElementSibling
  if (!displayRow) return

  const dateCell = displayRow.querySelector('[data-time-entry-display="date"]')
  const descriptionCell = displayRow.querySelector('[data-time-entry-display="description"]')
  const hoursCell = displayRow.querySelector('[data-time-entry-display="hours"]')

  if (dateCell) dateCell.textContent = formatDisplayDate(payload.time_entry.date)
  if (descriptionCell) descriptionCell.textContent = payload.time_entry.description || "No description"
  if (hoursCell) hoursCell.textContent = payload.time_entry.hours
}

const closeTimeEntryEditor = (displayRow, reset = false) => {
  const editorRow = displayRow?.nextElementSibling
  const feedbackRow = editorRow?.nextElementSibling
  if (!editorRow?.matches("[data-time-entry-editor-row]")) return

  if (reset) {
    editorRow.querySelectorAll("[data-time-entry-field]").forEach((field) => {
      field.value = field.dataset.originalValue || ""
    })
  }

  displayRow.classList.remove("is-editing")
  editorRow.hidden = true

  if (feedbackRow?.matches("[data-time-entry-feedback-row]")) {
    feedbackRow.hidden = true
  }
}

const openTimeEntryEditor = (displayRow) => {
  const editorRow = displayRow?.nextElementSibling
  if (!editorRow?.matches("[data-time-entry-editor-row]")) return

  document.querySelectorAll("[data-time-entry-row].is-editing").forEach((row) => {
    if (row !== displayRow) closeTimeEntryEditor(row, true)
  })

  displayRow.classList.add("is-editing")
  editorRow.hidden = false
  editorRow.querySelector("[data-time-entry-field]")?.focus()
}

const mountTimeEntryInlineEditing = () => {
  const rows = document.querySelectorAll("[data-time-entry-row]")
  if (!rows.length) return

  rows.forEach((row) => {
    row.addEventListener("click", () => openTimeEntryEditor(row))
    row.addEventListener("keydown", (event) => {
      if (event.key !== "Enter" && event.key !== " ") return
      event.preventDefault()
      openTimeEntryEditor(row)
    })
  })

  const forms = document.querySelectorAll("[data-time-entry-form]")
  if (!forms.length) return

  forms.forEach((form) => {
    const displayRow = form.closest("[data-time-entry-editor-row]")?.previousElementSibling
    const fields = form.querySelectorAll("[data-time-entry-field]")
    const cancelButton = form.querySelector("[data-time-entry-cancel]")
    if (!displayRow || !fields.length) return

    fields.forEach((field) => {
      field.dataset.originalValue = field.value
    })

    form.addEventListener("submit", async (event) => {
      event.preventDefault()

      const response = await fetch(form.action, {
        method: "PATCH",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": csrfToken()
        },
        body: new FormData(form),
        credentials: "same-origin"
      })

      const payload = await response.json()

      if (!response.ok) {
        showTimeEntryFeedback(form, payload.error || "Unable to update time entry")
        return
      }

      const fieldValues = {
        "time_entry[date]": payload.time_entry.date,
        "time_entry[description]": payload.time_entry.description,
        "time_entry[hours]": payload.time_entry.hours
      }

      fields.forEach((field) => {
        if (field.name in fieldValues) {
          field.value = fieldValues[field.name] || ""
          field.dataset.originalValue = field.value
        }
      })

      syncTimeEntryDisplay(form, payload)
      showTimeEntryFeedback(form, "")
      closeTimeEntryEditor(displayRow)
    })

    cancelButton?.addEventListener("click", () => {
      closeTimeEntryEditor(displayRow, true)
    })
  })

  document.addEventListener("click", (event) => {
    const activeRow = document.querySelector("[data-time-entry-row].is-editing")
    if (!activeRow) return

    const editorRow = activeRow.nextElementSibling
    if (activeRow.contains(event.target) || editorRow?.contains(event.target)) return

    closeTimeEntryEditor(activeRow, true)
  })
}

document.addEventListener("turbo:load", mountTimerUi)
document.addEventListener("turbo:load", mountTimeEntryInlineEditing)
document.addEventListener("turbo:before-cache", () => {
  if (window.soundlogTimerInterval) {
    clearInterval(window.soundlogTimerInterval)
    window.soundlogTimerInterval = null
  }
})
