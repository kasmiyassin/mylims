// --- Core ELN Application Logic (common_scripts.js) ---
// This file contains all shared variables, utilities, API calls, and logic for 
// the multi-page application (Dashboard, Editor, View, Run).

let currentProtocolData = null; 
let currentUser = { person_id: null, full_name: 'Loading User...' }; 
let stepCounter = 0; 
let reagentCounter = 0; 
let componentCounter = 0; 
let autosaveTimer;
let currentModalCallback = null; 
let currentTimerInterval = null; 

// Base URL for API calls relative to the domain root, matching Flask setup.
const API_BASE = '/mylims_demo/api'; 
const mdConverter = new showdown.Converter();
mdConverter.setOption('simpleLineBreaks', true); 
mdConverter.setOption('tables', true);

// --- Bootstrap Modal References (Must be retrieved after DOM content load) ---
let confirmationModal;
let shareModal;
let previewOffcanvas;

// --- UTILITY FUNCTIONS ---

function initBootstrapComponents() {
    const confirmationModalEl = document.getElementById('confirmationModal');
    const shareModalEl = document.getElementById('shareModal');
    const previewOffcanvasEl = document.getElementById('previewOffcanvas');

    if (confirmationModalEl) confirmationModal = new bootstrap.Modal(confirmationModalEl);
    if (shareModalEl) shareModal = new bootstrap.Modal(shareModalEl);
    if (previewOffcanvasEl) previewOffcanvas = new bootstrap.Offcanvas(previewOffcanvasEl);

    if (document.getElementById('btn-modal-confirm')) {
        document.getElementById('btn-modal-confirm').addEventListener('click', () => { 
             if (confirmationModal) confirmationModal.hide();
             if (currentModalCallback) {
                  currentModalCallback();
                  currentModalCallback = null;
             }
        });
    }
}


function showConfirmationModal(title, body, confirmCallback, confirmText = "Confirm") { 
    document.getElementById('modal-title').innerHTML = title;
    document.getElementById('modal-body').innerHTML = body;
    document.getElementById('btn-modal-confirm').textContent = confirmText;
    currentModalCallback = confirmCallback;
    if (confirmationModal) confirmationModal.show();
}

function handleClipboardCopy(e) { 
    const linkInput = document.getElementById('share-link-input');
    if (linkInput) {
        linkInput.select();
        linkInput.setSelectionRange(0, 99999); 
        document.execCommand('copy');
        const originalText = e.currentTarget.innerHTML;
        e.currentTarget.innerHTML = '<i class="bi bi-check-lg"></i> Copied!';
        setTimeout(() => {
            e.currentTarget.innerHTML = originalText;
        }, 2000);
    }
}

// --- API HELPER ---

async function apiCall(endpoint, method = 'GET', data = null) {
    const url = `${window.location.origin}${API_BASE}${endpoint}`; 
    
    const options = {
        method,
        headers: { 'Content-Type': 'application/json' },
    };
    if (data && (method === 'POST' || method === 'PUT')) {
        options.body = JSON.stringify(data);
    }

    try {
        console.log(`API Call: ${method} ${url}`, data ? `Data: ${JSON.stringify(data).substring(0, 100)}...` : '');
        const response = await fetch(url, options);
        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ error: `HTTP error! status: ${response.status}`, details: response.statusText }));
            console.error(`API Error (${method} ${url}):`, response.status, errorData);
            showConfirmationModal('API Error', `Failed: ${method} ${endpoint}<br>Status: ${response.status}<br>Message: ${errorData.error || 'Unknown error'} ${errorData.details ? '<br>Details: '+errorData.details : ''}`, () => {}, "OK");
            throw new Error(errorData.error || `HTTP error ${response.status}`);
        }
        if (response.status === 204) { return null; } 
        const contentType = response.headers.get("content-type");
        if (contentType && contentType.indexOf("application/json") !== -1) {
             return await response.json();
        } else {
             return null;
        }
    } catch (error) {
        console.error(`Fetch Error (${method} ${url}):`, error);
        showConfirmationModal('Network Error', `Could not connect or process request for ${endpoint}. Error: ${error.message}`, () => {}, "OK");
        throw error; 
    }
}

