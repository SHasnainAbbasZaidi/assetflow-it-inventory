// app.js

// --- Constants & Schemas ---
const CATEGORY_SCHEMAS = {
    'PC/Laptop': [
        { id: 'cpu', label: 'Processor (CPU)', placeholder: 'e.g. Intel Core i7' },
        { id: 'ram', label: 'RAM (GB)', placeholder: 'e.g. 16' },
        { id: 'storage', label: 'Storage', placeholder: 'e.g. 512GB SSD' },
        { id: 'os', label: 'Operating System', placeholder: 'e.g. Windows 11 Pro' },
        { id: 'mac', label: 'MAC Address', placeholder: '00:1A:2B:3C:4D:5E' }
    ],
    'Display': [
        { id: 'resolution', label: 'Resolution', placeholder: 'e.g. 3840x2160' },
        { id: 'size', label: 'Screen Size (Inches)', placeholder: 'e.g. 27' },
        { id: 'refresh', label: 'Refresh Rate (Hz)', placeholder: 'e.g. 144' }
    ],
    'VR': [
        { id: 'headset', label: 'Headset Model', placeholder: 'e.g. Meta Quest 3' },
        { id: 'controllers', label: 'Controllers Included?', placeholder: 'Yes/No' }
    ],
    'Mobile': [
        { id: 'os', label: 'Mobile OS', placeholder: 'e.g. iOS 17' },
        { id: 'storage', label: 'Storage (GB)', placeholder: 'e.g. 256' },
        { id: 'imei', label: 'IMEI Number', placeholder: 'Enter IMEI' }
    ],
    'Keyboard': [
        { id: 'connection', label: 'Connection Type', placeholder: 'Wireless / Wired' },
        { id: 'layout', label: 'Layout', placeholder: 'e.g. QWERTY US' }
    ],
    'Mouse': [
        { id: 'connection', label: 'Connection Type', placeholder: 'Wireless / Wired' },
        { id: 'dpi', label: 'DPI', placeholder: 'e.g. 4000' }
    ],
    'Headphones': [
        { id: 'connection', label: 'Connection Type', placeholder: 'Wireless / Wired' },
        { id: 'mic', label: 'Has Microphone?', placeholder: 'Yes / No' }
    ],
    'Software': [
        { id: 'licenseKey', label: 'License Key', placeholder: 'XXXX-XXXX-XXXX-XXXX' },
        { id: 'expiry', label: 'Expiry Date', placeholder: 'YYYY-MM-DD' }
    ],
    'Other': [
        { id: 'notes', label: 'Additional Notes', placeholder: 'Any extra info...' }
    ]
};

// --- Database Wrapper (IndexedDB) ---
const DB_NAME = 'AssetFlowDB';
const DB_VERSION = 1;
let db;

function initDB() {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open(DB_NAME, DB_VERSION);

        request.onerror = (event) => reject("IndexedDB error: " + event.target.error);

        request.onsuccess = (event) => {
            db = event.target.result;
            resolve(db);
        };

        request.onupgradeneeded = (event) => {
            const db = event.target.result;
            if (!db.objectStoreNames.contains('assets')) {
                db.createObjectStore('assets', { keyPath: 'id' });
            }
            if (!db.objectStoreNames.contains('users')) {
                db.createObjectStore('users', { keyPath: 'id' });
            }
            if (!db.objectStoreNames.contains('logs')) {
                db.createObjectStore('logs', { keyPath: 'id' });
            }
        };
    });
}

// DB Helper Functions
function dbGetAll(storeName) {
    return new Promise((resolve) => {
        const transaction = db.transaction([storeName], 'readonly');
        const store = transaction.objectStore(storeName);
        const request = store.getAll();
        request.onsuccess = () => resolve(request.result);
    });
}

function dbPut(storeName, item) {
    return new Promise((resolve) => {
        const transaction = db.transaction([storeName], 'readwrite');
        const store = transaction.objectStore(storeName);
        store.put(item);
        transaction.oncomplete = () => resolve();
    });
}

