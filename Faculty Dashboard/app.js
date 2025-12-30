// Configuration
const AUTH_URL = "https://attendance-automation-app-auth.onrender.com";
const RESOURCE_URL = "https://attendance-automation-app.onrender.com";

// DOM Elements
const loginView = document.getElementById('login-view');
const dashboardView = document.getElementById('dashboard-view');
const loginForm = document.getElementById('login-form');
const loginError = document.getElementById('login-error');
const logoutBtn = document.getElementById('logout-btn');

// Tabs
const tabOverview = document.getElementById('tab-overview');
const tabHistory = document.getElementById('tab-history');
const sectionOverview = document.getElementById('section-overview');
const sectionHistory = document.getElementById('section-history');

// Buttons & Tables
const refreshBtn = document.getElementById('refresh-btn');
const refreshHistoryBtn = document.getElementById('refresh-history-btn');
const statsBody = document.getElementById('stats-body');
const historyBody = document.getElementById('history-body');

// State
const SECTION = "A"; // Hardcoded section for MVP
let accessToken = sessionStorage.getItem('faculty_access_token');
let refreshToken = sessionStorage.getItem('faculty_refresh_token');
let chartInstance = null;

// Init
if (accessToken) {
    showDashboard();
}

// --- Tab Logic ---

tabOverview.addEventListener('click', () => {
    switchTab('overview');
});

tabHistory.addEventListener('click', () => {
    switchTab('history');
});

function switchTab(tab) {
    if (tab === 'overview') {
        tabOverview.classList.add('active');
        tabHistory.classList.remove('active');
        sectionOverview.classList.remove('d-none');
        sectionHistory.classList.add('d-none');
    } else {
        tabOverview.classList.remove('active');
        tabHistory.classList.add('active');
        sectionOverview.classList.add('d-none');
        sectionHistory.classList.remove('d-none');
        fetchHistory(); // Load data on switch
    }
}

// --- Auth Functions ---

loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    const btn = document.getElementById('login-btn');

    btn.disabled = true;
    loginError.classList.add('d-none');

    try {
        const res = await fetch(`${AUTH_URL}/check_faculty_login?username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`, {
            method: 'POST'
        });
        const data = await res.json();

        if (res.ok) {
            accessToken = data.access_token;
            refreshToken = data.refresh_token;
            sessionStorage.setItem('faculty_access_token', accessToken);
            sessionStorage.setItem('faculty_refresh_token', refreshToken);
            showDashboard();
        } else {
            showError(data.detail || 'Login failed');
        }
    } catch (err) {
        showError('Could not connect to server. Check console for details.');
        console.error("Login Error:", err);
    } finally {
        btn.disabled = false;
    }
});

logoutBtn.addEventListener('click', () => {
    sessionStorage.removeItem('faculty_access_token');
    sessionStorage.removeItem('faculty_refresh_token');
    accessToken = null;
    refreshToken = null;
    loginView.classList.remove('d-none');
    dashboardView.classList.add('d-none');
});

function showError(msg) {
    loginError.textContent = msg;
    loginError.classList.remove('d-none');
}

// --- Dashboard Functions ---

function showDashboard() {
    loginView.classList.add('d-none');
    dashboardView.classList.remove('d-none');
    fetchStats();
}

refreshBtn.addEventListener('click', fetchStats);

async function refreshAccessToken() {
    try {
        const res = await fetch(`${AUTH_URL}/refresh`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ refresh_token: refreshToken })
        });

        if (res.ok) {
            const data = await res.json();
            accessToken = data.access_token;
            refreshToken = data.refresh_token;
            sessionStorage.setItem('faculty_access_token', accessToken);
            sessionStorage.setItem('faculty_refresh_token', refreshToken);
            return true;
        }
        return false;
    } catch (err) {
        console.error("Refresh Token Error:", err);
        return false;
    }
}

async function fetchStats() {
    try {
        const res = await fetch(`${RESOURCE_URL}/get_all_student_stats?section=${encodeURIComponent(SECTION)}`, {
            headers: { 'Authorization': `Bearer ${accessToken}` }
        });

        if (res.status === 401) {
            // Try to refresh token
            const refreshed = await refreshAccessToken();
            if (refreshed) {
                // Retry the request with new token
                return fetchStats();
            } else {
                // Refresh failed, logout
                logoutBtn.click();
            }
            return;
        }

        const data = await res.json();
        renderData(data);
    } catch (err) {
        console.error("Stats Fetch Error:", err);
        alert('Failed to fetch data. See console.');
    }
}

