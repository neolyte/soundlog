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
  const projectPickerInput = widget.querySelector("[data-timer-project-picker-input]")

  if (expandedProject) expandedProject.textContent = projectName
  if (collapsedProject) collapsedProject.textContent = projectName
  if (expandedSubtitle) {
    expandedSubtitle.textContent = subtitle
    expandedSubtitle.hidden = subtitle === ""
  }
  if (collapsedClient) collapsedClient.textContent = clientName
  if (descriptionField) descriptionField.value = timer.description || ""
  if (projectField) projectField.value = timer.project_id || ""
  if (projectPickerInput) {
    projectPickerInput.value = timer.project_id ? `${projectName} (${clientName})` : ""
    projectPickerInput.dataset.originalValue = projectPickerInput.value
  }
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

const loadChartJs = () => {
  if (window.Chart) {
    return Promise.resolve(window.Chart)
  }

  if (window.soundlogChartJsPromise) {
    return window.soundlogChartJsPromise
  }

  window.soundlogChartJsPromise = new Promise((resolve, reject) => {
    const existingScript = document.querySelector('script[data-chartjs-loader="true"]')
    if (existingScript) {
      existingScript.addEventListener("load", () => resolve(window.Chart), { once: true })
      existingScript.addEventListener("error", reject, { once: true })
      return
    }

    const script = document.createElement("script")
    script.src = "https://cdn.jsdelivr.net/npm/chart.js@4.4.3/dist/chart.umd.min.js"
    script.async = true
    script.dataset.chartjsLoader = "true"
    script.onload = () => resolve(window.Chart)
    script.onerror = reject
    document.head.append(script)
  })

  return window.soundlogChartJsPromise
}

const mountDashboardChart = async () => {
  const canvas = document.querySelector("[data-dashboard-hours-chart]")
  if (!canvas) return

  if (canvas.chartInstance) {
    canvas.chartInstance.destroy()
  }

  const labels = JSON.parse(canvas.dataset.dashboardChartLabels || "[]")
  const values = JSON.parse(canvas.dataset.dashboardChartValues || "[]")
  const Chart = await loadChartJs()
  if (!Chart) return

  canvas.chartInstance = new Chart(canvas, {
    type: "line",
    data: {
      labels,
      datasets: [
        {
          label: "Hours logged",
          data: values,
          borderColor: "#1f2937",
          backgroundColor: "rgba(31, 41, 55, 0.10)",
          borderWidth: 2,
          fill: true,
          tension: 0.35,
          pointRadius: 3,
          pointHoverRadius: 4,
          pointBackgroundColor: "#1f2937",
          pointBorderWidth: 0
        }
      ]
    },
    options: {
      animation: false,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: false
        },
        tooltip: {
          displayColors: false,
          callbacks: {
            label: (context) => `${context.parsed.y.toFixed(2)} hours`
          }
        }
      },
      scales: {
        x: {
          grid: {
            display: false
          },
          ticks: {
            color: "#64748b"
          },
          border: {
            display: false
          }
        },
        y: {
          beginAtZero: true,
          ticks: {
            color: "#64748b",
            callback: (value) => `${value}h`
          },
          grid: {
            color: "rgba(148, 163, 184, 0.15)"
          },
          border: {
            display: false
          }
        }
      }
    }
  })
}

const formatDisplayDate = (value) => {
  if (!value) return ""

  const [year, month, day] = value.split("-")
  if (!year || !month || !day) return value

  return `${day}/${month}/${year}`
}