function dbDelete(storeName, id) {
    return new Promise((resolve) => {
        const transaction = db.transaction([storeName], 'readwrite');
        const store = transaction.objectStore(storeName);
        store.delete(id);
        transaction.oncomplete = () => resolve();
    });
}

// --- State Management ---
let assets = [];
let activityLogs = [];
let users = [];
let html5QrcodeScanner = null;

async function loadData() {
    await initDB();
    assets = await dbGetAll('assets');
    users = await dbGetAll('users');
    activityLogs = await dbGetAll('logs');
    
    // Sort logs descending
    activityLogs.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

    if (users.length === 0) {
        // Seed default user
        await addUser({ name: 'Unassigned', department: 'System', email: 'none@system' });
    }

    renderCurrentView();
}

// UUID Generator for globally unique tags
function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    }).toUpperCase();
}

async function logActivity(action, assetId, details) {
    const log = {
        id: generateUUID(),
        timestamp: new Date().toISOString(),
        user: 'Admin',
        action: action,
        assetId: assetId,
        details: details
    };
    activityLogs.unshift(log);
    await dbPut('logs', log);
}

async function addAsset(assetData) {
    const newAsset = {
        id: generateUUID().split('-')[0], // Use first segment for manageable QR tags
        ...assetData,
        dateAdded: new Date().toISOString().split('T')[0]
    };
    assets.push(newAsset);
    await dbPut('assets', newAsset);
    await logActivity('Added Asset', newAsset.id, `Added ${newAsset.name} (${newAsset.category})`);
}

async function updateAsset(id, assetData) {
    const index = assets.findIndex(a => a.id === id);
    if (index !== -1) {
        const oldStatus = assets[index].status;
        const oldAssignee = assets[index].assignee;
        assets[index] = { ...assets[index], ...assetData };
        await dbPut('assets', assets[index]);
        
        let details = `Updated ${assets[index].name}`;
        if(oldStatus !== assetData.status) details += ` | Status: ${oldStatus} -> ${assetData.status}`;
        if(oldAssignee !== assetData.assignee) {
            const oldUser = users.find(u => u.id === oldAssignee)?.name || 'Unassigned';
            const newUser = users.find(u => u.id === assetData.assignee)?.name || 'Unassigned';
            details += ` | Reassigned: ${oldUser} -> ${newUser}`;
        }
        await logActivity('Updated Asset', id, details);
    }
}

async function deleteAsset(id) {
    const asset = assets.find(a => a.id === id);
    if(asset) {
        assets = assets.filter(a => a.id !== id);
        await dbDelete('assets', id);
        await logActivity('Deleted Asset', id, `Removed ${asset.name} from inventory`);
    }
}

// User Management
async function addUser(userData) {
    const newUser = {
        id: generateUUID(),
        ...userData
    };
    users.push(newUser);
    await dbPut('users', newUser);
    return newUser;
}

async function updateUser(id, userData) {
    const index = users.findIndex(u => u.id === id);
    if (index !== -1) {
        users[index] = { ...users[index], ...userData };
        await dbPut('users', users[index]);
    }
}

async function deleteUser(id) {
    // Unassign all assets first
    for (let asset of assets) {
        if (asset.assignee === id) {
            asset.assignee = '';
            await dbPut('assets', asset);
        }
    }
    users = users.filter(u => u.id !== id);
    await dbDelete('users', id);
}


// --- Export to CSV Logic ---
function exportToCSV() {
    if (assets.length === 0) {
        alert("No assets to export.");
        return;
    }

    const headers = ['ID', 'Name', 'Category', 'Serial', 'Status', 'Assigned User', 'Date Added'];
    let csvContent = headers.join(',') + '\n';

    assets.forEach(asset => {
        const userName = users.find(u => u.id === asset.assignee)?.name || 'Unassigned';
        const row = [
            asset.id,
            `"${asset.name}"`,
            `"${asset.category}"`,
            `"${asset.serial}"`,
            asset.status,
            `"${userName}"`,
            asset.dateAdded
        ];
        csvContent += row.join(',') + '\n';
    });

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement("a");
    const url = URL.createObjectURL(blob);
    link.setAttribute("href", url);
    link.setAttribute("download", `Inventory_Report_${new Date().toISOString().split('T')[0]}.csv`);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

// --- Navigation & Routing ---
let currentView = 'dashboard';

function navigateTo(viewId) {
    if (currentView === 'scanner' && html5QrcodeScanner) {
        try { html5QrcodeScanner.clear(); } catch(e) {}
    }
    currentView = viewId;
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
        if (item.dataset.view === viewId) item.classList.add('active');
    });
    renderCurrentView();
}

