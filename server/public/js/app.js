// AssetFlow Native Web App JavaScript
// Unified REST API Client (/api/...) with Personnel & Settings Split

let token = localStorage.getItem('assetflow_token') || null;
let currentUser = JSON.parse(localStorage.getItem('assetflow_user') || 'null');
let currentTab = 'dashboard';
let currentSettingsSubTab = 'company';

// In-memory data store
let data = {
    workstations: [],
    peripherals: [],
    personnel: [],
    users: [],
    logs: [],
    settings: {},
    customFields: []
};

// API Helper
async function api(path, options = {}) {
    const headers = {
        'Accept': 'application/json',
        ...(options.headers || {})
    };
    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }
    if (options.body && !(options.body instanceof FormData)) {
        headers['Content-Type'] = 'application/json';
        options.body = JSON.stringify(options.body);
    }

    try {
        const response = await fetch(path, { credentials: 'same-origin', ...options, headers });
        if (response.status === 401) {
            handleLogout();
            throw new Error('Session expired. Please sign in again.');
        }
        if (response.status === 204) return null;
        const result = await response.json().catch(() => null);
        if (!response.ok) {
            const errorMsg = result?.error?.message || `Request failed with status ${response.status}`;
            throw new Error(errorMsg);
        }
        return result;
    } catch (err) {
        showToast(err.message, 'error');
        throw err;
    }
}

// Toast notification helper
function showToast(message, type = 'info') {
    const container = document.getElementById('toastContainer');
    if (!container) return;
    const toast = document.createElement('div');
    toast.className = `toast ${type === 'error' ? 'toast-error' : type === 'success' ? 'toast-success' : ''}`;
    const icon = type === 'error' ? 'ph-warning-circle' : type === 'success' ? 'ph-check-circle' : 'ph-info';
    toast.innerHTML = `<i class="ph ${icon}"></i> <span>${escapeHtml(message)}</span>`;
    container.appendChild(toast);
    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateX(100%)';
        setTimeout(() => toast.remove(), 300);
    }, 4000);
}

function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

// Modal Helpers
function openModal(id) {
    const modal = document.getElementById(id);
    if (modal) modal.classList.add('active');
}

function closeModal(id) {
    const modal = document.getElementById(id);
    if (modal) modal.classList.remove('active');
}

// Setup & Initialization
document.addEventListener('DOMContentLoaded', () => {
    initAuth();
    setupEventListeners();
});

function initAuth() {
    const loginScreen = document.getElementById('loginScreen');
    const appContainer = document.getElementById('appContainer');

    if (!token || !currentUser) {
        loginScreen.style.display = 'flex';
        appContainer.style.display = 'none';
    } else {
        loginScreen.style.display = 'none';
        appContainer.style.display = 'flex';
        updateHeaderUserInfo();
        applyRBAC();
        loadAllData().then(() => {
            applySettingsToUI();
            switchTab(currentTab);
        });
    }
}

function updateHeaderUserInfo() {
    if (!currentUser) return;
    document.getElementById('headerUserName').textContent = currentUser.fullName || currentUser.email;
    document.getElementById('headerUserRole').textContent = currentUser.role || 'VIEWER';
    document.getElementById('headerUserAvatar').textContent = (currentUser.fullName || currentUser.email || 'A')[0].toUpperCase();
}

function applyRBAC() {
    const role = (currentUser?.role || 'VIEWER').toUpperCase();
    const isAdmin = role === 'ADMIN';

    // Hide admin navigation items if not admin
    document.querySelectorAll('.admin-only').forEach(el => {
        el.style.display = isAdmin ? '' : 'none';
    });
}

function applySettingsToUI() {
    if (data.settings.companyName) {
        document.getElementById('companyHeaderTitle').textContent = data.settings.companyName;
    }
}

function handleLogout() {
    token = null;
    currentUser = null;
    localStorage.removeItem('assetflow_token');
    localStorage.removeItem('assetflow_user');
    initAuth();
}

function setupEventListeners() {
    // Login form
    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
        loginForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const email = document.getElementById('loginEmail').value.trim();
            const password = document.getElementById('loginPassword').value.trim();
            const errorBox = document.getElementById('loginError');
            const errorText = document.getElementById('loginErrorText');
            errorBox.style.display = 'none';

            try {
                const res = await api('/api/auth/login', {
                    method: 'POST',
                    body: { email, password }
                });
                token = res.token;
                currentUser = res.user;
                localStorage.setItem('assetflow_token', token);
                localStorage.setItem('assetflow_user', JSON.stringify(currentUser));
                initAuth();
                showToast(`Welcome, ${currentUser.fullName || currentUser.email}!`, 'success');
            } catch (err) {
                errorText.textContent = err.message || 'Invalid credentials';
                errorBox.style.display = 'flex';
            }
        });
    }

    // Logout button
    document.getElementById('btnLogout')?.addEventListener('click', handleLogout);

    // Sidebar navigation tabs
    document.querySelectorAll('.sidebar-nav .nav-item').forEach(item => {
        item.addEventListener('click', () => {
            const tab = item.getAttribute('data-tab');
            if (tab) switchTab(tab);
        });
    });

    // Global Header Search
    const searchInput = document.getElementById('globalSearchInput');
    if (searchInput) {
        searchInput.addEventListener('keydown', async (e) => {
            if (e.key === 'Enter') {
                const tag = searchInput.value.trim();
                if (tag) lookupAsset(tag);
            }
        });
    }

    // Forms
    document.getElementById('personnelForm')?.addEventListener('submit', handlePersonnelFormSubmit);
    document.getElementById('workstationForm')?.addEventListener('submit', handleWorkstationFormSubmit);
    document.getElementById('peripheralForm')?.addEventListener('submit', handlePeripheralFormSubmit);
    document.getElementById('userForm')?.addEventListener('submit', handleUserFormSubmit);
    document.getElementById('customFieldForm')?.addEventListener('submit', handleCustomFieldFormSubmit);

    // Dynamic field creator input type toggle
    document.getElementById('cfFieldType')?.addEventListener('change', (e) => {
        const isSelect = e.target.value === 'select';
        document.getElementById('cfOptionsGroup').style.display = isSelect ? 'block' : 'none';
    });
}

// Tab Switching
function switchTab(tab) {
    if (tab === 'settings' && currentUser?.role !== 'ADMIN') {
        showToast('Settings are restricted to Administrators.', 'error');
        return;
    }

    currentTab = tab;
    document.querySelectorAll('.sidebar-nav .nav-item').forEach(item => {
        item.classList.toggle('active', item.getAttribute('data-tab') === tab);
    });

    const container = document.getElementById('viewContainer');
    if (!container) return;

    if (tab === 'dashboard') renderDashboard(container);
    else if (tab === 'workstations') renderWorkstations(container);
    else if (tab === 'peripherals') renderPeripherals(container);
    else if (tab === 'personnel') renderPersonnel(container);
    else if (tab === 'logs') renderLogs(container);
    else if (tab === 'excel') renderExcelTools(container);
    else if (tab === 'settings') renderSettings(container);
}

// Data Fetching
async function loadAllData() {
    try {
        const promises = [
            api('/api/workstations'),
            api('/api/peripherals'),
            api('/api/personnel'),
            api('/api/logs'),
            api('/api/settings'),
            api('/api/settings/custom-fields')
        ];
        if (currentUser?.role === 'ADMIN') {
            promises.push(api('/api/users'));
        }

        const results = await Promise.all(promises);
        data.workstations = results[0] || [];
        data.peripherals = results[1] || [];
        data.personnel = results[2] || [];
        data.logs = results[3] || [];
        data.settings = results[4] || {};
        data.customFields = results[5] || [];
        if (currentUser?.role === 'ADMIN') {
            data.users = results[6] || [];
        }
    } catch (err) {
        console.error('Failed to load data:', err);
    }
}