const formatHoursInput = (value) => {
  const normalized = String(value || "").trim()
  if (normalized === "") return ""

  if (normalized.includes(":")) {
    const parts = normalized.split(":")
    if (parts.length !== 2 || parts.some((part) => !/^\d+$/.test(part))) return normalized

    const hours = String(Number(parts[0]))
    const minutes = parts[1].padStart(2, "0")
    if (Number(minutes) >= 60) return normalized

    return `${hours}:${minutes}`
  }

  const decimalHours = Number(normalized.replace(",", "."))
  if (!Number.isFinite(decimalHours) || decimalHours < 0) return normalized

  const totalMinutes = Math.round(decimalHours * 60)
  const hours = String(Math.floor(totalMinutes / 60))
  const minutes = String(totalMinutes % 60).padStart(2, "0")
  return `${hours}:${minutes}`
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

const flashTimeEntrySuccess = (displayRow) => {
  if (!displayRow) return

  displayRow.classList.remove("is-success")
  // Force reflow so the animation can replay on repeated saves.
  void displayRow.offsetWidth
  displayRow.classList.add("is-success")

  window.setTimeout(() => {
    displayRow.classList.remove("is-success")
  }, 1800)
}

const updateTimeEntryLedgerTotal = () => {
  const footer = document.querySelector(".time-entries-ledger__footer-hours")
  if (!footer) return

  const totalHours = Array.from(document.querySelectorAll("[data-time-entry-row]"))
    .reduce((sum, row) => sum + Number(row.dataset.timeEntryHoursValue || 0), 0)

  const totalMinutes = Math.round(totalHours * 60)
  const hours = Math.floor(totalMinutes / 60)
  const minutes = String(totalMinutes % 60).padStart(2, "0")
  footer.textContent = `Total: ${hours}:${minutes}`
}

const syncTimeEntryDisplay = (form, payload) => {
  const editorRow = form.closest("[data-time-entry-editor-row]")
  const displayRow = editorRow?.previousElementSibling
  if (!displayRow) return

  const dateCell = displayRow.querySelector('[data-time-entry-display="date"]')
  const projectCell = displayRow.querySelector('[data-time-entry-display="project"]')
  const descriptionCell = displayRow.querySelector('[data-time-entry-display="description"]')
  const hoursCell = displayRow.querySelector('[data-time-entry-display="hours"]')

  if (dateCell) dateCell.textContent = formatDisplayDate(payload.time_entry.date)
  if (projectCell) {
    const projectName = projectCell.querySelector("strong")
    const clientName = projectCell.querySelector("span")
    if (projectName) projectName.textContent = payload.time_entry.project_name
    if (clientName) clientName.textContent = `(${payload.time_entry.client_name})`
  }
  if (descriptionCell) descriptionCell.textContent = payload.time_entry.description || "No description"
  if (hoursCell) hoursCell.textContent = payload.time_entry.hours
}

const projectPickerOptions = (picker) => {
  const sourceId = picker?.dataset.projectPickerSource || "time-entry-project-options"
  const source = document.querySelector(`#${sourceId}`)
  if (!source) return []

  try {
    return JSON.parse(source.textContent || "[]")
  } catch {
    return []
  }
}

const projectOptionMap = (picker) => {
  const byLabel = new Map()
  const byId = new Map()

  projectPickerOptions(picker).forEach((option) => {
    if (!option?.label || !option?.id) return

    byLabel.set(option.label, String(option.id))
    byId.set(String(option.id), option.label)
  })

  return { byLabel, byId }
}

const syncProjectPickerFromLabel = (input) => {
  const picker = input.closest("[data-project-picker]")
  const hiddenField = picker?.querySelector("[data-project-picker-hidden]")
  if (!hiddenField) return

  hiddenField.value = projectOptionMap(picker).byLabel.get(input.value) || ""
}

const restoreProjectPicker = (input) => {
  const picker = input.closest("[data-project-picker]")
  const hiddenField = picker?.querySelector("[data-project-picker-hidden]")
  if (!hiddenField) return

  input.value = projectOptionMap(picker).byId.get(hiddenField.value) || input.dataset.originalValue || ""
}

const renderProjectPickerOptions = (picker, query = "") => {
  const menu = picker.querySelector("[data-project-picker-menu]")
  const hiddenField = picker.querySelector("[data-project-picker-hidden]")
  if (!menu || !hiddenField) return

  const normalizedQuery = query.trim().toLowerCase()
  const options = projectPickerOptions(picker)
    .filter((option) => option.label.toLowerCase().includes(normalizedQuery))
    .slice(0, 40)

  menu.innerHTML = ""

  if (!options.length) {
    const emptyState = document.createElement("div")
    emptyState.className = "project-picker__empty"
    emptyState.textContent = "No matching projects"
    menu.append(emptyState)
    return
  }

  options.forEach((option) => {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "project-picker__option"
    button.textContent = option.label
    if (String(option.id) === hiddenField.value) {
      button.classList.add("is-active")
    }

    button.addEventListener("mousedown", (event) => {
      event.preventDefault()
    })

    button.addEventListener("click", () => {
      const input = picker.querySelector("[data-project-picker-input]")
      if (!input) return

      input.value = option.label
      hiddenField.value = String(option.id)
      input.setCustomValidity("")
      menu.hidden = true
      hiddenField.dispatchEvent(new Event("change", { bubbles: true }))
    })

    menu.append(button)
  })
}

const mountProjectPickers = () => {
  document.querySelectorAll("[data-project-picker]").forEach((picker) => {
    const input = picker.querySelector("[data-project-picker-input]")
    const menu = picker.querySelector("[data-project-picker-menu]")
    const hiddenField = picker.querySelector("[data-project-picker-hidden]")
    if (!input || !menu || !hiddenField) return
    if (input.dataset.projectPickerMounted === "true") return

    input.dataset.projectPickerMounted = "true"

    if (hiddenField.value && !input.value) {
      input.value = projectOptionMap(picker).byId.get(hiddenField.value) || ""
    }

    input.dataset.originalValue = input.value

    input.addEventListener("input", () => {
      syncProjectPickerFromLabel(input)
      renderProjectPickerOptions(picker, input.value)
      menu.hidden = false
      input.setCustomValidity("")
    })

    input.addEventListener("focus", () => {
      renderProjectPickerOptions(picker, input.value)
      menu.hidden = false
    })

    input.addEventListener("blur", () => {
      window.setTimeout(() => {
        menu.hidden = true
      }, 120)
    })

    input.addEventListener("keydown", (event) => {
      if (event.key === "Escape") {
        menu.hidden = true
      }
    })
  })
}

const mountTimeEntryHoursFormatting = () => {
  document.querySelectorAll("[data-time-entry-hours-input]").forEach((input) => {
    if (input.dataset.hoursFormattingMounted === "true") return

    input.dataset.hoursFormattingMounted = "true"

    input.addEventListener("blur", () => {
      input.value = formatHoursInput(input.value)
    })
  })
}

const closeTimeEntryCreatePanel = (reset = false) => {
  const panel = document.querySelector("[data-time-entry-create-panel]")
  if (!panel) return

  if (reset) {
    const form = panel.querySelector("[data-time-entry-create-form]")
    form?.reset()
    form?.querySelectorAll("[data-project-picker-input]").forEach((input) => {
      restoreProjectPicker(input)
      input.setCustomValidity("")
    })
  }

  panel.hidden = true
  document.querySelectorAll("[data-time-entry-create-toggle]").forEach((toggle) => {
    toggle.setAttribute("aria-expanded", "false")
  })
}

const openTimeEntryCreatePanel = () => {
  const panel = document.querySelector("[data-time-entry-create-panel]")
  if (!panel) return

  document.querySelectorAll("[data-time-entry-row].is-editing").forEach((row) => {
    closeTimeEntryEditor(row, true)
  })

  panel.hidden = false
  document.querySelectorAll("[data-time-entry-create-toggle]").forEach((toggle) => {
    toggle.setAttribute("aria-expanded", "true")
  })

  panel.querySelector("[data-time-entry-create-focus], [data-time-entry-create-field]:not([data-project-picker-input])")?.focus()
}

const closeTimeEntryEditor = (displayRow, reset = false) => {
  const editorRow = displayRow?.nextElementSibling
  const feedbackRow = editorRow?.nextElementSibling
  if (!editorRow?.matches("[data-time-entry-editor-row]")) return

  if (reset) {
    editorRow.querySelectorAll("[data-time-entry-field]").forEach((field) => {
      field.value = field.dataset.originalValue || ""
    })
    editorRow.querySelectorAll("[data-project-picker-input]").forEach((input) => {
      restoreProjectPicker(input)
      input.setCustomValidity("")
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

  closeTimeEntryCreatePanel(true)

  document.querySelectorAll("[data-time-entry-row].is-editing").forEach((row) => {
    if (row !== displayRow) closeTimeEntryEditor(row, true)
  })

  displayRow.classList.add("is-editing")
  editorRow.hidden = false
  editorRow.querySelector('[data-time-entry-field="hours"]')?.focus()
}

const mountTimeEntryInlineEditing = () => {
  mountProjectPickers()
  mountTimeEntryHoursFormatting()

  const createPanel = document.querySelector("[data-time-entry-create-panel]")
  const createForm = createPanel?.querySelector("[data-time-entry-create-form]")
  const createCancelButton = createPanel?.querySelector("[data-time-entry-create-cancel]")
  const createToggles = document.querySelectorAll("[data-time-entry-create-toggle]")

  createToggles.forEach((toggle) => {
    toggle.addEventListener("click", () => {
      if (createPanel?.hidden) {
        openTimeEntryCreatePanel()
      } else {
        closeTimeEntryCreatePanel(createForm?.dataset.hasErrors !== "true")
      }
    })
  })

  createCancelButton?.addEventListener("click", () => {
    closeTimeEntryCreatePanel(true)
  })

  if (createForm?.dataset.hasErrors === "true") {
    openTimeEntryCreatePanel()
  }

  createForm?.addEventListener("submit", (event) => {
    const projectPickerInput = createForm.querySelector("[data-project-picker-input]")
    const projectHiddenField = createForm.querySelector("[data-project-picker-hidden]")
    if (!projectPickerInput || !projectHiddenField || projectHiddenField.value) return

    event.preventDefault()
    projectPickerInput.setCustomValidity("Select a project from the list")
    projectPickerInput.reportValidity()
  })

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

      const projectPickerInput = form.querySelector("[data-project-picker-input]")
      const projectHiddenField = form.querySelector("[data-project-picker-hidden]")
      if (projectPickerInput && projectHiddenField && !projectHiddenField.value) {
        projectPickerInput.setCustomValidity("Select a project from the list")
        projectPickerInput.reportValidity()
        return
      }

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
        "time_entry[project_id]": String(payload.time_entry.project_id),
        "time_entry[date]": payload.time_entry.date,
        "time_entry[description]": payload.time_entry.description,
        "time_entry[hours]": payload.time_entry.input_hours
      }

      fields.forEach((field) => {
        if (field.name in fieldValues) {
          field.value = fieldValues[field.name] || ""
          field.dataset.originalValue = field.value
        }
      })

      const projectPickerField = form.querySelector("[data-project-picker-input]")
      if (projectPickerField) {
        projectPickerField.value = `${payload.time_entry.project_name} (${payload.time_entry.client_name})`
        projectPickerField.dataset.originalValue = projectPickerField.value
        projectPickerField.setCustomValidity("")
      }

      syncTimeEntryDisplay(form, payload)
      flashTimeEntrySuccess(displayRow)
      showTimeEntryFeedback(form, "")
      closeTimeEntryEditor(displayRow)
    })

    cancelButton?.addEventListener("click", () => {
      closeTimeEntryEditor(displayRow, true)
    })

    const deleteButton = form.querySelector("[data-time-entry-delete]")
    deleteButton?.addEventListener("click", async () => {
      if (!window.confirm("Delete this time entry?")) return

      const response = await fetch(deleteButton.dataset.timeEntryDeleteUrl, {
        method: "DELETE",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": csrfToken()
        },
        credentials: "same-origin"
      })

      const payload = await response.json()

      if (!response.ok) {
        showTimeEntryFeedback(form, payload.error || "Unable to delete time entry")
        return
      }

      form.closest("[data-time-entry-item]")?.remove()

      if (!document.querySelector("[data-time-entry-item]")) {
        window.location.reload()
        return
      }

      updateTimeEntryLedgerTotal()
    })
  })

  document.addEventListener("click", (event) => {
    const activeRow = document.querySelector("[data-time-entry-row].is-editing")
    if (!activeRow) return

    const editorRow = activeRow.nextElementSibling
    if (activeRow.contains(event.target) || editorRow?.contains(event.target)) return

    closeTimeEntryEditor(activeRow, true)
  })

  document.querySelectorAll("[data-time-entry-row].is-success").forEach((row) => {
    flashTimeEntrySuccess(row)
  })
}