// --- Rendering Logic ---
function renderCurrentView() {
    const container = document.getElementById('viewContainer');
    container.innerHTML = '';

    if (currentView === 'dashboard') {
        container.innerHTML = renderDashboard();
    } else if (currentView === 'assets') {
        container.innerHTML = renderAssetList();
        attachAssetListListeners();
    } else if (currentView === 'logs') {
        container.innerHTML = renderLogs();
    } else if (currentView === 'scanner') {
        container.innerHTML = renderScanner();
        initScanner();
    } else if (currentView === 'users') {
        container.innerHTML = renderUsersList();
        attachUserListListeners();
    } else if (currentView === 'tags') {
        container.innerHTML = renderTagGenerator();
        attachTagGeneratorListeners();
    } else if (currentView === 'settings') {
        container.innerHTML = renderSettings();
        attachSettingsListeners();
    }
}

function renderDashboard() {
    const total = assets.filter(a => a.status !== 'Retired').length;
    const available = assets.filter(a => a.status === 'Available').length;
    const inUse = assets.filter(a => a.status === 'In Use').length;
    const deprecated = assets.filter(a => a.status === 'Retired').length;

    return `
        <div class="view-section active" id="dashboardView">
            <div class="dashboard-header">
                <div>
                    <h2>Overview</h2>
                    <p>Welcome back. Here's your inventory status.</p>
                </div>
            </div>
            
            <div class="stats-grid">
                <div class="stat-card glass-panel">
                    <div class="stat-header"><span>Active Assets</span><div class="stat-icon" style="background: rgba(99, 102, 241, 0.15); color: var(--accent-primary)"><i class="ph ph-hard-drives"></i></div></div>
                    <div class="stat-value">${total}</div>
                </div>
                <div class="stat-card glass-panel">
                    <div class="stat-header"><span>Available</span><div class="stat-icon" style="background: var(--status-available-bg); color: var(--status-available-text)"><i class="ph ph-check-circle"></i></div></div>
                    <div class="stat-value">${available}</div>
                </div>
                <div class="stat-card glass-panel">
                    <div class="stat-header"><span>In Use</span><div class="stat-icon" style="background: var(--status-inuse-bg); color: var(--status-inuse-text)"><i class="ph ph-user"></i></div></div>
                    <div class="stat-value">${inUse}</div>
                </div>
                <div class="stat-card glass-panel">
                    <div class="stat-header"><span>Deprecated</span><div class="stat-icon" style="background: var(--status-retired-bg); color: var(--status-retired-text)"><i class="ph ph-trash"></i></div></div>
                    <div class="stat-value">${deprecated}</div>
                </div>
            </div>
        </div>
    `;
}