// =====================================================================
// 1. DASHBOARD VIEW
// =====================================================================
function renderDashboard(container) {
    const totalWs = data.workstations.length;
    const totalPer = data.peripherals.length;
    const totalPersonnel = data.personnel.length;
    const totalAssets = totalWs + totalPer;

    const inStore = [...data.workstations, ...data.peripherals].filter(a => a.status === 'IN_STORE').length;
    const assigned = [...data.workstations, ...data.peripherals].filter(a => a.status === 'ASSIGNED').length;
    const retired = [...data.workstations, ...data.peripherals].filter(a => a.status === 'RETIRED' || a.status === 'OUT_OF_ORDER').length;

    container.innerHTML = `
        <div class="page-header">
            <div class="page-title">
                <h1>Dashboard Overview</h1>
                <p>Real-time IT infrastructure and asset metrics</p>
            </div>
            <div class="header-controls">
                <button class="btn btn-secondary" onclick="refreshData()"><i class="ph ph-arrows-clockwise"></i> Refresh</button>
                <button class="btn btn-primary" onclick="exportExcel()"><i class="ph ph-file-arrow-down"></i> Export Excel</button>
            </div>
        </div>

        <div class="metrics-grid">
            <div class="glass-panel metric-card">
                <div class="metric-header">
                    <span class="metric-title">Total Assets</span>
                    <div class="metric-icon-wrap" style="background: rgba(99, 102, 241, 0.15); color: #818cf8;"><i class="ph ph-stack"></i></div>
                </div>
                <div class="metric-value">${totalAssets}</div>
                <p style="font-size: 12px; color: var(--text-muted);">${totalWs} Workstations • ${totalPer} Peripherals</p>
            </div>
            <div class="glass-panel metric-card">
                <div class="metric-header">
                    <span class="metric-title">Total Personnel</span>
                    <div class="metric-icon-wrap" style="background: rgba(14, 165, 233, 0.15); color: #38bdf8;"><i class="ph ph-users-three"></i></div>
                </div>
                <div class="metric-value">${totalPersonnel}</div>
                <p style="font-size: 12px; color: var(--text-muted);">Registered staff & asset holders</p>
            </div>
            <div class="glass-panel metric-card">
                <div class="metric-header">
                    <span class="metric-title">Assigned / In Use</span>
                    <div class="metric-icon-wrap" style="background: var(--status-assigned-bg); color: var(--status-assigned-text);"><i class="ph ph-user-check"></i></div>
                </div>
                <div class="metric-value">${assigned}</div>
                <p style="font-size: 12px; color: var(--text-muted);">${inStore} remaining in store</p>
            </div>
            <div class="glass-panel metric-card">
                <div class="metric-header">
                    <span class="metric-title">Retired / Out of Order</span>
                    <div class="metric-icon-wrap" style="background: var(--status-retired-bg); color: var(--status-retired-text);"><i class="ph ph-archive"></i></div>
                </div>
                <div class="metric-value">${retired}</div>
                <p style="font-size: 12px; color: var(--text-muted);">Decommissioned or in maintenance</p>
            </div>
        </div>

        <div class="dashboard-sections">
            <div class="glass-panel table-card">
                <div class="table-toolbar">
                    <h3 style="font-size: 16px;">Quick Actions</h3>
                </div>
                <div style="padding: 24px; display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px;">
                    <button class="btn btn-secondary" style="justify-content: flex-start; padding: 16px;" onclick="openWorkstationModal()">
                        <i class="ph ph-desktop" style="font-size: 24px; color: var(--accent);"></i>
                        <div style="text-align: left;">
                            <div style="font-weight: 600;">Add Workstation</div>
                            <div style="font-size: 11px; color: var(--text-muted);">Register computer or laptop</div>
                        </div>
                    </button>
                    <button class="btn btn-secondary" style="justify-content: flex-start; padding: 16px;" onclick="openPeripheralModal()">
                        <i class="ph ph-mouse" style="font-size: 24px; color: #10b981;"></i>
                        <div style="text-align: left;">
                            <div style="font-weight: 600;">Add Peripheral</div>
                            <div style="font-size: 11px; color: var(--text-muted);">Register monitor, mouse, VR, etc.</div>
                        </div>
                    </button>
                    <button class="btn btn-secondary" style="justify-content: flex-start; padding: 16px;" onclick="openPersonnelModal()">
                        <i class="ph ph-user-plus" style="font-size: 24px; color: #38bdf8;"></i>
                        <div style="text-align: left;">
                            <div style="font-weight: 600;">Add Personnel</div>
                            <div style="font-size: 11px; color: var(--text-muted);">Register employee/staff profile</div>
                        </div>
                    </button>
                    <button class="btn btn-secondary" style="justify-content: flex-start; padding: 16px;" onclick="switchTab('excel')">
                        <i class="ph ph-file-xls" style="font-size: 24px; color: #f59e0b;"></i>
                        <div style="text-align: left;">
                            <div style="font-weight: 600;">Excel Tools</div>
                            <div style="font-size: 11px; color: var(--text-muted);">Import or Export 4-sheet database</div>
                        </div>
                    </button>
                </div>
            </div>

            <div class="glass-panel table-card">
                <div class="table-toolbar">
                    <h3 style="font-size: 16px;">Recent Audit Activity</h3>
                    <button class="btn btn-sm btn-secondary" onclick="switchTab('logs')">View All</button>
                </div>
                <div style="padding: 12px 16px; max-height: 280px; overflow-y: auto;">
                    ${data.logs.slice(0, 5).map(l => `
                        <div style="padding: 10px 0; border-bottom: 1px solid var(--border-subtle); font-size: 13px;">
                            <div style="display: flex; justify-content: space-between; margin-bottom: 2px;">
                                <span style="font-weight: 600; color: var(--text-primary);">${escapeHtml(l.actionTaken)}</span>
                                <span style="font-size: 11px; color: var(--text-muted);">${formatDate(l.timestamp)}</span>
                            </div>
                            <div style="font-size: 12px; color: var(--text-muted);">
                                ${l.assetTag ? `<span class="tag-badge" style="color: var(--accent);">${escapeHtml(l.assetTag)}</span> • ` : ''}
                                By: ${escapeHtml(l.userEmail || 'System')}
                            </div>
                        </div>
                    `).join('') || '<p style="color: var(--text-muted); font-size: 13px; text-align: center; padding: 20px;">No activity logs yet</p>'}
                </div>
            </div>
        </div>
    `;
}

// =====================================================================
// 2. WORKSTATIONS VIEW
// =====================================================================
function renderWorkstations(container) {
    const isViewer = currentUser?.role === 'VIEWER';
    container.innerHTML = `
        <div class="page-header">
            <div class="page-title">
                <h1>Workstations</h1>
                <p>Manage all desktop PCs, laptops, and host machines</p>
            </div>
            <div class="header-controls">
                ${!isViewer ? `<button class="btn btn-primary" onclick="openWorkstationModal()"><i class="ph ph-plus"></i> New Workstation</button>` : ''}
            </div>
        </div>

        <div class="glass-panel table-card">
            <div class="table-toolbar">
                <div class="table-search">
                    <i class="ph ph-magnifying-glass"></i>
                    <input type="text" id="wsSearchInput" placeholder="Filter workstations..." oninput="filterWorkstations()">
                </div>
                <div class="table-filters">
                    <select id="wsStatusFilter" class="select-filter" onchange="filterWorkstations()">
                        <option value="">All Statuses</option>
                        <option value="IN_STORE">In Store</option>
                        <option value="ASSIGNED">Assigned</option>
                        <option value="OUT_OF_ORDER">Out of Order</option>
                        <option value="RETIRED">Retired</option>
                    </select>
                </div>
            </div>

            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Tag</th>
                            <th>Assigned Personnel</th>
                            <th>Device Type</th>
                            <th>CPU & Specs</th>
                            <th>RAM / Storage / GPU</th>
                            <th>Status</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody id="wsTableBody">
                        ${generateWorkstationsRows(data.workstations)}
                    </tbody>
                </table>
            </div>
        </div>
    `;
}

function generateWorkstationsRows(workstations) {
    const isViewer = currentUser?.role === 'VIEWER';
    if (!workstations.length) {
        return `<tr><td colspan="7" style="text-align:center; padding: 32px; color: var(--text-muted);">No workstations found</td></tr>`;
    }
    return workstations.map(ws => {
        const assignedName = ws.personnel?.fullName || ws.userName;
        return `
        <tr>
            <td><span class="tag-badge" style="color: #818cf8;">${escapeHtml(ws.workstationTag)}</span></td>
            <td>
                ${assignedName 
                    ? `<a href="javascript:void(0)" onclick="openPersonnelOwnershipModal('${ws.personnelId || ''}')" style="color: #38bdf8; font-weight: 500; text-decoration: none;"><i class="ph ph-user" style="margin-right: 4px;"></i> ${escapeHtml(assignedName)}</a>` 
                    : '<span style="color: var(--text-muted);">Unassigned</span>'}
            </td>
            <td>${escapeHtml(ws.deviceType || 'PC / Workstation')}</td>
            <td>
                <div style="font-weight: 500;">${escapeHtml(ws.processorGen || 'N/A')}</div>
                <div style="font-size: 11px; color: var(--text-muted);">${escapeHtml(ws.motherboard || '')}</div>
            </td>
            <td>
                <div style="font-size: 12px;">${[ws.ram, ws.ssd || ws.hdd, ws.gpu].filter(Boolean).map(escapeHtml).join(' • ') || 'N/A'}</div>
            </td>
            <td>${statusBadge(ws.status)}</td>
            <td>
                <div style="display: flex; gap: 6px;">
                    <button class="icon-btn" title="View Details" onclick="lookupAsset('${escapeHtml(ws.workstationTag)}')"><i class="ph ph-eye"></i></button>
                    ${!isViewer ? `<button class="icon-btn" title="Edit Workstation" onclick="editWorkstation('${escapeHtml(ws.workstationTag)}')"><i class="ph ph-pencil-simple"></i></button>` : ''}
                    <button class="icon-btn" title="Print Tag" onclick="printTag('${escapeHtml(ws.workstationTag)}', 'workstation')"><i class="ph ph-printer"></i></button>
                    ${!isViewer ? (ws.status === 'RETIRED' 
                        ? `<button class="btn btn-sm btn-success" onclick="restoreAsset('workstation', '${escapeHtml(ws.workstationTag)}')">Restore</button>`
                        : `<button class="btn btn-sm btn-danger" onclick="retireAsset('workstation', '${escapeHtml(ws.workstationTag)}')">Retire</button>`
                    ) : ''}
                </div>
            </td>
        </tr>
    `}).join('');
}

function filterWorkstations() {
    const q = document.getElementById('wsSearchInput')?.value.toLowerCase() || '';
    const status = document.getElementById('wsStatusFilter')?.value || '';

    const filtered = data.workstations.filter(ws => {
        const assignedName = (ws.personnel?.fullName || ws.userName || '').toLowerCase();
        const matchesQuery = !q || 
            ws.workstationTag.toLowerCase().includes(q) ||
            assignedName.includes(q) ||
            (ws.processorGen && ws.processorGen.toLowerCase().includes(q)) ||
            (ws.deviceType && ws.deviceType.toLowerCase().includes(q));
        const matchesStatus = !status || ws.status === status;
        return matchesQuery && matchesStatus;
    });

    const tbody = document.getElementById('wsTableBody');
    if (tbody) tbody.innerHTML = generateWorkstationsRows(filtered);
}

// =====================================================================
// 3. PERIPHERALS VIEW (Dedicated Standalone Tab)
// =====================================================================
function renderPeripherals(container) {
    const isViewer = currentUser?.role === 'VIEWER';
    const categories = [...new Set(data.peripherals.map(p => p.category).filter(Boolean))];

    container.innerHTML = `
        <div class="page-header">
            <div class="page-title">
                <h1>Peripherals</h1>
                <p>Manage displays, keyboards, VR gear, mice, and other accessories</p>
            </div>
            <div class="header-controls">
                ${!isViewer ? `<button class="btn btn-primary" onclick="openPeripheralModal()"><i class="ph ph-plus"></i> New Peripheral</button>` : ''}
            </div>
        </div>

        <div class="glass-panel table-card">
            <div class="table-toolbar">
                <div class="table-search">
                    <i class="ph ph-magnifying-glass"></i>
                    <input type="text" id="perSearchInput" placeholder="Filter peripherals..." oninput="filterPeripherals()">
                </div>
                <div class="table-filters">
                    <select id="perCategoryFilter" class="select-filter" onchange="filterPeripherals()">
                        <option value="">All Categories</option>
                        ${categories.map(c => `<option value="${escapeHtml(c)}">${escapeHtml(c)}</option>`).join('')}
                    </select>
                    <select id="perStatusFilter" class="select-filter" onchange="filterPeripherals()">
                        <option value="">All Statuses</option>
                        <option value="IN_STORE">In Store</option>
                        <option value="ASSIGNED">Assigned</option>
                        <option value="OUT_OF_ORDER">Out of Order</option>
                        <option value="RETIRED">Retired</option>
                    </select>
                </div>
            </div>

            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Peripheral Tag</th>
                            <th>Category</th>
                            <th>Brand & Model Specs</th>
                            <th>Linked Host Machine</th>
                            <th>Assigned Person</th>
                            <th>Qty</th>
                            <th>Status</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody id="perTableBody">
                        ${generatePeripheralsRows(data.peripherals)}
                    </tbody>
                </table>
            </div>
        </div>
    `;
}