document.addEventListener("turbo:load", mountTimerUi)
document.addEventListener("turbo:load", mountTimeEntryInlineEditing)
document.addEventListener("turbo:load", mountDashboardChart)
document.addEventListener("turbo:before-cache", () => {
  document.querySelectorAll("[data-dashboard-hours-chart]").forEach((canvas) => {
    canvas.chartInstance?.destroy()
    canvas.chartInstance = null
  })

  if (window.soundlogTimerInterval) {
    clearInterval(window.soundlogTimerInterval)
    window.soundlogTimerInterval = null
  }

  document.querySelectorAll("[data-time-entry-editor-row]").forEach((row) => {
    row.hidden = true
  })

  document.querySelectorAll("[data-time-entry-feedback-row]").forEach((row) => {
    row.hidden = true
  })

  document.querySelectorAll("[data-time-entry-row]").forEach((row) => {
    row.classList.remove("is-editing")
  })

  const createPanel = document.querySelector("[data-time-entry-create-panel]")
  if (createPanel) {
    createPanel.hidden = true
  }

  document.querySelectorAll("[data-time-entry-create-toggle]").forEach((toggle) => {
    toggle.setAttribute("aria-expanded", "false")
  })

  document.querySelectorAll("[data-project-picker-menu]").forEach((menu) => {
    menu.hidden = true
  })
})