function renderAssetList() {
    return `
        <div class="view-section active" id="assetsView">
            <div class="dashboard-header">
                <div>
                    <h2>Asset Directory</h2>
                    <p>Manage all hardware, peripherals, and software assets.</p>
                </div>
                <button class="btn-success" id="btnExportCsv"><i class="ph ph-download-simple"></i> Export CSV</button>
            </div>
            <div class="table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>ID / Name</th>
                            <th>Category</th>
                            <th>Serial / Tag</th>
                            <th>Assigned To</th>
                            <th>Status</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${assets.map(asset => {
                            const assignee = users.find(u => u.id === asset.assignee);
                            return `
                            <tr style="${asset.status === 'Retired' ? 'opacity: 0.6;' : ''}">
                                <td><div style="font-size: 11px; color: var(--accent-primary)">${asset.id}</div><strong>${asset.name}</strong></td>
                                <td>${asset.category}</td>
                                <td style="font-family: monospace; color: var(--text-muted)">${asset.serial}</td>
                                <td>${assignee ? assignee.name : '<span style="color: var(--text-muted)">Unassigned</span>'}</td>
                                <td><span class="status-badge status-${asset.status.replace(/\s+/g, '')}">${asset.status}</span></td>
                                <td>
                                    <button class="icon-btn btn-edit" data-id="${asset.id}" style="margin-left: 8px;"><i class="ph ph-pencil-simple"></i></button>
                                    <button class="icon-btn btn-delete" data-id="${asset.id}" style="color: var(--status-retired-text); margin-left: 8px;"><i class="ph ph-trash"></i></button>
                                </td>
                            </tr>
                        `}).join('')}
                    </tbody>
                </table>
            </div>
        </div>
    `;
}

function renderUsersList() {
    return `
        <div class="view-section active" id="usersView">
            <div class="dashboard-header">
                <div>
                    <h2>Personnel Directory</h2>
                    <p>Manage employees and their assigned inventory.</p>
                </div>
                <button class="btn-primary" id="btnAddUser"><i class="ph ph-plus"></i> Add Person</button>
            </div>
            <div class="table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>Department</th>
                            <th>Email</th>
                            <th>Assigned Items</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${users.filter(u => u.name !== 'Unassigned').map(user => {
                            const assignedCount = assets.filter(a => a.assignee === user.id && a.status !== 'Retired').length;
                            return `
                            <tr>
                                <td><strong>${user.name}</strong></td>
                                <td>${user.department}</td>
                                <td>${user.email}</td>
                                <td><span class="status-badge" style="background: var(--accent-glow); color: var(--accent-primary)">${assignedCount} Items</span></td>
                                <td>
                                    <button class="icon-btn btn-view-inventory" data-id="${user.id}" title="View Inventory"><i class="ph ph-list-dashes"></i></button>
                                    <button class="icon-btn btn-edit-user" data-id="${user.id}" style="margin-left: 8px;"><i class="ph ph-pencil-simple"></i></button>
                                    <button class="icon-btn btn-delete-user" data-id="${user.id}" style="color: var(--status-retired-text); margin-left: 8px;"><i class="ph ph-trash"></i></button>
                                </td>
                            </tr>
                        `}).join('')}
                    </tbody>
                </table>
            </div>
        </div>
    `;
}