function generatePeripheralsRows(peripherals) {
    const isViewer = currentUser?.role === 'VIEWER';
    if (!peripherals.length) {
        return `<tr><td colspan="8" style="text-align:center; padding: 32px; color: var(--text-muted);">No peripherals found</td></tr>`;
    }
    return peripherals.map(p => {
        const hostWs = p.workstation;
        const assignedPerson = hostWs?.personnel?.fullName || hostWs?.userName;
        return `
        <tr>
            <td><span class="tag-badge" style="color: #34d399;">${escapeHtml(p.peripheralTag)}</span></td>
            <td><span class="badge" style="background: rgba(99, 102, 241, 0.1); color: #a5b4fc;">${escapeHtml(p.category || 'Peripheral')}</span></td>
            <td>
                <div style="font-weight: 500;">${escapeHtml(p.modelSpecs || 'N/A')}</div>
                <div style="font-size: 11px; color: var(--text-muted);">${escapeHtml(p.brandManufacturer || '')}</div>
            </td>
            <td>
                ${p.workstationTag 
                    ? `<a href="javascript:void(0)" onclick="lookupAsset('${escapeHtml(p.workstationTag)}')" style="color: var(--accent); text-decoration: none; font-weight: 600;"><i class="ph ph-desktop"></i> ${escapeHtml(p.workstationTag)}</a>`
                    : `<span style="color: var(--text-muted);">Standalone</span>`
                }
            </td>
            <td>
                ${assignedPerson 
                    ? `<span style="color: #38bdf8; font-size: 12.5px;"><i class="ph ph-user"></i> ${escapeHtml(assignedPerson)}</span>`
                    : `<span style="color: var(--text-muted);">—</span>`}
            </td>
            <td>${p.quantity ?? 1}</td>
            <td>${statusBadge(p.status)}</td>
            <td>
                <div style="display: flex; gap: 6px;">
                    <button class="icon-btn" title="View Details" onclick="lookupAsset('${escapeHtml(p.peripheralTag)}')"><i class="ph ph-eye"></i></button>
                    ${!isViewer ? `<button class="icon-btn" title="Edit Peripheral" onclick="editPeripheral('${escapeHtml(p.peripheralTag)}')"><i class="ph ph-pencil-simple"></i></button>` : ''}
                    <button class="icon-btn" title="Print Tag" onclick="printTag('${escapeHtml(p.peripheralTag)}', 'peripheral')"><i class="ph ph-printer"></i></button>
                    ${!isViewer ? (p.status === 'RETIRED' 
                        ? `<button class="btn btn-sm btn-success" onclick="restoreAsset('peripheral', '${escapeHtml(p.peripheralTag)}')">Restore</button>`
                        : `<button class="btn btn-sm btn-danger" onclick="retireAsset('peripheral', '${escapeHtml(p.peripheralTag)}')">Retire</button>`
                    ) : ''}
                </div>
            </td>
        </tr>
    `}).join('');
}

function filterPeripherals() {
    const q = document.getElementById('perSearchInput')?.value.toLowerCase() || '';
    const cat = document.getElementById('perCategoryFilter')?.value || '';
    const status = document.getElementById('perStatusFilter')?.value || '';

    const filtered = data.peripherals.filter(p => {
        const matchesQuery = !q ||
            p.peripheralTag.toLowerCase().includes(q) ||
            (p.category && p.category.toLowerCase().includes(q)) ||
            (p.brandManufacturer && p.brandManufacturer.toLowerCase().includes(q)) ||
            (p.modelSpecs && p.modelSpecs.toLowerCase().includes(q)) ||
            (p.workstationTag && p.workstationTag.toLowerCase().includes(q));
        const matchesCat = !cat || p.category === cat;
        const matchesStatus = !status || p.status === status;
        return matchesQuery && matchesCat && matchesStatus;
    });

    const tbody = document.getElementById('perTableBody');
    if (tbody) tbody.innerHTML = generatePeripheralsRows(filtered);
}

// =====================================================================
// 4. PERSONNEL TAB (Dedicated Top-Level Inventory Ownership View)
// =====================================================================
function renderPersonnel(container) {
    const isViewer = currentUser?.role === 'VIEWER';
    const departments = [...new Set(data.personnel.map(p => p.department).filter(Boolean))];

    container.innerHTML = `
        <div class="page-header">
            <div class="page-title">
                <h1>Personnel & Asset Ownership</h1>
                <p>Staff members who hold and operate assigned physical assets</p>
            </div>
            <div class="header-controls">
                ${!isViewer ? `<button class="btn btn-primary" onclick="openPersonnelModal()"><i class="ph ph-user-plus"></i> New Personnel</button>` : ''}
            </div>
        </div>

        <div class="glass-panel table-card">
            <div class="table-toolbar">
                <div class="table-search">
                    <i class="ph ph-magnifying-glass"></i>
                    <input type="text" id="personnelSearchInput" placeholder="Search personnel name or email..." oninput="filterPersonnel()">
                </div>
                <div class="table-filters">
                    <select id="personnelDeptFilter" class="select-filter" onchange="filterPersonnel()">
                        <option value="">All Departments</option>
                        ${departments.map(d => `<option value="${escapeHtml(d)}">${escapeHtml(d)}</option>`).join('')}
                    </select>
                </div>
            </div>

            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Personnel Name</th>
                            <th>Department</th>
                            <th>Contact Email</th>
                            <th>Workstations</th>
                            <th>Peripherals</th>
                            <th>Total Assets</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody id="personnelTableBody">
                        ${generatePersonnelRows(data.personnel)}
                    </tbody>
                </table>
            </div>
        </div>
    `;
}

function generatePersonnelRows(personnelList) {
    const isViewer = currentUser?.role === 'VIEWER';
    const isAdmin = currentUser?.role === 'ADMIN';

    if (!personnelList.length) {
        return `<tr><td colspan="7" style="text-align:center; padding: 32px; color: var(--text-muted);">No personnel profiles registered</td></tr>`;
    }

    return personnelList.map(p => `
        <tr>
            <td>
                <div style="display: flex; align-items: center; gap: 10px;">
                    <div class="user-avatar" style="background: rgba(14, 165, 233, 0.15); color: #38bdf8; width: 30px; height: 30px; font-size: 12px;">
                        ${(p.fullName || 'P')[0].toUpperCase()}
                    </div>
                    <div>
                        <div style="font-weight: 600; color: var(--text-primary);">${escapeHtml(p.fullName)}</div>
                        ${p.notes ? `<div style="font-size: 11px; color: var(--text-muted);">${escapeHtml(p.notes)}</div>` : ''}
                    </div>
                </div>
            </td>
            <td><span class="badge" style="background: rgba(255,255,255,0.05); color: #cbd5e1;">${escapeHtml(p.department || 'General')}</span></td>
            <td>${escapeHtml(p.contactEmail || '—')}</td>
            <td><strong style="color: #818cf8;">${p.workstationsCount ?? (p.workstations?.length || 0)}</strong></td>
            <td><strong style="color: #34d399;">${p.peripheralsCount ?? 0}</strong></td>
            <td>
                <span class="badge" style="background: rgba(99, 102, 241, 0.15); color: #a5b4fc; font-weight: 700;">
                    ${p.totalAssetsCount ?? (p.workstations?.length || 0)} Assets
                </span>
            </td>
            <td>
                <div style="display: flex; gap: 6px;">
                    <button class="btn btn-sm btn-secondary" onclick="openPersonnelOwnershipModal('${escapeHtml(p.id)}')">
                        <i class="ph ph-stack"></i> View Inventory
                    </button>
                    ${!isViewer ? `<button class="icon-btn" title="Edit Profile" onclick="editPersonnel('${escapeHtml(p.id)}')"><i class="ph ph-pencil-simple"></i></button>` : ''}
                    ${isAdmin ? `<button class="icon-btn" title="Delete Personnel" style="color: #f87171;" onclick="deletePersonnel('${escapeHtml(p.id)}')"><i class="ph ph-trash"></i></button>` : ''}
                </div>
            </td>
        </tr>
    `).join('');
}

function filterPersonnel() {
    const q = document.getElementById('personnelSearchInput')?.value.toLowerCase() || '';
    const dept = document.getElementById('personnelDeptFilter')?.value || '';

    const filtered = data.personnel.filter(p => {
        const matchesQuery = !q ||
            p.fullName.toLowerCase().includes(q) ||
            (p.contactEmail && p.contactEmail.toLowerCase().includes(q)) ||
            (p.notes && p.notes.toLowerCase().includes(q));
        const matchesDept = !dept || p.department === dept;
        return matchesQuery && matchesDept;
    });

    const tbody = document.getElementById('personnelTableBody');
    if (tbody) tbody.innerHTML = generatePersonnelRows(filtered);
}