// --- NEW DIAGNOSTIC FUNCTION ---
async function checkConnectionAndAuth() {
    try {
        // Attempt to check session status
        const response = await fetch('/mylims_demo/api/login', { method: 'GET' });
        const data = await response.json();
        const userWelcomeEl = document.getElementById('user-welcome');

        if (data && data.user && data.user.full_name) {
            // Success: Session active and user identified
            currentUser = { person_id: data.user.person_id, full_name: data.user.full_name };
            userWelcomeEl.textContent = `Welcome, ${data.user.full_name} 👩‍🔬`;
            console.info("Connection Status: OK. User is authenticated.");
            return true;
        } else {
            // Failure: Session invalid or expired
            currentUser = { person_id: null, full_name: 'Unauthenticated' };
            userWelcomeEl.textContent = `Welcome, Guest 🧐`;
            console.warn("Connection Status: OK, but session expired/invalid. Redirecting to login...");
            // Redirect if not already on the login page (to prevent infinite loop)
            if (!window.location.pathname.toLowerCase().includes('login.html')) {
                window.location.href = '../login.html';
            }
            return false;
        }
    } catch (e) {
        // Network or API route failure
        currentUser = { person_id: null, full_name: 'Connection Error' };
        document.getElementById('user-welcome').textContent = `Connection Error ❌`;
        console.error("Connection Status: FAILED. API route or network unreachable.", e);
        showConfirmationModal("Connection Error", "Cannot connect to the LIMS API. Please ensure Flask server is running.", () => {}, "OK");
        return false;
    }
}
// --- END DIAGNOSTIC FUNCTION ---


// --- PATH CORRECTION UTILITY ---
// This function ensures correct relative paths are used based on the assumption
// that app files are in ./protocols and login/scripts are in ./

function getRelativePath(targetFile) {
    // Current file structure assumption: Protocols pages are in ./protocols/, Login is in ./
    
    // Check if we are linking from an HTML file within ./protocols/
    const isInsideProtocolsDir = window.location.pathname.toLowerCase().includes('/protocol_manager_');
    
    if (isInsideProtocolsDir) {
        if (targetFile.includes('login.html') || targetFile.includes('common_scripts.js')) {
            // Linking up to the root directory
            return `../${targetFile}`;
        }
    }
    // Assume other links (protocol to protocol) are relative within the same directory
    return targetFile;
}

// --- DASHBOARD FUNCTIONS (Used by dashboard.html) ---

function getStatusBadge(statusId) {
    statusId = statusId ? statusId.toLowerCase() : 'draft';
    let badgeClass = 'bg-secondary';
    let icon = 'bi-pencil-square'; 
    if (statusId === 'published') {
        badgeClass = 'bg-primary';
        icon = 'bi-globe'; 
    } else if (statusId === 'completed') {
        badgeClass = 'bg-success';
        icon = 'bi-check-circle-fill';
    } else if (statusId === 'archived') {
        badgeClass = 'bg-warning text-dark';
        icon = 'bi-archive-fill'; 
    } else if (statusId === 'in progress') {
        badgeClass = 'bg-info text-dark';
        icon = 'bi-hourglass-split';
    } else if (statusId === 'draft') {
        badgeClass = 'bg-dark';
        icon = 'bi-pencil-square';
    }
    return { badgeClass, icon };
}