function renderLogs() {
    return `
        <div class="view-section active" id="logsView">
            <div class="dashboard-header">
                <h2>Activity Logs</h2>
                <p>Audit trail of all asset modifications and system events.</p>
            </div>
            <div class="table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Date / Time</th>
                            <th>Action</th>
                            <th>Asset ID</th>
                            <th>User</th>
                            <th>Details</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${activityLogs.slice(0, 100).map(log => `
                            <tr>
                                <td style="color: var(--text-muted); font-size: 13px;">${new Date(log.timestamp).toLocaleString()}</td>
                                <td><span style="color: var(--accent-primary); font-weight: 500;">${log.action}</span></td>
                                <td style="font-family: monospace;">${log.assetId}</td>
                                <td>${log.user}</td>
                                <td>${log.details}</td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            </div>
        </div>
    `;
}

function renderScanner() {
    return `
        <div class="view-section active" id="scannerView">
            <div class="dashboard-header" style="text-align: center;">
                <h2>QR Tag Scanner</h2>
                <p>Scan an asset tag to quickly view, edit, or check it out.</p>
            </div>
            <div id="reader"></div>
            <div style="text-align: center; margin-top: 20px;">
                <p style="color: var(--text-muted)">Or manually enter Asset ID:</p>
                <div class="search-bar" style="margin: 10px auto;">
                    <i class="ph ph-magnifying-glass"></i>
                    <input type="text" id="manualScanInput" placeholder="e.g. A1B2C3">
                </div>
            </div>
        </div>
    `;
}

function renderTagGenerator() {
    return `
        <div class="view-section active" id="tagsView">
            <div class="dashboard-header">
                <div>
                    <h2>Tag Generator</h2>
                    <p>Select assets to generate a printable PDF of QR tags.</p>
                </div>
                <button class="btn-primary" id="btnGeneratePdf"><i class="ph ph-file-pdf"></i> Generate PDF</button>
            </div>
            <div class="table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th style="width: 40px;"><input type="checkbox" id="selectAllTags"></th>
                            <th>Tag ID</th>
                            <th>Asset Name</th>
                            <th>Category</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${assets.filter(a => a.status !== 'Retired').map(asset => `
                            <tr>
                                <td><input type="checkbox" class="tag-checkbox" value="${asset.id}"></td>
                                <td style="font-family: monospace;">${asset.id}</td>
                                <td><strong>${asset.name}</strong></td>
                                <td>${asset.category}</td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            </div>
        </div>
    `;
}

function renderSettings() {
    return `
        <div class="view-section active" id="settingsView">
            <div class="dashboard-header">
                <h2>Settings</h2>
                <p>Configure app preferences and custom branding.</p>
            </div>
            
            <div class="settings-container">
                <div class="glass-panel" style="padding: 24px; border-radius: var(--border-radius-lg);">
                    <h3>Company Branding</h3>
                    <p style="margin-bottom: 20px;">Upload a company logo to appear on all generated QR tags.</p>
                    
                    <div class="upload-area" id="logoUploadArea">
                        <i class="ph ph-upload-simple" style="font-size: 32px; color: var(--accent-primary); margin-bottom: 10px;"></i>
                        <p>Click or drag image to upload logo</p>
                        <input type="file" id="logoInput" accept="image/*" style="display: none;">
                    </div>
                    
                    <div style="text-align: center;">
                        <img id="settingsLogoPreview" class="logo-preview" src="">
                    </div>
                    
                    <div style="margin-top: 20px; display: flex; justify-content: flex-end;">
                        <button class="btn-primary" id="btnSaveSettings">Save Branding</button>
                    </div>
                </div>
            </div>
        </div>
    `;
}

// --- DOM Interactions ---
function attachAssetListListeners() {
    document.querySelectorAll('.btn-edit').forEach(btn => btn.addEventListener('click', (e) => {
        const asset = assets.find(a => a.id === e.currentTarget.dataset.id);
        if (asset) openModal(asset);
    }));

    document.querySelectorAll('.btn-delete').forEach(btn => btn.addEventListener('click', async (e) => {
        if(confirm('Are you sure you want to delete this asset? This cannot be undone.')) {
            await deleteAsset(e.currentTarget.dataset.id);
            renderCurrentView();
        }
    }));

    document.getElementById('btnExportCsv').addEventListener('click', exportToCSV);
}

function attachTagGeneratorListeners() {
    document.getElementById('selectAllTags').addEventListener('change', (e) => {
        const checked = e.target.checked;
        document.querySelectorAll('.tag-checkbox').forEach(cb => cb.checked = checked);
    });

    document.getElementById('btnGeneratePdf').addEventListener('click', async () => {
        const selectedIds = Array.from(document.querySelectorAll('.tag-checkbox:checked')).map(cb => cb.value);
        if (selectedIds.length === 0) return alert('Select at least one asset to generate tags.');
        await generateTagsPDF(selectedIds);
    });
}

function attachUserListListeners() {
    document.getElementById('btnAddUser').addEventListener('click', () => openUserModal());

    document.querySelectorAll('.btn-edit-user').forEach(btn => btn.addEventListener('click', (e) => {
        const user = users.find(u => u.id === e.currentTarget.dataset.id);
        if (user) openUserModal(user);
    }));

    document.querySelectorAll('.btn-delete-user').forEach(btn => btn.addEventListener('click', async (e) => {
        if(confirm('Are you sure you want to delete this person? Their assets will be marked Unassigned.')) {
            await deleteUser(e.currentTarget.dataset.id);
            renderCurrentView();
        }
    }));

    document.querySelectorAll('.btn-view-inventory').forEach(btn => btn.addEventListener('click', (e) => {
        const user = users.find(u => u.id === e.currentTarget.dataset.id);
        if (user) showUserInventoryModal(user);
    }));
}

function attachSettingsListeners() {
    const uploadArea = document.getElementById('logoUploadArea');
    const logoInput = document.getElementById('logoInput');
    const preview = document.getElementById('settingsLogoPreview');
    let base64Logo = localStorage.getItem('companyLogo') || '';

    if (base64Logo) {
        preview.src = base64Logo;
        preview.style.display = 'inline-block';
    }

    uploadArea.addEventListener('click', () => logoInput.click());

    logoInput.addEventListener('change', (e) => {
        const file = e.target.files[0];
        if (file) {
            const reader = new FileReader();
            reader.onload = (event) => {
                base64Logo = event.target.result;
                preview.src = base64Logo;
                preview.style.display = 'inline-block';
            };
            reader.readAsDataURL(file);
        }
    });

    document.getElementById('btnSaveSettings').addEventListener('click', () => {
        if (base64Logo) {
            localStorage.setItem('companyLogo', base64Logo);
            alert("Settings saved successfully!");
        }
    });
}

// --- User Inventory Modal ---
function showUserInventoryModal(user) {
    document.getElementById('inventoryModalTitle').textContent = `Assigned Inventory: ${user.name}`;
    const listContainer = document.getElementById('userInventoryList');
    
    const userAssets = assets.filter(a => a.assignee === user.id && a.status !== 'Retired');
    
    if(userAssets.length === 0) {
        listContainer.innerHTML = '<p style="color: var(--text-muted)">No active assets assigned to this person.</p>';
    } else {
        listContainer.innerHTML = `
            <table class="data-table">
                <thead><tr><th>Name</th><th>Category</th><th>Serial</th><th>Status</th></tr></thead>
                <tbody>
                    ${userAssets.map(a => `
                        <tr>
                            <td><strong>${a.name}</strong></td>
                            <td>${a.category}</td>
                            <td style="font-family: monospace;">${a.serial}</td>
                            <td><span class="status-badge status-${a.status.replace(/\s+/g, '')}">${a.status}</span></td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
    }
    document.getElementById('userInventoryModal').classList.add('active');
}
document.getElementById('btnCloseInventoryModal').addEventListener('click', () => document.getElementById('userInventoryModal').classList.remove('active'));


// --- Asset Form Modal & Dynamic Fields ---
const modal = document.getElementById('assetModal');
const form = document.getElementById('assetForm');
const categorySelect = document.getElementById('assetCategory');
const dynamicContainer = document.getElementById('dynamicFieldsContainer');
const assigneeSelect = document.getElementById('assetAssignee');

function populateUserDropdown() {
    assigneeSelect.innerHTML = `<option value="">Unassigned</option>` + 
        users.filter(u => u.name !== 'Unassigned').map(u => `<option value="${u.id}">${u.name} (${u.department})</option>`).join('');
}

categorySelect.addEventListener('change', (e) => renderDynamicFields(e.target.value));

function renderDynamicFields(category, existingData = {}) {
    const schema = CATEGORY_SCHEMAS[category];
    if (!schema || schema.length === 0) {
        dynamicContainer.classList.remove('active');
        dynamicContainer.innerHTML = '';
        return;
    }
    dynamicContainer.classList.add('active');
    let html = `<h4>${category} Specifications</h4>`;
    schema.forEach(field => {
        html += `
            <div class="form-group" style="margin-bottom: 12px;">
                <label for="custom_${field.id}">${field.label}</label>
                <input type="text" id="custom_${field.id}" placeholder="${field.placeholder || ''}" value="${existingData[field.id] || ''}">
            </div>
        `;
    });
    dynamicContainer.innerHTML = html;
}

function openModal(assetToEdit = null) {
    document.getElementById('modalTitle').textContent = assetToEdit ? 'Edit Asset' : 'Add New Asset';
    dynamicContainer.innerHTML = '';
    dynamicContainer.classList.remove('active');
    populateUserDropdown();

    if (assetToEdit) {
        document.getElementById('assetId').value = assetToEdit.id;
        document.getElementById('assetName').value = assetToEdit.name;
        document.getElementById('assetCategory').value = assetToEdit.category;
        document.getElementById('assetSerial').value = assetToEdit.serial;
        document.getElementById('assetStatus').value = assetToEdit.status;
        document.getElementById('assetAssignee').value = assetToEdit.assignee;
        renderDynamicFields(assetToEdit.category, assetToEdit.customFields || {});
    } else {
        form.reset();
        document.getElementById('assetId').value = '';
    }
    modal.classList.add('active');
}

function closeModal() { modal.classList.remove('active'); form.reset(); }
document.getElementById('btnCloseModal').addEventListener('click', closeModal);
document.getElementById('btnCancelModal').addEventListener('click', closeModal);

form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const category = document.getElementById('assetCategory').value;
    const schema = CATEGORY_SCHEMAS[category] || [];
    const customFields = {};
    schema.forEach(field => {
        const input = document.getElementById(`custom_${field.id}`);
        if(input) customFields[field.id] = input.value;
    });

    const assetData = {
        name: document.getElementById('assetName').value,
        category: category,
        serial: document.getElementById('assetSerial').value,
        status: document.getElementById('assetStatus').value,
        assignee: document.getElementById('assetAssignee').value,
        customFields: customFields
    };

    const id = document.getElementById('assetId').value;
    if (id) await updateAsset(id, assetData);
    else await addAsset(assetData);

    closeModal();
    renderCurrentView();
});