// Personnel Ownership Detail Modal
async function openPersonnelOwnershipModal(id) {
    if (!id) return;
    try {
        const person = await api(`/api/personnel/${encodeURIComponent(id)}`);
        document.getElementById('personnelDetailTitle').textContent = `Assets Assigned to ${person.fullName}`;

        const wsList = person.workstations || [];
        let allPeripherals = [];
        wsList.forEach(ws => {
            (ws.peripherals || []).forEach(p => {
                allPeripherals.push({ ...p, hostWorkstation: ws.workstationTag });
            });
        });

        let bodyHtml = `
            <div style="background: rgba(255,255,255,0.03); padding: 18px; border-radius: 12px; margin-bottom: 20px; border: 1px solid var(--border-subtle); display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 12px; font-size: 13.5px;">
                <div><strong>Department:</strong> ${escapeHtml(person.department || 'General')}</div>
                <div><strong>Contact Email:</strong> ${escapeHtml(person.contactEmail || 'Not specified')}</div>
                <div><strong>Total Assigned Assets:</strong> <span style="color: var(--accent); font-weight: bold;">${wsList.length + allPeripherals.length}</span></div>
            </div>

            <h3 style="font-size: 15px; margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
                <i class="ph ph-desktop" style="color: #818cf8;"></i> Workstations (${wsList.length})
            </h3>
        `;

        if (!wsList.length) {
            bodyHtml += `<p style="color: var(--text-muted); font-size: 13px; margin-bottom: 20px;">No workstations assigned to this person.</p>`;
        } else {
            bodyHtml += `
                <div style="display: flex; flex-direction: column; gap: 10px; margin-bottom: 24px;">
                    ${wsList.map(ws => `
                        <div class="ownership-card">
                            <div class="ownership-header">
                                <span class="tag-badge" style="color: #818cf8; font-size: 15px;">${escapeHtml(ws.workstationTag)}</span>
                                ${statusBadge(ws.status)}
                            </div>
                            <div style="font-size: 13px; color: var(--text-secondary);">
                                <strong>Device:</strong> ${escapeHtml(ws.deviceType || 'PC')} • 
                                <strong>CPU:</strong> ${escapeHtml(ws.processorGen || 'N/A')} • 
                                <strong>RAM:</strong> ${escapeHtml(ws.ram || 'N/A')} • 
                                <strong>Storage:</strong> ${escapeHtml(ws.ssd || ws.hdd || 'N/A')}
                            </div>
                            ${ws.peripherals && ws.peripherals.length ? `
                                <div style="margin-top: 6px; font-size: 12px; color: var(--text-muted);">
                                    <strong>Attached accessories:</strong> ${ws.peripherals.map(p => `${escapeHtml(p.peripheralTag)} (${escapeHtml(p.category || 'Peripheral')})`).join(', ')}
                                </div>
                            ` : ''}
                        </div>
                    `).join('')}
                </div>
            `;
        }

        bodyHtml += `
            <h3 style="font-size: 15px; margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
                <i class="ph ph-mouse" style="color: #34d399;"></i> Attached Peripherals (${allPeripherals.length})
            </h3>
        `;

        if (!allPeripherals.length) {
            bodyHtml += `<p style="color: var(--text-muted); font-size: 13px;">No peripherals currently linked.</p>`;
        } else {
            bodyHtml += `
                <div style="display: flex; flex-direction: column; gap: 8px;">
                    ${allPeripherals.map(p => `
                        <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; background: rgba(255,255,255,0.02); border-radius: 8px; border: 1px solid var(--border-subtle); font-size: 13px;">
                            <div>
                                <strong style="color: #34d399;">${escapeHtml(p.peripheralTag)}</strong> • 
                                ${escapeHtml(p.category || 'Peripheral')} (${escapeHtml(p.modelSpecs || p.brandManufacturer || '')})
                                <span style="font-size: 11px; color: var(--text-muted); margin-left: 6px;">[via ${escapeHtml(p.hostWorkstation)}]</span>
                            </div>
                            ${statusBadge(p.status)}
                        </div>
                    `).join('')}
                </div>
            `;
        }

        document.getElementById('personnelDetailBody').innerHTML = bodyHtml;
        openModal('personnelDetailModal');
    } catch (err) {}
}

// Personnel Modal Handlers
let editingPersonnelId = null;

function openPersonnelModal(id = null) {
    editingPersonnelId = id;
    const modalTitle = document.getElementById('personnelModalTitle');
    const form = document.getElementById('personnelForm');
    form.reset();

    if (id) {
        modalTitle.textContent = 'Edit Personnel Profile';
        const p = data.personnel.find(item => item.id === id);
        if (p) {
            document.getElementById('personnelFullName').value = p.fullName || '';
            document.getElementById('personnelDepartment').value = p.department || '';
            document.getElementById('personnelEmail').value = p.contactEmail || '';
            document.getElementById('personnelNotes').value = p.notes || '';
        }
    } else {
        modalTitle.textContent = 'New Personnel Profile';
    }
    openModal('personnelModal');
}

function editPersonnel(id) {
    openPersonnelModal(id);
}

async function handlePersonnelFormSubmit(e) {
    e.preventDefault();
    const payload = {
        fullName: document.getElementById('personnelFullName').value.trim(),
        department: document.getElementById('personnelDepartment').value.trim() || null,
        contactEmail: document.getElementById('personnelEmail').value.trim() || null,
        notes: document.getElementById('personnelNotes').value.trim() || null,
    };

    try {
        if (editingPersonnelId) {
            await api(`/api/personnel/${encodeURIComponent(editingPersonnelId)}`, {
                method: 'PATCH',
                body: payload
            });
            showToast('Personnel updated successfully', 'success');
        } else {
            await api('/api/personnel', {
                method: 'POST',
                body: payload
            });
            showToast('Personnel registered successfully', 'success');
        }
        closeModal('personnelModal');
        await loadAllData();
        switchTab(currentTab);
    } catch (err) {}
}

async function deletePersonnel(id) {
    if (!confirm('Are you sure you want to delete this personnel profile? Assigned workstations will become unassigned.')) return;
    try {
        await api(`/api/personnel/${encodeURIComponent(id)}`, { method: 'DELETE' });
        showToast('Personnel profile deleted', 'success');
        await loadAllData();
        switchTab(currentTab);
    } catch (err) {}
}

// =====================================================================
// 5. SETTINGS TAB (Admin-Only Centralized Configuration)
// =====================================================================
function renderSettings(container) {
    container.innerHTML = `
        <div class="page-header">
            <div class="page-title">
                <h1>Settings & System Administration</h1>
                <p>Configure company details, custom fields, automated tags, app themes, and login accounts</p>
            </div>
        </div>

        <div class="settings-container">
            <div class="settings-subnav">
                <button class="subnav-btn ${currentSettingsSubTab === 'company' ? 'active' : ''}" onclick="switchSettingsSubTab('company')">
                    <i class="ph ph-buildings"></i> Company Details & Logo
                </button>
                <button class="subnav-btn ${currentSettingsSubTab === 'tags' ? 'active' : ''}" onclick="switchSettingsSubTab('tags')">
                    <i class="ph ph-barcode"></i> Custom Tag Generator
                </button>
                <button class="subnav-btn ${currentSettingsSubTab === 'custom-fields' ? 'active' : ''}" onclick="switchSettingsSubTab('custom-fields')">
                    <i class="ph ph-sliders"></i> Custom Field Creator
                </button>
                <button class="subnav-btn ${currentSettingsSubTab === 'users' ? 'active' : ''}" onclick="switchSettingsSubTab('users')">
                    <i class="ph ph-shield-check"></i> Users & Access
                </button>
                <button class="subnav-btn ${currentSettingsSubTab === 'themes' ? 'active' : ''}" onclick="switchSettingsSubTab('themes')">
                    <i class="ph ph-palette"></i> Themes & Personalization
                </button>
                <button class="subnav-btn ${currentSettingsSubTab === 'mobile' ? 'active' : ''}" onclick="switchSettingsSubTab('mobile')">
                    <i class="ph ph-device-mobile"></i> Mobile APK Distribution
                </button>
            </div>

            <div id="settingsPaneContainer">
                <!-- Sub-pane rendered dynamically -->
            </div>
        </div>
    `;

    renderSettingsSubPane();
}

function switchSettingsSubTab(subTab) {
    currentSettingsSubTab = subTab;
    document.querySelectorAll('.settings-subnav .subnav-btn').forEach(btn => {
        btn.classList.toggle('active', btn.getAttribute('onclick')?.includes(subTab));
    });
    renderSettingsSubPane();
}