function createProtocolCardHtml(protocol, tagsString = '') {
     const { badgeClass, icon } = getStatusBadge(protocol.status_id);
     const tagsHtml = tagsString.split(',')
                                .map(t => t.trim() ? `<span class="tag me-1">${t.trim()}</span>` : '')
                                .join('');
     const descriptionSnippet = protocol.description ? protocol.description.substring(0, 100) + (protocol.description.length > 100 ? '...' : '') : 'No description.';
     const updatedAt = protocol.updated_at ? new Date(protocol.updated_at).toLocaleDateString() : 'N/A';
     const authors = protocol.author_person_id || 'Unknown Author';

    return `
        <div class="col-md-6 col-lg-4 mb-4">
            <div class="card h-100 protocol-card shadow-sm">
                <div class="card-body d-flex flex-column">
                    <h5 class="card-title mb-2 text-dark">${protocol.title || 'Untitled Protocol'} 
                        <span class="badge ${badgeClass} ms-2"><i class="bi ${icon}"></i> ${protocol.status_id || 'Draft'}</span>
                    </h5>
                    <p class="card-subtitle text-muted small mb-2">
                        v${protocol.version || 1} | By: ${authors} | Updated: ${updatedAt}
                    </p>
                    <p class="card-text small text-muted flex-grow-1">${descriptionSnippet}</p>
                    <div class="mt-2">${tagsHtml}</div>
                </div>
                <div class="card-footer d-flex justify-content-end gap-2">
                    <a href="protocol_manager_view.html#view=${protocol.protocol_id}" class="btn btn-sm btn-outline-primary btn-view" data-id="${protocol.protocol_id}" title="View"><i class="bi bi-eye-fill"></i> View</a>
                    <a href="protocol_manager_editor.html#edit=${protocol.protocol_id}" class="btn btn-sm btn-outline-secondary btn-edit" data-id="${protocol.protocol_id}" title="Edit"><i class="bi bi-pencil-fill"></i></a>
                    <button class="btn btn-sm btn-outline-info btn-duplicate" data-id="${protocol.protocol_id}" title="Duplicate"><i class="bi bi-copy"></i></button>
                    <button class="btn btn-sm btn-outline-danger btn-delete" data-id="${protocol.protocol_id}" title="Delete"><i class="bi bi-trash-fill"></i></button>
                </div>
            </div>
        </div>`;
}

// --- EDITOR FUNCTIONS (Used by editor.html) ---

function formatComponentValue(value) { return value ? value.replace(/</g, "&lt;").replace(/>/g, "&gt;") : '<i class="text-muted">N/A</i>'; }

function createComponentHtml(stepId, type, data = {}) {
     componentCounter++;
     const compId = data.id || `comp-${Date.now()}-${componentCounter}`; 
     let fieldsHtml = '';
     let iconClass = 'bi-box';

     switch(type) {
         case 'Centrifuge':
             iconClass = 'bi-arrow-repeat';
             fieldsHtml = `
                 <input type="text" class="form-control form-control-sm mb-1" placeholder="Speed (e.g., 10000 rpm)" value="${data.speed || ''}" data-field="speed">
                 <input type="text" class="form-control form-control-sm mb-1" placeholder="Time (e.g., 5 min)" value="${data.time || ''}" data-field="time">
                 <input type="text" class="form-control form-control-sm" placeholder="Temp (°C, optional)" value="${data.temp || ''}" data-field="temp">`;
             break;
         case 'Shake':
             iconClass = 'bi-phone-vibrate';
             fieldsHtml = `
                 <input type="text" class="form-control form-control-sm mb-1" placeholder="Speed (e.g., 200 rpm)" value="${data.speed || ''}" data-field="speed">
                 <input type="text" class="form-control form-control-sm" placeholder="Time (e.g., 30 min)" value="${data.time || ''}" data-field="time">`;
             break;
         case 'Incubate':
             iconClass = 'bi-thermometer-half';
              fieldsHtml = `
                 <input type="text" class="form-control form-control-sm mb-1" placeholder="Temp (°C)" value="${data.temp || ''}" data-field="temp">
                 <input type="text" class="form-control form-control-sm" placeholder="Time (e.g., 1 hr)" value="${data.time || ''}" data-field="time">`;
             break;
         case 'Cool':
              iconClass = 'bi-snow';
              fieldsHtml = `
                 <input type="text" class="form-control form-control-sm mb-1" placeholder="Temp (°C, e.g., 4)" value="${data.temp || ''}" data-field="temp">
                 <input type="text" class="form-control form-control-sm" placeholder="Time (e.g., 10 min)" value="${data.time || ''}" data-field="time">`;
             break;
          case 'Reagent':
              iconClass = 'bi-beaker';
              fieldsHtml = `
                 <input type="text" class="form-control form-control-sm mb-1" placeholder="Reagent Name/ID (lims.reagents)" value="${data.name || ''}" data-field="name">
                 <input type="text" class="form-control form-control-sm mb-1" placeholder="Quantity (e.g., 10 ul)" value="${data.quantity || ''}" data-field="quantity">
                 <input type="text" class="form-control form-control-sm" placeholder="Concentration (optional)" value="${data.concentration || ''}" data-field="concentration">`;
             break;
          case 'Equipment':
               iconClass = 'bi-wrench';
               fieldsHtml = `<input type="text" class="form-control form-control-sm" placeholder="Equipment Name/ID (lims.equipment)" value="${data.name || ''}" data-field="name">`;
             break;
         default:
             fieldsHtml = `<input type="text" class="form-control form-control-sm" placeholder="Parameter" value="${data.param || ''}" data-field="param">`;
     }
     
     return `
         <div class="component-card card-sm" id="${compId}" data-component-id="${compId}" data-component-type="${type}">
              <button type="button" class="btn-close btn-sm btn-remove-component" aria-label="Remove Component"></button>
             <strong class="mb-1 small d-block"><i class="${iconClass} me-1"></i> ${type}</strong>
             ${fieldsHtml}
         </div>`;
}