// --- User Form Modal ---
const userModal = document.getElementById('userModal');
const userForm = document.getElementById('userForm');

function openUserModal(userToEdit = null) {
    document.getElementById('userModalTitle').textContent = userToEdit ? 'Edit Personnel' : 'Add Personnel';
    if (userToEdit) {
        document.getElementById('userId').value = userToEdit.id;
        document.getElementById('userName').value = userToEdit.name;
        document.getElementById('userDepartment').value = userToEdit.department;
        document.getElementById('userEmail').value = userToEdit.email;
    } else {
        userForm.reset();
        document.getElementById('userId').value = '';
    }
    userModal.classList.add('active');
}

function closeUserModal() { userModal.classList.remove('active'); userForm.reset(); }
document.getElementById('btnCloseUserModal').addEventListener('click', closeUserModal);
document.getElementById('btnCancelUserModal').addEventListener('click', closeUserModal);

userForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const userData = {
        name: document.getElementById('userName').value,
        department: document.getElementById('userDepartment').value,
        email: document.getElementById('userEmail').value,
    };
    const id = document.getElementById('userId').value;
    if (id) await updateUser(id, userData);
    else await addUser(userData);

    closeUserModal();
    renderCurrentView();
});

// --- PDF Tag Generation ---
async function generateTagsPDF(selectedIds) {
    if (typeof window.jspdf === 'undefined') {
        alert("PDF library not loaded. Check your internet connection.");
        return;
    }
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF({ format: 'a4', unit: 'mm' });
    
    const logoData = localStorage.getItem('companyLogo');
    
    const marginX = 15; const marginY = 15;
    const tagWidth = 85; const tagHeight = 60;
    const spacingX = 10; const spacingY = 10;
    
    let x = marginX; let y = marginY;
    let col = 0; let row = 0;
    
    const hiddenQr = document.createElement('div');
    document.body.appendChild(hiddenQr);
    
    // UI Feedback
    const btn = document.getElementById('btnGeneratePdf');
    const originalText = btn.innerHTML;
    btn.innerHTML = '<i class="ph ph-spinner ph-spin"></i> Generating...';
    btn.disabled = true;
    
    for (let i = 0; i < selectedIds.length; i++) {
        const asset = assets.find(a => a.id === selectedIds[i]);
        if(!asset) continue;
        
        if (row > 3) {
            doc.addPage();
            col = 0; row = 0;
            x = marginX; y = marginY;
        }
        
        // Draw Box
        doc.setLineWidth(0.5);
        doc.rect(x, y, tagWidth, tagHeight);
        
        // 1. Logo
        if (logoData) {
            try {
                // Constrain max width/height
                doc.addImage(logoData, 'PNG', x + (tagWidth/2) - 15, y + 5, 30, 15);
            } catch(e) {
                doc.setFontSize(10);
                doc.text("LOGO ERROR", x + (tagWidth/2), y + 15, {align: "center"});
            }
        } else {
            doc.setFontSize(12);
            doc.setFont('helvetica', 'bold');
            doc.text("COMPANY LOGO", x + (tagWidth/2), y + 15, {align: "center"});
        }
        
        // 2. QR Code
        hiddenQr.innerHTML = '';
        new QRCode(hiddenQr, { text: asset.id, width: 200, height: 200, correctLevel : QRCode.CorrectLevel.H });
        
        // Wait for canvas to render
        await new Promise(r => setTimeout(r, 50)); 
        const canvas = hiddenQr.querySelector('canvas');
        if (canvas) {
            const qrDataUrl = canvas.toDataURL('image/png');
            doc.addImage(qrDataUrl, 'PNG', x + (tagWidth/2) - 15, y + 22, 30, 30);
        }
        
        // 3. Tag Number
        doc.setFontSize(10);
        doc.setFont('helvetica', 'bold');
        doc.text(`Tag No: ${asset.id}`, x + (tagWidth/2), y + 56, {align: "center"});
        
        col++;
        if (col > 1) {
            col = 0; row++;
            x = marginX; y = marginY + (row * (tagHeight + spacingY));
        } else {
            x = marginX + tagWidth + spacingX;
        }
    }
    
    document.body.removeChild(hiddenQr);
    doc.save(`Asset_Tags_${new Date().toISOString().split('T')[0]}.pdf`);
    
    // Reset UI
    btn.innerHTML = originalText;
    btn.disabled = false;
}