function renderSettingsSubPane() {
    const pane = document.getElementById('settingsPaneContainer');
    if (!pane) return;

    if (currentSettingsSubTab === 'company') {
        pane.innerHTML = `
            <div class="settings-pane">
                <div>
                    <h3 style="font-size: 18px; margin-bottom: 6px;">Company Details & Branding</h3>
                    <p style="font-size: 13px; color: var(--text-secondary);">These details appear on printed asset tags, export headers, and the top application banner.</p>
                </div>
                <form id="companySettingsForm" onsubmit="saveCompanySettings(event)">
                    <div class="form-group" style="margin-bottom: 16px;">
                        <label>Company / Organization Name</label>
                        <input type="text" id="settingCompanyName" value="${escapeHtml(data.settings.companyName || 'AssetFlow Enterprise')}">
                    </div>
                    <div class="form-group" style="margin-bottom: 16px;">
                        <label>Headquarters / Physical Address</label>
                        <input type="text" id="settingCompanyAddress" value="${escapeHtml(data.settings.companyAddress || 'Headquarters, Innovation Way')}">
                    </div>
                    <button type="submit" class="btn btn-primary"><i class="ph ph-floppy-disk"></i> Save Branding Settings</button>
                </form>
            </div>
        `;
    } else if (currentSettingsSubTab === 'tags') {
        const prefixWs = data.settings.tagPrefixWs || 'WS';
        const prefixPer = data.settings.tagPrefixPer || 'PER';
        const seqLen = data.settings.tagSeqLength || '4';
        const seqStart = data.settings.tagSeqStart || '1001';
        const sep = data.settings.tagSeparator || '-';

        pane.innerHTML = `
            <div class="settings-pane">
                <div>
                    <h3 style="font-size: 18px; margin-bottom: 6px;">Automated Tag Generator Rules</h3>
                    <p style="font-size: 13px; color: var(--text-secondary);">Configure prefix patterns, separators, and sequence formatting for one-click asset tag generation.</p>
                </div>
                <form id="tagRulesForm" onsubmit="saveTagSettings(event)">
                    <div class="form-row" style="margin-bottom: 16px;">
                        <div class="form-group">
                            <label>Workstation Prefix</label>
                            <input type="text" id="settingTagPrefixWs" value="${escapeHtml(prefixWs)}" oninput="updateTagPreview()">
                        </div>
                        <div class="form-group">
                            <label>Peripheral Prefix</label>
                            <input type="text" id="settingTagPrefixPer" value="${escapeHtml(prefixPer)}" oninput="updateTagPreview()">
                        </div>
                    </div>
                    <div class="form-row" style="margin-bottom: 16px;">
                        <div class="form-group">
                            <label>Separator Symbol</label>
                            <input type="text" id="settingTagSeparator" value="${escapeHtml(sep)}" oninput="updateTagPreview()">
                        </div>
                        <div class="form-group">
                            <label>Sequence Starting Number</label>
                            <input type="number" id="settingTagSeqStart" value="${escapeHtml(seqStart)}" oninput="updateTagPreview()">
                        </div>
                    </div>
                    <div style="background: rgba(255,255,255,0.02); padding: 18px; border-radius: 10px; border: 1px solid var(--border-subtle); margin-bottom: 20px;">
                        <div style="font-size: 12px; color: var(--text-muted); margin-bottom: 6px;">LIVE PREVIEW GENERATION:</div>
                        <div style="font-size: 16px; font-family: monospace; font-weight: bold; color: var(--accent);" id="tagLivePreview">
                            ${prefixWs}${sep}${seqStart} &nbsp;•&nbsp; ${prefixPer}${sep}${seqStart}
                        </div>
                    </div>
                    <button type="submit" class="btn btn-primary"><i class="ph ph-floppy-disk"></i> Save Tag Rules</button>
                </form>
            </div>
        `;
    } else if (currentSettingsSubTab === 'custom-fields') {
        pane.innerHTML = `
            <div class="settings-pane">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <div>
                        <h3 style="font-size: 18px; margin-bottom: 6px;">Custom Field Creator</h3>
                        <p style="font-size: 13px; color: var(--text-secondary);">Add dynamic custom metadata fields to Workstations, Peripherals, or Personnel without database migrations.</p>
                    </div>
                    <button class="btn btn-primary" onclick="openModal('customFieldModal')"><i class="ph ph-plus"></i> Add Custom Field</button>
                </div>

                <div class="table-container">
                    <table>
                        <thead>
                            <tr>
                                <th>Field Label</th>
                                <th>System Key</th>
                                <th>Attached Entity</th>
                                <th>Field Type</th>
                                <th>Options / Required</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${data.customFields.map(cf => `
                                <tr>
                                    <td><strong style="color: var(--text-primary);">${escapeHtml(cf.label)}</strong></td>
                                    <td><span style="font-family: monospace; font-size: 12px; color: var(--accent);">${escapeHtml(cf.name)}</span></td>
                                    <td><span class="badge" style="background: rgba(99,102,241,0.15); color: #a5b4fc;">${escapeHtml(cf.entityType)}</span></td>
                                    <td><span class="badge" style="background: rgba(255,255,255,0.06); color: #cbd5e1;">${escapeHtml(cf.fieldType)}</span></td>
                                    <td>${cf.options ? `<span style="font-size: 12px;">${escapeHtml(cf.options)}</span>` : (cf.required ? '<strong style="color: #f87171;">Required</strong>' : 'Optional')}</td>
                                    <td>
                                        <button class="icon-btn" style="color: #f87171;" title="Delete Field" onclick="deleteCustomField('${escapeHtml(cf.id)}')"><i class="ph ph-trash"></i></button>
                                    </td>
                                </tr>
                            `).join('') || '<tr><td colspan="6" style="text-align: center; padding: 24px; color: var(--text-muted);">No custom fields defined yet</td></tr>'}
                        </tbody>
                    </table>
                </div>
            </div>
        `;
    } else if (currentSettingsSubTab === 'users') {
        pane.innerHTML = `
            <div class="settings-pane">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <div>
                        <h3 style="font-size: 18px; margin-bottom: 6px;">Users & Access Control</h3>
                        <p style="font-size: 13px; color: var(--text-secondary);">Manage accounts that can sign into this application, their roles (Admin / Editor / Viewer), and access statuses.</p>
                    </div>
                    <button class="btn btn-primary" onclick="openUserModal()"><i class="ph ph-user-plus"></i> New Login Account</button>
                </div>

                <div class="table-container">
                    <table>
                        <thead>
                            <tr>
                                <th>User Account</th>
                                <th>Login Email</th>
                                <th>Role</th>
                                <th>Status</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${data.users.map(u => `
                                <tr>
                                    <td>
                                        <div style="display: flex; align-items: center; gap: 10px;">
                                            <div class="user-avatar" style="width: 28px; height: 28px; font-size: 12px;">${(u.fullName || u.email)[0].toUpperCase()}</div>
                                            <span style="font-weight: 600; color: var(--text-primary);">${escapeHtml(u.fullName)}</span>
                                        </div>
                                    </td>
                                    <td>${escapeHtml(u.email)}</td>
                                    <td><span class="badge badge-${u.role.toLowerCase()}">${escapeHtml(u.role)}</span></td>
                                    <td><span class="badge ${u.status === 'ACTIVE' ? 'badge-instore' : 'badge-retired'}">${escapeHtml(u.status)}</span></td>
                                    <td>
                                        <div style="display: flex; gap: 6px;">
                                            <button class="icon-btn" title="Edit User" onclick="editUser('${escapeHtml(u.email)}')"><i class="ph ph-pencil-simple"></i></button>
                                            <button class="icon-btn" title="Delete User" style="color: #f87171;" onclick="deleteUser('${escapeHtml(u.email)}')"><i class="ph ph-trash"></i></button>
                                        </div>
                                    </td>
                                </tr>
                            `).join('') || '<tr><td colspan="5" style="text-align: center; padding: 24px;">No users registered</td></tr>'}
                        </tbody>
                    </table>
                </div>
            </div>
        `;
    } else if (currentSettingsSubTab === 'themes') {
        pane.innerHTML = `
            <div class="settings-pane">
                <div>
                    <h3 style="font-size: 18px; margin-bottom: 6px;">Themes & Personalization</h3>
                    <p style="font-size: 13px; color: var(--text-secondary);">Select the visual theme and brand accent palette for the web portal.</p>
                </div>
                <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; margin-top: 10px;">
                    <div style="padding: 20px; border-radius: 12px; background: #0b0f19; border: 2px solid var(--accent); cursor: pointer;" onclick="showToast('Default Dark Theme applied', 'success')">
                        <h4 style="color: #ffffff; margin-bottom: 6px;">Dark Nebula (Default)</h4>
                        <p style="font-size: 12px; color: #9ca3af;">High-contrast slate dark background with ambient neon glow.</p>
                    </div>
                    <div style="padding: 20px; border-radius: 12px; background: #0f172a; border: 1px solid var(--border-subtle); cursor: pointer;" onclick="showToast('Midnight Slate theme selected', 'info')">
                        <h4 style="color: #ffffff; margin-bottom: 6px;">Midnight Blue</h4>
                        <p style="font-size: 12px; color: #9ca3af;">Deep navy tones with cyan highlights.</p>
                    </div>
                    <div style="padding: 20px; border-radius: 12px; background: #18181b; border: 1px solid var(--border-subtle); cursor: pointer;" onclick="showToast('Onyx Black theme selected', 'info')">
                        <h4 style="color: #ffffff; margin-bottom: 6px;">Onyx Minimal</h4>
                        <p style="font-size: 12px; color: #9ca3af;">Pure neutral monochrome with emerald accents.</p>
                    </div>
                </div>
            </div>
        `;
    } else if (currentSettingsSubTab === 'mobile') {
        pane.innerHTML = `
            <div class="settings-pane">
                <div>
                    <h3 style="font-size: 18px; margin-bottom: 6px;">Mobile App (Android APK) Distribution</h3>
                    <p style="font-size: 13px; color: var(--text-secondary);">Direct download link for mobile technicians and field operators.</p>
                </div>
                <div style="background: rgba(255,255,255,0.02); padding: 20px; border-radius: 12px; border: 1px solid var(--border-subtle); display: flex; align-items: center; justify-content: space-between;">
                    <div>
                        <h4 style="font-size: 15px;"><i class="ph ph-android-logo" style="color: #10b981;"></i> Android Release APK</h4>
                        <p style="font-size: 12px; color: var(--text-muted); margin-top: 4px;">Served directly from <code>/download/app-release.apk</code></p>
                    </div>
                    <a href="/download/app-release.apk" class="btn btn-primary" target="_blank">
                        <i class="ph ph-download-simple"></i> Download APK
                    </a>
                </div>
            </div>
        `;
    }
}

function updateTagPreview() {
    const prefixWs = document.getElementById('settingTagPrefixWs')?.value || 'WS';
    const prefixPer = document.getElementById('settingTagPrefixPer')?.value || 'PER';
    const sep = document.getElementById('settingTagSeparator')?.value || '-';
    const seqStart = document.getElementById('settingTagSeqStart')?.value || '1001';

    const preview = document.getElementById('tagLivePreview');
    if (preview) {
        preview.textContent = `${prefixWs}${sep}${seqStart} • ${prefixPer}${sep}${seqStart}`;
    }
}

async function saveCompanySettings(e) {
    e.preventDefault();
    const companyName = document.getElementById('settingCompanyName').value.trim();
    const companyAddress = document.getElementById('settingCompanyAddress').value.trim();

    try {
        await api('/api/settings', {
            method: 'POST',
            body: { companyName, companyAddress }
        });
        showToast('Company branding settings saved!', 'success');
        await loadAllData();
        applySettingsToUI();
    } catch (err) {}
}

async function saveTagSettings(e) {
    e.preventDefault();
    const tagPrefixWs = document.getElementById('settingTagPrefixWs').value.trim();
    const tagPrefixPer = document.getElementById('settingTagPrefixPer').value.trim();
    const tagSeparator = document.getElementById('settingTagSeparator').value.trim();
    const tagSeqStart = document.getElementById('settingTagSeqStart').value.trim();

    try {
        await api('/api/settings', {
            method: 'POST',
            body: { tagPrefixWs, tagPrefixPer, tagSeparator, tagSeqStart }
        });
        showToast('Automated tag rules saved!', 'success');
        await loadAllData();
    } catch (err) {}
}