function createStepCardHtml(stepId, stepNum, data = {}) { 
     const isCollapsed = stepNum > 1; 
     const componentsHtml = (data.components || []).map(comp => createComponentHtml(stepId, comp.type, comp)).join('');
     const durationValue = data.estimated_time_minutes ? `${data.estimated_time_minutes} min` : (data.duration || '');

     return `
        <div class="step-card shadow-sm" id="${stepId}" draggable="true" data-step-id="${data.step_id || ''}" data-step-number="${stepNum}">
            <!-- Step Header -->
            <div class="step-header">
                <div class="step-header-left">
                    <i class="bi bi-grip-vertical step-drag-handle grab-cursor" title="Drag to reorder ⋮⋮"></i>
                    <strong class="text-primary me-2">Step ${stepNum}:</strong>
                    <input type="text" id="${stepId}-title" class="form-control form-control-sm step-title-input" value="${data.title || ''}" placeholder="Enter step title" required>
                </div>
                <div class="btn-group btn-group-sm">
                    <button type="button" class="btn btn-outline-secondary btn-duplicate-step" title="Duplicate Step"><i class="bi bi-copy"></i></button>
                    <button type="button" class="btn btn-outline-danger btn-remove-step" title="Delete Step"><i class="bi bi-trash"></i></button>
                    <button type="button" class="btn btn-outline-secondary btn-toggle-collapse" data-bs-toggle="collapse" data-bs-target="#collapse-${stepId}" title="Toggle Step">
                        <i class="bi ${isCollapsed ? 'bi-arrows-expand' : 'bi-arrows-collapse'}"></i>
                    </button>
                </div>
            </div>
            <!-- Step Body (Collapsible) -->
            <div class="step-body collapse ${isCollapsed ? '' : 'show'}" id="collapse-${stepId}">
                <!-- Markdown Editor -->
                <label class="form-label fw-bold small text-muted">DESCRIPTION (Supports Markdown)</label>
                <div class="markdown-toolbar btn-group btn-group-sm">
                    <button type="button" class="btn btn-outline-secondary btn-markdown" data-action="bold"><b>B</b></button>
                    <button type="button" class="btn btn-outline-secondary btn-markdown" data-action="italic"><i>I</i></button>
                    <button type="button" class="btn btn-outline-secondary btn-markdown" data-action="code"><code>&lt;/&gt;</code></button>
                    <button type="button" class="btn btn-outline-secondary btn-markdown" data-action="list"><i class="bi bi-list-ul"></i></button>
                    <button type="button" class="btn btn-outline-secondary btn-markdown" data-action="link"><i class="bi bi-link-45deg"></i></button>
                    <button type="button" class="btn btn-outline-secondary btn-markdown" data-action="toggle-preview" title="Toggle Preview"><i class="bi bi-eye-fill"></i></button>
                </div>
                <div class="markdown-editor-area d-flex">
                    <textarea id="${stepId}-desc" class="form-control step-description" rows="6" placeholder="Describe the step procedure and key steps here.">${data.description || ''}</textarea>
                    <div id="${stepId}-preview" class="markdown-preview d-none flex-grow-1"></div> 
                </div>

                <!-- Components -->
                <div class="mt-4 border-top pt-3">
                    <label class="form-label fw-bold small text-muted">STEP COMPONENTS (Structured Data)</label>
                    <div class="btn-group btn-group-sm mb-2 component-add-buttons flex-wrap">
                        <button type="button" class="btn btn-outline-dark" data-component-type="Centrifuge"><i class="bi bi-arrow-repeat"></i> Centrifuge</button>
                        <button type="button" class="btn btn-outline-dark" data-component-type="Shake"><i class="bi bi-phone-vibrate"></i> Shake/Mix</button>
                        <button type="button" class="btn btn-outline-dark" data-component-type="Incubate"><i class="bi bi-thermometer-half"></i> Incubate</button>
                        <button type="button" class="btn btn-outline-dark" data-component-type="Cool"><i class="bi bi-snow"></i> Cool</button>
                        <button type="button" class="btn btn-outline-dark" data-component-type="Reagent"><i class="bi bi-beaker"></i> Reagent</button>
                        <button type="button" class="btn btn-outline-dark" data-component-type="Equipment"><i class="bi bi-wrench"></i> Equipment</button>
                    </div>
                    <div class="step-components-container mt-2 d-flex flex-wrap gap-2">
                         ${componentsHtml}
                    </div>
                </div>

                <!-- Details Row (Reagents, Duration, Timer) -->
                <div class="row mt-4 g-3 border-top pt-3">
                    <div class="col-md-6">
                        <label for="${stepId}-reagents" class="form-label small text-muted">REAGENTS USED (Informational Only)</label>
                        <input type="text" id="${stepId}-reagents" class="form-control form-control-sm" value="${data.reagents || ''}" placeholder="e.g., PBS, Ethanol">
                    </div>
                    <div class="col-md-3">
                        <label for="${stepId}-duration" class="form-label small text-muted">EST. DURATION (e.g., 15 min)</label>
                        <input type="text" id="${stepId}-duration" class="form-control form-control-sm" value="${durationValue}" placeholder="e.g., 15 min">
                    </div>
                    <div class="col-md-3">
                        <label for="${stepId}-timer" class="form-label small text-muted">TIMER DURATION (e.g., 5 min)</label>
                        <input type="text" id="${stepId}-timer" class="form-control form-control-sm" value="${data.timer || ''}" placeholder="e.g., 5 min, 90 sec">
                    </div>
                </div>

                <!-- Attachments -->
                <div class="mt-4 border-top pt-3">
                    <label class="form-label fw-bold small text-muted">ATTACHMENTS (Local Mockup)</label>
                    <div class="file-upload-area mb-2">
                        <i class="bi bi-cloud-arrow-up-fill fs-2 text-secondary"></i>
                        <p class="mb-0 text-muted small">Drag & drop files here or click to browse</p>
                        <input type="file" class="file-input visually-hidden" id="file-${stepId}" multiple>
                    </div>
                    <div class="file-preview-list" id="file-preview-${stepId}">
                        <!-- File previews added here -->
                    </div>
                </div>
            </div>
        </div>`;
}