function renderData(data) {
    statsBody.innerHTML = '';

    // Summary Vars
    let totalStudents = new Set();
    let totalClasses = 0;
    let sumPercentage = 0;
    let passedCount = 0;

    // Sort by lowest attendance first
    data.sort((a, b) => a.percentage - b.percentage);

    data.forEach(item => {
        totalStudents.add(item.username);
        totalClasses = Math.max(totalClasses, item.total); // Approximate max classes
        sumPercentage += item.percentage;
        if (item.percentage >= 75) passedCount++;

        // Color coding
        let color = 'bg-danger';
        if (item.percentage >= 75) color = 'bg-success';
        else if (item.percentage >= 50) color = 'bg-warning';

        const row = document.createElement('tr');
        row.innerHTML = `
            <td class="ps-4 fw-bold text-dark">${item.username}</td>
            <td><span class="badge bg-light text-secondary border">${item.subject}</span></td>
            <td class="text-center font-monospace small">${item.attended} / ${item.total}</td>
            <td class="pe-4">
                <div class="d-flex align-items-center justify-content-end">
                    <div class="progress w-50 me-2" style="height: 6px;">
                        <div class="progress-bar ${color}" style="width: ${item.percentage}%"></div>
                    </div>
                    <span class="fw-bold small badge-percent text-end">${item.percentage}%</span>
                </div>
            </td>
        `;
        statsBody.appendChild(row);
    });

    // Update Summary Cards
    document.getElementById('total-students').textContent = totalStudents.size;
    document.getElementById('total-classes').textContent = totalClasses; // Simplified
    const avg = data.length ? (sumPercentage / data.length).toFixed(1) : 0;
    document.getElementById('avg-attendance').textContent = `${avg}%`;

    // Update Chart
    updateChart(passedCount, data.length - passedCount);

    // Pass Rate
    const passRate = data.length ? ((passedCount / data.length) * 100).toFixed(1) : 0;
    document.getElementById('pass-rate').textContent = `${passRate}%`;
}

function updateChart(passed, failed) {
    const ctx = document.getElementById('attendanceChart').getContext('2d');

    if (chartInstance) chartInstance.destroy();

    chartInstance = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Good Attendance (>75%)', 'Low Attendance (<75%)'],
            datasets: [{
                data: [passed, failed],
                backgroundColor: ['#198754', '#dc3545'],
                borderWidth: 0,
                hoverOffset: 4
            }]
        },
        options: {
            responsive: true,
            cutout: '75%',
            plugins: {
                legend: { position: 'bottom', labels: { usePointStyle: true } }
            }
        }
    });
}

// --- History Logic ---

refreshHistoryBtn.addEventListener('click', fetchHistory);

async function fetchHistory() {
    try {
        const res = await fetch(`${RESOURCE_URL}/get_attendance_records?section=${encodeURIComponent(SECTION)}`, {
            headers: { 'Authorization': `Bearer ${accessToken}` }
        });

        if (res.status === 401) {
            // Try to refresh token
            const refreshed = await refreshAccessToken();
            if (refreshed) {
                // Retry the request with new token
                return fetchHistory();
            } else {
                // Refresh failed, logout
                logoutBtn.click();
            }
            return;
        }

        const data = await res.json();
        renderHistory(data);
    } catch (err) {
        console.error("History Fetch Error:", err);
        alert('Failed to fetch history.');
    }
}

function renderHistory(data) {
    historyBody.innerHTML = '';

    if (data.length === 0) {
        historyBody.innerHTML = '<tr><td colspan="5" class="text-center py-4 text-muted">No records found</td></tr>';
        return;
    }

    data.forEach(item => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td class="ps-4 text-secondary small">${item.date || '-'}</td>
            <td class="text-secondary small font-monospace">${item.time || '-'}</td>
            <td class="fw-bold text-dark">${item.username}</td>
            <td><span class="badge bg-light text-dark border">${item.subject}</span></td>
            <td><span class="badge bg-success bg-opacity-10 text-success border border-success">Present</span></td>
        `;
        historyBody.appendChild(row);
    });
}