async function handleCustomFieldFormSubmit(e) {
    e.preventDefault();
    const label = document.getElementById('cfLabel').value.trim();
    const entityType = document.getElementById('cfEntityType').value;
    const fieldType = document.getElementById('cfFieldType').value;
    const options = document.getElementById('cfOptions').value.trim();
    const required = document.getElementById('cfRequired').checked;
    const name = label.toLowerCase().replace(/[^a-z0-9]/g, '_');

    try {
        await api('/api/settings/custom-fields', {
            method: 'POST',
            body: { name, label, entityType, fieldType, options, required }
        });
        showToast('Custom field definition created', 'success');
        closeModal('customFieldModal');
        await loadAllData();
        renderSettingsSubPane();
    } catch (err) {}
}

async function deleteCustomField(id) {
    if (!confirm('Are you sure you want to remove this custom field definition?')) return;
    try {
        await api(`/api/settings/custom-fields/${encodeURIComponent(id)}`, { method: 'DELETE' });
        showToast('Custom field removed', 'success');
        await loadAllData();
        renderSettingsSubPane();
    } catch (err) {}
}

// User CRUD in Settings
let editingUserEmail = null;

function openUserModal(email = null) {
    editingUserEmail = email;
    const modalTitle = document.getElementById('userModalTitle');
    const form = document.getElementById('userForm');
    form.reset();

    if (email) {
        modalTitle.textContent = `Edit Account: ${email}`;
        const u = data.users.find(item => item.email === email);
        if (u) {
            document.getElementById('userEmail').value = u.email;
            document.getElementById('userEmail').disabled = true;
            document.getElementById('userFullName').value = u.fullName || '';
            document.getElementById('userRole').value = u.role || 'VIEWER';
            document.getElementById('userStatus').value = u.status || 'ACTIVE';
        }
    } else {
        modalTitle.textContent = 'New Login Account';
        document.getElementById('userEmail').disabled = false;
    }
    openModal('userModal');
}

function editUser(email) {
    openUserModal(email);
}

async function deleteUser(email) {
    if (!confirm(`Are you sure you want to delete user account "${email}"?`)) return;
    try {
        await api(`/api/users/${encodeURIComponent(email)}`, { method: 'DELETE' });
        showToast('User account deleted', 'success');
        await loadAllData();
        renderSettingsSubPane();
    } catch (err) {}
}

async function handleUserFormSubmit(e) {
    e.preventDefault();
    const email = document.getElementById('userEmail').value.trim();
    const fullName = document.getElementById('userFullName').value.trim();
    const role = document.getElementById('userRole').value;
    const status = document.getElementById('userStatus').value;
    const password = document.getElementById('userPassword').value;

    const payload = { email, fullName, role, status };
    if (password) payload.password = password;

    try {
        if (editingUserEmail) {
            await api(`/api/users/${encodeURIComponent(editingUserEmail)}`, {
                method: 'PATCH',
                body: payload
            });
            showToast('User access updated successfully', 'success');
        } else {
            if (!password) {
                showToast('Password is required for new accounts', 'error');
                return;
            }
            await api('/api/users', {
                method: 'POST',
                body: payload
            });
            showToast('User account created', 'success');
        }
        closeModal('userModal');
        await loadAllData();
        renderSettingsSubPane();
    } catch (err) {}
}

// =====================================================================
// 6. AUDIT LOGS VIEW
// =====================================================================
function renderLogs(container) {
    container.innerHTML = `
        <div class="page-header">
            <div class="page-title">
                <h1>Audit Logs</h1>
                <p>Immutable system audit trail and asset lifecycle history</p>
            </div>
            <div class="header-controls">
                <button class="btn btn-secondary" onclick="refreshData()"><i class="ph ph-arrows-clockwise"></i> Refresh</button>
            </div>
        </div>

        <div class="glass-panel table-card">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Timestamp</th>
                            <th>Action Taken</th>
                            <th>Asset Tag</th>
                            <th>Operator Email</th>
                            <th>Log ID</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${data.logs.map(l => `
                            <tr>
                                <td style="white-space: nowrap; font-size: 12px;">${formatDate(l.timestamp)}</td>
                                <td style="font-weight: 500; color: var(--text-primary);">${escapeHtml(l.actionTaken)}</td>
                                <td>${l.assetTag ? `<span class="tag-badge" style="color: var(--accent); cursor: pointer;" onclick="lookupAsset('${escapeHtml(l.assetTag)}')">${escapeHtml(l.assetTag)}</span>` : '<span style="color: var(--text-muted);">—</span>'}</td>
                                <td>${escapeHtml(l.userEmail || 'System')}</td>
                                <td><span style="font-family: monospace; font-size: 11px; color: var(--text-muted);">${escapeHtml(l.logId.substring(0, 8))}...</span></td>
                            </tr>
                        `).join('') || '<tr><td colspan="5" style="text-align: center; padding: 32px;">No logs recorded</td></tr>'}
                    </tbody>
                </table>
            </div>
        </div>
    `;
}

// =====================================================================
// 7. EXCEL IMPORT / EXPORT (Fixed Button & Live Upload Handling)
// =====================================================================
function renderExcelTools(container) {
    container.innerHTML = `
        <div class="page-header">
            <div class="page-title">
                <h1>Excel Database Tools</h1>
                <p>Import and export full database sheets (Workstations, Peripherals, Users, Audit Logs)</p>
            </div>
        </div>

        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 24px;">
            <div class="glass-panel" style="padding: 32px; display: flex; flex-direction: column; gap: 20px;">
                <div>
                    <h3 style="display: flex; align-items: center; gap: 10px; font-size: 18px;">
                        <i class="ph ph-file-arrow-up" style="color: var(--accent);"></i> Import Excel Database
                    </h3>
                    <p style="font-size: 13px; color: var(--text-secondary); margin-top: 6px;">
                        Upload a multi-sheet .xlsx workbook containing <strong>Workstations</strong>, <strong>Peripherals</strong>, <strong>Users</strong>, and <strong>Audit Logs</strong>. Valid rows are upserted.
                    </p>
                </div>

                <div id="dropZone" style="border: 2px dashed var(--border-subtle); border-radius: 12px; padding: 40px 20px; text-align: center; background: rgba(255, 255, 255, 0.02); cursor: pointer; transition: all 0.2s ease;">
                    <i class="ph ph-cloud-arrow-up" style="font-size: 48px; color: var(--accent);"></i>
                    <h4 id="dropZoneFileName" style="margin-top: 12px; font-size: 15px;">Click to select or drag .xlsx file here</h4>
                    <p style="font-size: 12px; color: var(--text-muted); margin-top: 4px;">Supports standard .xlsx format (up to 25MB)</p>
                    <input type="file" id="excelFileInput" accept=".xlsx" style="display: none;">
                </div>

                <button class="btn btn-primary" id="btnUploadExcel" style="width: 100%;" onclick="uploadExcelFile()">
                    <i class="ph ph-upload-simple"></i> Run Import Now
                </button>

                <div id="importResult" style="display: none; padding: 16px; border-radius: 8px; background: rgba(255, 255, 255, 0.04); border: 1px solid var(--border-subtle); font-size: 13px;">
                </div>
            </div>

            <div class="glass-panel" style="padding: 32px; display: flex; flex-direction: column; gap: 20px; justify-content: space-between;">
                <div>
                    <h3 style="display: flex; align-items: center; gap: 10px; font-size: 18px;">
                        <i class="ph ph-file-arrow-down" style="color: #10b981;"></i> Export Complete Database
                    </h3>
                    <p style="font-size: 13px; color: var(--text-secondary); margin-top: 6px;">
                        Download a clean, structured .xlsx spreadsheet with exact sheet headers and complete data for Workstations, Peripherals, Users, and Audit Logs.
                    </p>
                </div>

                <div style="background: rgba(255, 255, 255, 0.02); border: 1px solid var(--border-subtle); border-radius: 12px; padding: 20px; font-size: 13px; display: flex; flex-direction: column; gap: 8px;">
                    <div><i class="ph ph-check" style="color: #10b981; margin-right: 6px;"></i> <strong>Sheet 1:</strong> Workstations (13 columns)</div>
                    <div><i class="ph ph-check" style="color: #10b981; margin-right: 6px;"></i> <strong>Sheet 2:</strong> Peripherals (11 columns)</div>
                    <div><i class="ph ph-check" style="color: #10b981; margin-right: 6px;"></i> <strong>Sheet 3:</strong> Users (4 columns)</div>
                    <div><i class="ph ph-check" style="color: #10b981; margin-right: 6px;"></i> <strong>Sheet 4:</strong> Audit Logs (5 columns)</div>
                </div>

                <button class="btn btn-primary" style="background: #10b981; border-color: #059669; justify-content: center; width: 100%;" onclick="exportExcel()">
                    <i class="ph ph-download-simple"></i> Download IT Asset Database.xlsx
                </button>
            </div>
        </div>
    `;

    // Bind drag and drop / file selector
    const dropZone = document.getElementById('dropZone');
    const fileInput = document.getElementById('excelFileInput');

    if (dropZone && fileInput) {
        dropZone.onclick = () => fileInput.click();

        fileInput.onchange = () => {
            if (fileInput.files.length) {
                document.getElementById('dropZoneFileName').textContent = `Ready: ${fileInput.files[0].name}`;
                dropZone.classList.add('drop-zone-active');
            }
        };

        dropZone.ondragover = (e) => {
            e.preventDefault();
            dropZone.classList.add('drop-zone-active');
        };

        dropZone.ondragleave = () => {
            dropZone.classList.remove('drop-zone-active');
        };

        dropZone.ondrop = (e) => {
            e.preventDefault();
            dropZone.classList.remove('drop-zone-active');
            if (e.dataTransfer.files.length) {
                fileInput.files = e.dataTransfer.files;
                document.getElementById('dropZoneFileName').textContent = `Ready: ${e.dataTransfer.files[0].name}`;
            }
        };
    }
}