function serializeStep(stepElementId) { 
    const card = document.getElementById(stepElementId); if (!card) return null;
    const attachmentNames = []; 
    card.querySelectorAll('.file-preview-item').forEach(item => attachmentNames.push(item.dataset.filename));
    
    const components = [];
    card.querySelectorAll('.component-card').forEach(compCard => {
        const componentData = { 
             type: compCard.dataset.componentType 
        };
        compCard.querySelectorAll('input[data-field]').forEach(input => { 
             componentData[input.dataset.field] = input.value; 
        });
        components.push(componentData);
    });
    
    let estimatedTimeMinutes = null; 
    const durationInput = card.querySelector(`#${stepElementId}-duration`).value; 
    if (durationInput) {
         const numMatch = durationInput.match(/(\d+(\.\d+)?)\s*(min|hr|h|sec|s)?/i); 
         if (numMatch) {
              const num = parseFloat(numMatch[1]);
              const unit = numMatch[3]?.toLowerCase();
              if (unit === 'hr' || unit === 'h') {
                   estimatedTimeMinutes = Math.round(num * 60); 
              } else if (unit === 'sec' || unit === 's') {
                   estimatedTimeMinutes = Math.round(num / 60); 
              } else {
                   estimatedTimeMinutes = Math.round(num); 
              }
              estimatedTimeMinutes = Math.max(1, estimatedTimeMinutes); 
         }
    }
    
    const stepData = {
        client_id: stepElementId, 
        step_id: card.dataset.stepId || null, 
        step_number: parseInt(card.dataset.stepNumber, 10), 
        title: card.querySelector(`#${stepId}-title`).value,
        description: card.querySelector(`#${stepId}-desc`).value,
        reagents: card.querySelector(`#${stepId}-reagents`).value, 
        estimated_time_minutes: estimatedTimeMinutes, 
        timer: card.querySelector(`#${stepId}-timer`).value, 
        attachments: attachmentNames, 
        components: components 
    };
    return stepData;
}