// --- QR Scanner Logic ---
function initScanner() {
    if(typeof Html5QrcodeScanner === 'undefined') return;
    html5QrcodeScanner = new Html5QrcodeScanner("reader", { fps: 10, qrbox: {width: 250, height: 250} }, false);
    html5QrcodeScanner.render(
        (decodedText) => {
            const asset = assets.find(a => a.id === decodedText || a.serial === decodedText);
            if(asset) {
                try { html5QrcodeScanner.clear(); } catch(e){}
                navigateTo('assets');
                openModal(asset);
                logActivity('Scanned Asset', asset.id, 'Asset loaded via QR scan');
            } else alert(`Asset not found: ${decodedText}`);
        }, 
        () => {}
    );

    document.getElementById('manualScanInput').addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            const decodedText = this.value.trim();
            const asset = assets.find(a => a.id === decodedText || a.serial === decodedText);
            if(asset) {
                try { html5QrcodeScanner.clear(); } catch(e){}
                navigateTo('assets');
                openModal(asset);
                logActivity('Scanned Asset', asset.id, 'Asset loaded via manual scan');
            } else alert(`Asset not found: ${decodedText}`);
        }
    });
}

// --- Initialization ---
document.addEventListener('DOMContentLoaded', async () => {
    // We must wait for DB to load before rendering
    await loadData();
    
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            navigateTo(item.dataset.view);
        });
    });

    document.getElementById('btnAddAsset').addEventListener('click', () => openModal());

    document.getElementById('globalSearch').addEventListener('input', (e) => {
        const query = e.target.value.toLowerCase();
        if(currentView !== 'assets' && currentView !== 'users') navigateTo('assets');
        
        const rows = document.querySelectorAll('.data-table tbody tr');
        rows.forEach(row => {
            const text = row.textContent.toLowerCase();
            row.style.display = text.includes(query) ? '' : 'none';
        });
    });

    navigateTo('dashboard');
});