async function uploadExcelFile() {
    const fileInput = document.getElementById('excelFileInput');
    const resultBox = document.getElementById('importResult');
    if (!fileInput || !fileInput.files || !fileInput.files.length) {
        showToast('Please select an Excel (.xlsx) file first by clicking the upload area.', 'error');
        fileInput?.click();
        return;
    }

    const file = fileInput.files[0];
    const formData = new FormData();
    formData.append('file', file);

    resultBox.style.display = 'block';
    resultBox.innerHTML = `<div style="display: flex; align-items: center; gap: 8px;"><i class="ph ph-spinner ph-spin" style="font-size: 20px;"></i> Processing spreadsheet import...</div>`;

    try {
        const response = await fetch('/api/excel/import', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`
            },
            body: formData
        });

        const res = await response.json();
        if (!response.ok) {
            throw new Error(res?.error?.message || `Import failed with status ${response.status}`);
        }

        resultBox.innerHTML = `
            <div style="font-weight: 600; color: #34d399; margin-bottom: 6px;"><i class="ph ph-check-circle"></i> Import Completed Successfully!</div>
            <div>Inserted Rows: <strong>${res.inserted}</strong></div>
            <div>Updated Rows: <strong>${res.updated}</strong></div>
            <div>Skipped Rows: <strong>${res.skipped}</strong></div>
            ${res.errors && res.errors.length ? `
                <div style="margin-top: 10px; color: #f87171;">
                    <strong>Row Errors / Warnings (${res.errors.length}):</strong>
                    <ul style="margin-left: 20px; font-size: 12px; margin-top: 4px;">
                        ${res.errors.slice(0, 10).map(e => `<li>Sheet ${e.sheet}, Row ${e.row}: ${escapeHtml(e.reason)}</li>`).join('')}
                    </ul>
                </div>
            ` : ''}
        `;
        showToast('Excel database imported successfully', 'success');
        await loadAllData();
    } catch (err) {
        resultBox.innerHTML = `<div style="color: #f87171;"><i class="ph ph-warning"></i> ${escapeHtml(err.message)}</div>`;
    }
}

async function exportExcel() {
    showToast('Preparing Excel database export...', 'info');
    try {
        const response = await fetch('/api/excel/export', {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });
        if (!response.ok) {
            throw new Error(`Export failed (${response.status})`);
        }
        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'IT Asset Database.xlsx';
        document.body.appendChild(a);
        a.click();
        a.remove();
        window.URL.revokeObjectURL(url);
        showToast('Excel file downloaded successfully!', 'success');
    } catch (err) {
        showToast(err.message || 'Failed to export Excel file', 'error');
    }
}

// =====================================================================
// ASSET ACTIONS & MODALS
// =====================================================================
async function lookupAsset(tag) {
    try {
        const res = await api(`/api/assets/lookup/${encodeURIComponent(tag)}`);
        const isWs = res.type === 'workstation';
        const asset = res.data;

        document.getElementById('lookupModalTitle').textContent = `${isWs ? 'Workstation' : 'Peripheral'}: ${isWs ? asset.workstationTag : asset.peripheralTag}`;
        
        let bodyHtml = `
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
                <span class="tag-badge" style="font-size: 18px; color: ${isWs ? '#818cf8' : '#34d399'};">${isWs ? asset.workstationTag : asset.peripheralTag}</span>
                ${statusBadge(asset.status)}
            </div>
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px; font-size: 13.5px;">
        `;

        if (isWs) {
            const assignedPerson = asset.personnel?.fullName || asset.userName;
            bodyHtml += `
                <div><strong>Assigned Personnel:</strong> ${assignedPerson ? `<span style="color: #38bdf8; font-weight: 600;">${escapeHtml(assignedPerson)}</span>` : 'Unassigned'}</div>
                <div><strong>Device Type:</strong> ${escapeHtml(asset.deviceType || 'PC')}</div>
                <div><strong>Processor & Gen:</strong> ${escapeHtml(asset.processorGen || 'N/A')}</div>
                <div><strong>Motherboard:</strong> ${escapeHtml(asset.motherboard || 'N/A')}</div>
                <div><strong>RAM:</strong> ${escapeHtml(asset.ram || 'N/A')}</div>
                <div><strong>Storage:</strong> ${[asset.ssd, asset.hdd].filter(Boolean).map(escapeHtml).join(' / ') || 'N/A'}</div>
                <div><strong>GPU:</strong> ${escapeHtml(asset.gpu || 'N/A')}</div>
                <div><strong>Assigned Date:</strong> ${formatDate(asset.assignedDate)}</div>
                <div style="grid-column: span 2;"><strong>Notes:</strong> ${escapeHtml(asset.notes || 'None')}</div>
            `;
            if (asset.peripherals && asset.peripherals.length) {
                bodyHtml += `
                    <div style="grid-column: span 2; margin-top: 16px; border-top: 1px solid var(--border-subtle); padding-top: 12px;">
                        <h4 style="font-size: 14px; margin-bottom: 8px;">Attached Peripherals (${asset.peripherals.length}):</h4>
                        <div style="display: flex; flex-direction: column; gap: 6px;">
                            ${asset.peripherals.map(p => `
                                <div style="display: flex; justify-content: space-between; padding: 6px 10px; background: rgba(255, 255, 255, 0.03); border-radius: 6px;">
                                    <span><strong style="color: #34d399;">${escapeHtml(p.peripheralTag)}</strong> • ${escapeHtml(p.category || 'Peripheral')} (${escapeHtml(p.modelSpecs || '')})</span>
                                    ${statusBadge(p.status)}
                                </div>
                            `).join('')}
                        </div>
                    </div>
                `;
            }
        } else {
            const hostPerson = asset.workstation?.personnel?.fullName || asset.workstation?.userName;
            bodyHtml += `
                <div><strong>Category:</strong> ${escapeHtml(asset.category || 'N/A')}</div>
                <div><strong>Brand / Manufacturer:</strong> ${escapeHtml(asset.brandManufacturer || 'N/A')}</div>
                <div><strong>Model Specs:</strong> ${escapeHtml(asset.modelSpecs || 'N/A')}</div>
                <div><strong>Linked Workstation:</strong> ${asset.workstationTag ? `<span style="color: var(--accent); font-weight: 600;">${escapeHtml(asset.workstationTag)}</span>` : 'Standalone'}</div>
                <div><strong>Assigned Person:</strong> ${hostPerson ? `<span style="color: #38bdf8;">${escapeHtml(hostPerson)}</span>` : 'Unassigned'}</div>
                <div><strong>Quantity:</strong> ${asset.quantity ?? 1}</div>
                <div><strong>Storage Capacity:</strong> ${escapeHtml(asset.storageCapacity || 'N/A')}</div>
                <div><strong>GPU Specs:</strong> ${escapeHtml(asset.gpuSpecs || 'N/A')}</div>
                <div><strong>Purchase Date:</strong> ${formatDate(asset.purchaseDate)}</div>
                <div><strong>Warranty Expiry:</strong> ${formatDate(asset.warrantyExpiry)}</div>
            `;
        }

        bodyHtml += `</div>`;
        document.getElementById('lookupModalBody').innerHTML = bodyHtml;

        const isViewer = currentUser?.role === 'VIEWER';
        const footer = document.getElementById('lookupModalFooter');
        footer.innerHTML = `
            <button class="btn btn-secondary" onclick="closeModal('lookupModal')">Close</button>
            <button class="btn btn-secondary" onclick="printTag('${isWs ? asset.workstationTag : asset.peripheralTag}', '${isWs ? 'workstation' : 'peripheral'}')"><i class="ph ph-printer"></i> Print Tag</button>
            ${!isViewer ? (asset.status === 'RETIRED'
                ? `<button class="btn btn-success" onclick="restoreAsset('${isWs ? 'workstation' : 'peripheral'}', '${isWs ? asset.workstationTag : asset.peripheralTag}'); closeModal('lookupModal');">Restore Asset</button>`
                : `<button class="btn btn-danger" onclick="retireAsset('${isWs ? 'workstation' : 'peripheral'}', '${isWs ? asset.workstationTag : asset.peripheralTag}'); closeModal('lookupModal');">Retire Asset</button>`
            ) : ''}
        `;

        openModal('lookupModal');
    } catch (err) {}
}

// Workstation Modal Handlers
let editingWorkstationTag = null;

function openWorkstationModal(tag = null) {
    editingWorkstationTag = tag;
    const modalTitle = document.getElementById('workstationModalTitle');
    const form = document.getElementById('workstationForm');
    form.reset();

    // Populate personnel select dropdown
    const select = document.getElementById('wsPersonnelSelect');
    select.innerHTML = `<option value="">-- Unassigned (In Store) --</option>` +
        data.personnel.map(p => `<option value="${escapeHtml(p.id)}">${escapeHtml(p.fullName)} (${escapeHtml(p.department || 'General')})</option>`).join('');

    if (tag) {
        modalTitle.textContent = `Edit Workstation: ${tag}`;
        const ws = data.workstations.find(w => w.workstationTag === tag);
        if (ws) {
            document.getElementById('wsTag').value = ws.workstationTag;
            document.getElementById('wsTag').disabled = true;
            document.getElementById('wsPersonnelSelect').value = ws.personnelId || '';
            document.getElementById('wsDeviceType').value = ws.deviceType || '';
            document.getElementById('wsMotherboard').value = ws.motherboard || '';
            document.getElementById('wsProcessorGen').value = ws.processorGen || '';
            document.getElementById('wsRam').value = ws.ram || '';
            document.getElementById('wsSsd').value = ws.ssd || '';
            document.getElementById('wsHdd').value = ws.hdd || '';
            document.getElementById('wsGpu').value = ws.gpu || '';
            document.getElementById('wsAssignedDate').value = ws.assignedDate ? ws.assignedDate.split('T')[0] : '';
            document.getElementById('wsNotes').value = ws.notes || '';
        }
    } else {
        modalTitle.textContent = 'New Workstation';
        document.getElementById('wsTag').disabled = false;

        // Auto-generate tag if rule exists
        const prefix = data.settings.tagPrefixWs || 'WS';
        const sep = data.settings.tagSeparator || '-';
        const nextNum = (data.workstations.length + 1001);
        document.getElementById('wsTag').value = `${prefix}${sep}${nextNum}`;
    }
    openModal('workstationModal');
}

function editWorkstation(tag) {
    openWorkstationModal(tag);
}

async function handleWorkstationFormSubmit(e) {
    e.preventDefault();
    const tag = document.getElementById('wsTag').value.trim();
    const personnelId = document.getElementById('wsPersonnelSelect').value || null;

    const payload = {
        workstationTag: tag,
        personnelId,
        deviceType: document.getElementById('wsDeviceType').value.trim() || null,
        motherboard: document.getElementById('wsMotherboard').value.trim() || null,
        processorGen: document.getElementById('wsProcessorGen').value.trim() || null,
        ram: document.getElementById('wsRam').value.trim() || null,
        ssd: document.getElementById('wsSsd').value.trim() || null,
        hdd: document.getElementById('wsHdd').value.trim() || null,
        gpu: document.getElementById('wsGpu').value.trim() || null,
        assignedDate: document.getElementById('wsAssignedDate').value || null,
        notes: document.getElementById('wsNotes').value.trim() || null,
    };

    try {
        if (editingWorkstationTag) {
            await api(`/api/workstations/${encodeURIComponent(editingWorkstationTag)}`, {
                method: 'PATCH',
                body: payload
            });
            showToast('Workstation updated successfully', 'success');
        } else {
            await api('/api/workstations', {
                method: 'POST',
                body: payload
            });
            showToast('Workstation created successfully', 'success');
        }
        closeModal('workstationModal');
        await loadAllData();
        switchTab(currentTab);
    } catch (err) {}
}

// Peripheral Modal Handlers
let editingPeripheralTag = null;

function openPeripheralModal(tag = null) {
    editingPeripheralTag = tag;
    const modalTitle = document.getElementById('peripheralModalTitle');
    const form = document.getElementById('peripheralForm');
    form.reset();

    // Populate host workstation dropdown
    const select = document.getElementById('perWorkstationSelect');
    select.innerHTML = `<option value="">-- Standalone (No Host Machine) --</option>` +
        data.workstations.map(w => `<option value="${escapeHtml(w.workstationTag)}">${escapeHtml(w.workstationTag)} (${escapeHtml(w.userName || w.deviceType || 'PC')})</option>`).join('');

    if (tag) {
        modalTitle.textContent = `Edit Peripheral: ${tag}`;
        const p = data.peripherals.find(item => item.peripheralTag === tag);
        if (p) {
            document.getElementById('perTag').value = p.peripheralTag;
            document.getElementById('perTag').disabled = true;
            document.getElementById('perCategory').value = p.category || 'Display';
            document.getElementById('perBrand').value = p.brandManufacturer || '';
            document.getElementById('perModelSpecs').value = p.modelSpecs || '';
            document.getElementById('perWorkstationSelect').value = p.workstationTag || '';
            document.getElementById('perQuantity').value = p.quantity ?? 1;
            document.getElementById('perPurchaseDate').value = p.purchaseDate ? p.purchaseDate.split('T')[0] : '';
            document.getElementById('perWarrantyExpiry').value = p.warrantyExpiry ? p.warrantyExpiry.split('T')[0] : '';
            document.getElementById('perStorageCapacity').value = p.storageCapacity || '';
            document.getElementById('perGpuSpecs').value = p.gpuSpecs || '';
        }
    } else {
        modalTitle.textContent = 'New Peripheral';
        document.getElementById('perTag').disabled = false;

        // Auto-generate tag if rule exists
        const prefix = data.settings.tagPrefixPer || 'PER';
        const sep = data.settings.tagSeparator || '-';
        const nextNum = (data.peripherals.length + 2001);
        document.getElementById('perTag').value = `${prefix}${sep}${nextNum}`;
    }
    openModal('peripheralModal');
}

function editPeripheral(tag) {
    openPeripheralModal(tag);
}

async function handlePeripheralFormSubmit(e) {
    e.preventDefault();
    const tag = document.getElementById('perTag').value.trim();
    const payload = {
        peripheralTag: tag,
        category: document.getElementById('perCategory').value.trim() || null,
        brandManufacturer: document.getElementById('perBrand').value.trim() || null,
        modelSpecs: document.getElementById('perModelSpecs').value.trim() || null,
        workstationTag: document.getElementById('perWorkstationSelect').value.trim() || null,
        quantity: parseInt(document.getElementById('perQuantity').value, 10) || 1,
        purchaseDate: document.getElementById('perPurchaseDate').value || null,
        warrantyExpiry: document.getElementById('perWarrantyExpiry').value || null,
        storageCapacity: document.getElementById('perStorageCapacity').value.trim() || null,
        gpuSpecs: document.getElementById('perGpuSpecs').value.trim() || null,
    };

    try {
        if (editingPeripheralTag) {
            await api(`/api/peripherals/${encodeURIComponent(editingPeripheralTag)}`, {
                method: 'PATCH',
                body: payload
            });
            showToast('Peripheral updated successfully', 'success');
        } else {
            await api('/api/peripherals', {
                method: 'POST',
                body: payload
            });
            showToast('Peripheral created successfully', 'success');
        }
        closeModal('peripheralModal');
        await loadAllData();
        switchTab(currentTab);
    } catch (err) {}
}

// Asset Status Lifecycle
async function retireAsset(kind, tag) {
    if (!confirm(`Are you sure you want to retire ${kind} "${tag}"?`)) return;
    try {
        await api(`/api/assets/${kind}/${encodeURIComponent(tag)}/status`, {
            method: 'PATCH',
            body: { status: 'RETIRED' }
        });
        showToast(`${kind} "${tag}" marked as Retired`, 'success');
        await loadAllData();
        switchTab(currentTab);
    } catch (err) {}
}

async function restoreAsset(kind, tag) {
    try {
        await api(`/api/assets/${kind}/${encodeURIComponent(tag)}/restore`, {
            method: 'POST'
        });
        showToast(`${kind} "${tag}" restored to In Store`, 'success');
        await loadAllData();
        switchTab(currentTab);
    } catch (err) {}
}

// Print Tag Helper
function printTag(tag, type) {
    const area = document.getElementById('printableTagArea');
    const companyLogo = data.settings.companyLogo ? `<img src="${data.settings.companyLogo}" style="width: 32px; height: 32px; object-fit: contain; margin-top: 4px;">` : `<span class="logo">${data.settings.companyName || 'AssetFlow'}</span>`;

    if (type === 'workstation') {
        const ws = data.workstations.find(w => w.workstationTag === tag);
        if (!ws) return;
        const assignedName = ws.personnel?.fullName || ws.userName || 'Unassigned';
        
        area.innerHTML = `
            <div class="tag tag-large print-only-tag">
                <div class="tag-title">Device Details</div>
                <div class="qr-box"><div id="printQrCode"></div>${companyLogo}</div>
                <div class="field-row"><span class="field-label">Username:</span><span class="field-value">${escapeHtml(assignedName)}</span></div>
                <div class="field-row"><span class="field-label">CPU:</span><span class="field-value">${escapeHtml(ws.processorGen || '')}</span></div>
                <div class="field-row"><span class="field-label">Motherboard:</span><span class="field-value">${escapeHtml(ws.motherboard || '')}</span></div>
                <div class="field-row"><span class="field-label">Storage:</span><span class="field-value">${escapeHtml(ws.ssd || ws.hdd || '')}</span></div>
                <div class="field-row"><span class="field-label">RAM:</span><span class="field-value">${escapeHtml(ws.ram || '')}</span></div>
                <div class="field-row"><span class="field-label">GPU:</span><span class="field-value">${escapeHtml(ws.gpu || '')}</span></div>
                <div class="field-row" style="margin-top: 10px;"><span class="field-label" style="font-size: 11px;">Tag No:</span><span class="field-value" style="font-size: 11px; font-weight: bold; border: none;">${escapeHtml(tag)}</span></div>
            </div>
        `;
    } else {
        const p = data.peripherals.find(x => x.peripheralTag === tag);
        if (!p) return;
        const datePurchase = formatDate(p.purchaseDate);

        area.innerHTML = `
            <div class="tag tag-small print-only-tag">
                <div class="tag-title">Peripheral Tag</div>
                <div class="qr-box"><div id="printQrCode"></div>${companyLogo}</div>
                <div class="field-row field-row-small"><span class="field-label">Tag No:</span><span class="field-value" style="font-weight: bold;">${escapeHtml(p.category || 'Peripheral')} - ${escapeHtml(tag)}</span></div>
                <div class="field-row field-row-small"><span class="field-label">Date Purchase:</span><span class="field-value">${escapeHtml(datePurchase)}</span></div>
                ${p.brandManufacturer || p.modelSpecs ? `<div class="field-row field-row-small"><span class="field-label">Model/Brand:</span><span class="field-value" style="font-size:12px;">${escapeHtml(p.brandManufacturer || '')} ${escapeHtml(p.modelSpecs || '')}</span></div>` : ''}
            </div>
        `;
    }

    const qrContainer = document.getElementById('printQrCode');
    qrContainer.innerHTML = '';
    if (window.QRCode) {
        new QRCode(qrContainer, {
            text: tag,
            width: 70,
            height: 70,
            colorDark: "#000000",
            colorLight: "#ffffff",
            correctLevel: QRCode.CorrectLevel.L
        });
        // Make QRCode img styling fit the box
        setTimeout(() => {
            const img = qrContainer.querySelector('img');
            if(img) {
                img.style.width = '100%';
                img.style.height = '100%';
                img.style.margin = '0 auto';
            }
        }, 50);
    }
    openModal('tagPrintModal');
}

// Global Refresh Helper
async function refreshData() {
    showToast('Refreshing inventory data...', 'info');
    await loadAllData();
    switchTab(currentTab);
    showToast('Data synchronized', 'success');
}

// Utility Formatting
function statusBadge(status) {
    if (status === 'IN_STORE') return `<span class="badge badge-instore"><i class="ph ph-check-circle"></i> In Store</span>`;
    if (status === 'ASSIGNED') return `<span class="badge badge-assigned"><i class="ph ph-user"></i> Assigned</span>`;
    if (status === 'OUT_OF_ORDER') return `<span class="badge badge-outoforder"><i class="ph ph-wrench"></i> Out of Order</span>`;
    if (status === 'RETIRED') return `<span class="badge badge-retired"><i class="ph ph-archive"></i> Retired</span>`;
    return `<span class="badge badge-instore">${escapeHtml(status || 'In Store')}</span>`;
}

function formatDate(d) {
    if (!d) return '—';
    try {
        const date = new Date(d);
        return date.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
    } catch {
        return String(d);
    }
}