function serializeEditor() {
    const stepsContainer = document.getElementById('steps-container');
    const reagentListEditor = document.getElementById('reagent-list-editor');
    const protocolProjectSelect = document.getElementById('protocol-project');

    const steps = [];
    stepsContainer.querySelectorAll('.step-card').forEach(card => {
        const stepData = serializeStep(card.id); 
        if (stepData) steps.push(stepData);
    });
    steps.sort((a, b) => a.step_number - b.step_number); 
    
    const reagentsList = []; 
    reagentListEditor.querySelectorAll('.reagent-input').forEach(input => { 
        if (input.value.trim()) reagentsList.push(input.value.trim()); 
    });

    return {
        protocol_id: document.getElementById('protocol-id')?.value || null, 
        title: document.getElementById('protocol-title')?.value,
        description: document.getElementById('protocol-description')?.value,
        author_person_id: document.getElementById('protocol-authors')?.value || App.currentUser.person_id || null, 
        project_id: protocolProjectSelect?.value || null, 
        category_id: document.getElementById('protocol-category')?.value || null, 
        tags: document.getElementById('protocol-tags')?.value,
        status_id: document.getElementById('protocol-status')?.value || 'draft', 
        reagents: reagentsList, 
        steps: steps 
    };
}


// --- VIEW/RUN FUNCTIONS (Used by view/run.html) ---

function generateProtocolViewHtml(protocol) { 
    const steps = Array.isArray(protocol.steps) ? protocol.steps.sort((a,b) => (a.step_number || 0) - (b.step_number || 0)) : [];
    
    const stepsHtml = steps.map((step, index) => {
        const stepHtml = mdConverter.makeHtml(step.description || '');
        const componentsViewHtml = (step.components || []).map(comp => {
             let details = '';
             let icon = 'bi-box';
             switch(comp.type) {
                  case 'Centrifuge': icon='bi-arrow-repeat'; details = `Speed: ${formatComponentValue(comp.speed)}, Time: ${formatComponentValue(comp.time)}, Temp: ${formatComponentValue(comp.temp)}`; break;
                  case 'Shake': icon='bi-phone-vibrate'; details = `Speed: ${formatComponentValue(comp.speed)}, Time: ${formatComponentValue(comp.time)}`; break;
                  case 'Incubate': icon='bi-thermometer-half'; details = `Temp: ${formatComponentValue(comp.temp)}, Time: ${formatComponentValue(comp.time)}`; break;
                  case 'Cool': icon='bi-snow'; details = `Temp: ${formatComponentValue(comp.temp)}, Time: ${formatComponentValue(comp.time)}`; break;
                  case 'Reagent': icon='bi-beaker'; details = `Name: ${formatComponentValue(comp.name)}, Qty: ${formatComponentValue(comp.quantity)}, Conc: ${formatComponentValue(comp.concentration)}`; break;
                  case 'Equipment': icon='bi-wrench'; details = `Name: ${formatComponentValue(comp.name)}`; break;
                  default: details = 'Custom Component'; 
             }
             return `<p class="small text-dark"><i class="${icon} me-1"></i><strong>${comp.type}:</strong> ${details}</p>`;
        }).join('');
        const durationText = step.estimated_time_minutes ? `${step.estimated_time_minutes} min` : (step.timer || step.duration || '<i class="text-muted">N/A</i>');

         return `
             <div class="accordion-item">
                 <h2 class="accordion-header" id="heading-view-${step.step_id || index}">
                     <button class="accordion-button ${index === 0 ? '' : 'collapsed'}" type="button" data-bs-toggle="collapse" data-bs-target="#collapse-view-${step.step_id || index}" aria-expanded="${index === 0}">
                         <strong>Step ${step.step_number || index + 1}:</strong> ${step.title || 'Untitled Step'}
                     </button>
                 </h2>
                 <div id="collapse-view-${step.step_id || index}" class="accordion-collapse collapse ${index === 0 ? 'show' : ''}" data-bs-parent="#protocol-steps-accordion">
                     <div class="accordion-body">
                         ${componentsViewHtml ? `<div class="mb-3">${componentsViewHtml}</div><hr class="my-3">` : ''}
                         <div class="mb-3 markdown-content">${stepHtml || '<p class="text-muted">No description provided.</p>'}</div>
                         <div class="row small text-muted border-top pt-2">
                             <div class="col-md-4"><strong>Reagents:</strong><p class="mb-0">${step.reagents || 'N/A'}</p></div>
                             <div class="col-md-4"><strong>Est. Duration:</strong><p class="mb-0">${durationText}</p></div>
                         </div>
                     </div>
                 </div>
             </div>`;
    }).join('');
    
     const reagents = Array.isArray(protocol.reagents) ? protocol.reagents : [];
     const reagentsHtml = reagents.map(r => `<li class="list-group-item small">${r}</li>`).join('');
    
     return `
         <div>
             <div id="protocol-steps-accordion-content">${stepsHtml}</div>
             <div id="view-reagent-list-content">${reagentsHtml}</div>
         </div>
     `;
}

function parseTimerString(timerString) {
    if (!timerString) return 0;
    const match = timerString.match(/(\d+)\s*(min|h|hr|sec|s)/i);
    if (!match) return 0;
    const value = parseInt(match[1], 10);
    const unit = match[2]?.toLowerCase();
    
    if (unit === 'min') return value * 60;
    if (unit === 'h' || unit === 'hr') return value * 3600;
    if (unit === 'sec' || unit === 's') return value;
    return value * 60;
}

function formatTime(totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    
    const pad = (num) => String(num).padStart(2, '0');
    
    let timeString = `${pad(minutes)}:${pad(seconds)}`;
    if (hours > 0) {
        timeString = `${pad(hours)}:${timeString}`;
    }
    return timeString;
}

function populateSelect(selectElement, options, valueField, textField) { 
     if (!selectElement || !Array.isArray(options)) return;
     const firstOption = selectElement.options[0];
     selectElement.innerHTML = ''; 
     if (firstOption) selectElement.appendChild(firstOption);

     options.forEach(option => {
          const opt = document.createElement('option');
          opt.value = option[valueField];
          opt.textContent = option[textField] || option[valueField]; 
          selectElement.appendChild(opt);
     });
}


// Expose necessary functions globally for use in HTML files
window.App = {
    apiCall,
    showConfirmationModal,
    handleClipboardCopy,
    getStatusBadge,
    createProtocolCardHtml,
    serializeEditor,
    serializeStep,
    createComponentHtml,
    createStepCardHtml,
    generateProtocolViewHtml,
    parseTimerString,
    formatTime,
    populateSelect,
    currentUser,
    initBootstrapComponents,
    checkConnectionAndAuth,
    getRelativePath // Exposed path utility
};
