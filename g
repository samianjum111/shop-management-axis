#!/usr/bin/env python3
"""
Patcher: Replace pending_payments mobile template with a premium UI/UX design.
"""

import os

TEMPLATE_PATH = "templates/mobile/pending_payments.html"

NEW_TEMPLATE = '''{% extends "mobile/base.html" %}
{% load static %}

{% block title %}Pending Payments | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<style>
  /* ===== Page Header ===== */
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }
  .page-header h1 {
    font-size: 1.25rem;
    font-weight: 700;
    color: var(--text);
    margin: 0;
    letter-spacing: -0.01em;
  }
  .back-link {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    color: var(--text-secondary);
    text-decoration: none;
    font-size: 0.85rem;
    font-weight: 500;
    padding: 0.3rem 0.6rem;
    border-radius: 2rem;
    border: 1px solid var(--border);
    transition: all 0.2s;
  }
  .back-link svg {
    width: 16px;
    height: 16px;
    stroke: currentColor;
    fill: none;
  }
  .back-link:hover {
    background: var(--surface-alt);
    border-color: var(--accent);
    color: var(--accent);
  }

  /* ===== Stats Row ===== */
  .stats-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.6rem;
    margin-bottom: 1.2rem;
  }
  .stat-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 0.8rem 0.5rem;
    text-align: center;
    box-shadow: var(--shadow);
  }
  .stat-card .number {
    font-size: 1.4rem;
    font-weight: 700;
    color: var(--text);
  }
  .stat-card .label {
    font-size: 0.6rem;
    text-transform: uppercase;
    color: var(--muted);
    letter-spacing: 0.04em;
    font-weight: 600;
  }
  .stat-card .label svg {
    display: inline-block;
    width: 14px;
    height: 14px;
    margin-right: 2px;
    vertical-align: middle;
    stroke: currentColor;
    fill: none;
  }

  /* ===== Worker Card ===== */
  .worker-payment-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 0.8rem 1rem;
    margin-bottom: 0.7rem;
    box-shadow: var(--shadow);
    cursor: pointer;
    transition: all 0.15s;
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }
  .worker-payment-card:active {
    transform: scale(0.98);
  }
  .worker-payment-card .top-row {
    display: flex;
    align-items: center;
    gap: 0.6rem;
  }
  .worker-payment-card .avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    font-size: 1rem;
    color: #fff;
    flex-shrink: 0;
  }
  .worker-payment-card .info {
    flex: 1;
    min-width: 0;
  }
  .worker-payment-card .info .name {
    font-weight: 600;
    font-size: 0.95rem;
    color: var(--text);
  }
  .worker-payment-card .info .due {
    font-size: 0.75rem;
    color: var(--muted);
  }
  .worker-payment-card .amount {
    font-weight: 700;
    font-size: 1.1rem;
    color: var(--accent);
    white-space: nowrap;
  }
  .worker-payment-card .bottom-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.7rem;
    color: var(--muted);
  }
  .worker-payment-card .badge-salary {
    background: var(--accent-light);
    color: var(--accent);
    padding: 0.1rem 0.5rem;
    border-radius: 1rem;
    font-weight: 600;
  }
  .worker-payment-card .arrow {
    color: var(--muted);
  }
  .worker-payment-card .arrow svg {
    width: 18px;
    height: 18px;
    stroke: currentColor;
    fill: none;
  }

  /* ===== Pagination ===== */
  .pagination-wrap {
    display: flex;
    justify-content: center;
    margin-top: 1rem;
    gap: 0.3rem;
    flex-wrap: wrap;
  }
  .pagination-wrap a, .pagination-wrap .current {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 2rem;
    padding: 0.2rem 0.5rem;
    border: 1px solid var(--border);
    border-radius: 0.3rem;
    text-decoration: none;
    color: var(--text);
    font-weight: 500;
    font-size: 0.85rem;
  }
  .pagination-wrap a:hover {
    background: var(--surface-alt);
    border-color: var(--accent);
    color: var(--accent);
  }
  .pagination-wrap .current {
    background: var(--accent);
    color: #fff;
    border-color: var(--accent);
  }
  .pagination-wrap .disabled {
    opacity: 0.4;
    pointer-events: none;
  }

  /* ===== Modal ===== */
  .modal-content {
    border-radius: var(--radius);
    border: 1px solid var(--border);
    background: var(--surface);
  }
  .modal-header {
    border-bottom: 1px solid var(--border);
    padding: 1rem 1.2rem;
  }
  .modal-header .modal-title {
    font-weight: 600;
    font-size: 1rem;
  }
  .modal-body {
    padding: 1.2rem;
    max-height: 70vh;
    overflow-y: auto;
  }
  .modal-footer {
    border-top: 1px solid var(--border);
    padding: 0.8rem 1.2rem;
  }
  .modal-body .detail-section {
    margin-bottom: 1rem;
  }
  .modal-body .detail-section h6 {
    font-weight: 600;
    font-size: 0.85rem;
    color: var(--text-secondary);
    margin-bottom: 0.3rem;
  }
  .modal-body .period-table {
    width: 100%;
    font-size: 0.75rem;
    border-collapse: collapse;
  }
  .modal-body .period-table th,
  .modal-body .period-table td {
    padding: 0.25rem 0.3rem;
    border-bottom: 1px solid var(--border);
    text-align: left;
  }
  .modal-body .period-table th {
    font-weight: 600;
    color: var(--text-secondary);
  }
  .modal-body .period-table .remaining {
    font-weight: 600;
    color: var(--accent);
  }
  .modal-body .attendance-badge {
    display: inline-block;
    padding: 0.05rem 0.4rem;
    border-radius: 1rem;
    font-size: 0.6rem;
    font-weight: 600;
  }
  .attendance-badge.present { background: #dcfce7; color: #166534; }
  .attendance-badge.absent { background: #fee2e2; color: #991b1b; }
  .modal-body .pay-form {
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid var(--border);
  }
  .modal-body .pay-form .form-row {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem;
    align-items: end;
  }
  .modal-body .pay-form .form-group {
    flex: 1;
    min-width: 80px;
  }
  .modal-body .pay-form .form-group label {
    display: block;
    font-size: 0.65rem;
    font-weight: 600;
    color: var(--text-secondary);
    margin-bottom: 0.1rem;
  }
  .modal-body .pay-form .form-group input {
    width: 100%;
    padding: 0.3rem 0.4rem;
    border: 1px solid var(--border);
    border-radius: 0.3rem;
    background: var(--bg);
    color: var(--text);
    font-size: 0.8rem;
  }
  .modal-body .pay-form .form-group input:focus {
    outline: none;
    border-color: var(--accent);
  }
  .modal-body .pay-form .btn-pay {
    background: var(--accent);
    color: #fff;
    border: none;
    border-radius: 0.3rem;
    padding: 0.3rem 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }
  .modal-body .pay-form .btn-pay:active {
    transform: scale(0.96);
  }

  /* ===== Empty State ===== */
  .empty-state {
    text-align: center;
    padding: 2.5rem 1rem;
    color: var(--muted);
    background: var(--surface);
    border-radius: var(--radius);
    border: 1px solid var(--border);
  }
  .empty-state svg {
    width: 48px;
    height: 48px;
    stroke: var(--muted);
    fill: none;
    margin-bottom: 0.5rem;
  }

  /* ===== Responsive ===== */
  @media (max-width: 400px) {
    .stats-row { gap: 0.4rem; }
    .stat-card .number { font-size: 1.2rem; }
    .worker-payment-card .avatar { width: 34px; height: 34px; font-size: 0.8rem; }
    .worker-payment-card .info .name { font-size: 0.85rem; }
    .worker-payment-card .amount { font-size: 1rem; }
  }
</style>
{% endblock %}

{% block body %}

<!-- Header -->
<div class="page-header">
  <h1>Pending Payments</h1>
  <a href="/portal/{{ tenant.schema_name }}/expenses/workers/" class="back-link">
    <svg viewBox="0 0 24 24"><path d="M19 12H5"/><path d="M12 19l-7-7 7-7"/></svg>
    Workers
  </a>
</div>

<!-- Stats -->
<div class="stats-row">
  <div class="stat-card">
    <div class="number">₹{{ total_pending_sum|floatformat:2 }}</div>
    <div class="label">
      <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>
      Total Pending
    </div>
  </div>
  <div class="stat-card">
    <div class="number">{{ worker_count }}</div>
    <div class="label">
      <svg viewBox="0 0 24 24"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
      Workers
    </div>
  </div>
</div>

<!-- Worker Cards -->
<div id="worker-list">
  {% for item in page_obj %}
  <div class="worker-payment-card" data-worker-id="{{ item.worker.id }}">
    <div class="top-row">
      <div class="avatar" style="background: {% cycle '#E67E22' '#2E86AB' '#A23B72' '#F18F01' '#6A4C93' '#3D5A80' %};">{{ item.worker.name|slice:":1"|upper }}</div>
      <div class="info">
        <div class="name">{{ item.worker.name }}</div>
        <div class="due">Due since {{ item.due_date|date:"d M Y" }}</div>
      </div>
      <div class="amount">₹{{ item.total_pending|floatformat:2 }}</div>
    </div>
    <div class="bottom-row">
      <span class="badge-salary">₹{{ item.worker.salary_amount }}/{{ item.worker.salary_type }}</span>
      <span class="arrow">
        <svg viewBox="0 0 24 24"><path d="M9 18l6-6-6-6"/></svg>
      </span>
    </div>
  </div>
  {% empty %}
  <div class="empty-state">
    <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2 4-2 4-2"/><line x1="9" y1="9" x2="9.01" y2="9"/><line x1="15" y1="9" x2="15.01" y2="9"/></svg>
    <p>All payments are up to date!</p>
  </div>
  {% endfor %}
</div>

<!-- Pagination -->
{% if page_obj.has_other_pages %}
<div class="pagination-wrap">
  <div class="step-links">
    {% if page_obj.has_previous %}
      <a href="?page=1">&laquo; first</a>
      <a href="?page={{ page_obj.previous_page_number }}">prev</a>
    {% else %}
      <span class="disabled">&laquo; first</span>
      <span class="disabled">prev</span>
    {% endif %}

    <span class="current">Page {{ page_obj.number }} of {{ page_obj.paginator.num_pages }}</span>

    {% if page_obj.has_next %}
      <a href="?page={{ page_obj.next_page_number }}">next</a>
      <a href="?page={{ page_obj.paginator.num_pages }}">last &raquo;</a>
    {% else %}
      <span class="disabled">next</span>
      <span class="disabled">last &raquo;</span>
    {% endif %}
  </div>
</div>
{% endif %}

<!-- Detail Modal -->
<div class="modal fade" id="detailModal" tabindex="-1" aria-hidden="true">
  <div class="modal-dialog modal-lg modal-dialog-centered">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title" id="detailModalLabel">Worker Details</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body" id="detailModalBody">
        <!-- filled by JavaScript -->
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
      </div>
    </div>
  </div>
</div>

{{ page_obj.object_list|json_script:"pendingData" }}

<script>
document.addEventListener('DOMContentLoaded', function() {
  const modalBody = document.getElementById('detailModalBody');
  const modal = new bootstrap.Modal(document.getElementById('detailModal'));

  // Parse JSON data
  const dataScript = document.getElementById('pendingData');
  if (!dataScript) return;
  let pendingItems = [];
  try {
    pendingItems = JSON.parse(dataScript.textContent);
  } catch(e) { console.error('Error parsing pending data', e); }

  // Build map by worker id
  const itemMap = {};
  pendingItems.forEach(item => {
    itemMap[item.worker.id] = item;
  });

  // Click handler for worker cards
  document.querySelectorAll('.worker-payment-card').forEach(card => {
    card.addEventListener('click', function() {
      const workerId = parseInt(this.dataset.workerId);
      const item = itemMap[workerId];
      if (!item) {
        modalBody.innerHTML = '<div class="alert alert-danger">Data not found.</div>';
        modal.show();
        return;
      }

      // Build modal content
      let html = `
        <div class="row">
          <div class="col-md-6">
            <div class="detail-section">
              <h6>Contact</h6>
              <p><strong>Phone:</strong> ${item.worker.phone || '-'}</p>
              <p><strong>Address:</strong> ${item.worker.address || '-'}</p>
              <p><strong>Joining:</strong> ${item.worker.joining_date}</p>
            </div>
          </div>
          <div class="col-md-6">
            <div class="detail-section">
              <h6>Salary</h6>
              <p><strong>Amount:</strong> ₹${item.worker.salary_amount}/${item.worker.salary_type}</p>
              <p><strong>Total Paid:</strong> ₹${parseFloat(item.total_paid).toFixed(2)}</p>
              <p><strong>Pending:</strong> ₹${parseFloat(item.total_pending).toFixed(2)}</p>
            </div>
          </div>
        </div>

        <div class="detail-section">
          <h6>Pending Periods (oldest first)</h6>
          <div class="table-responsive">
            <table class="period-table">
              <thead><tr><th>Period</th><th>Due</th><th>Paid</th><th>Remaining</th></tr></thead>
              <tbody>
                ${item.pending_periods.map(p => `
                  <tr>
                    <td>${p.start} – ${p.end}</td>
                    <td>₹${parseFloat(p.due).toFixed(2)}</td>
                    <td>₹${parseFloat(p.paid).toFixed(2)}</td>
                    <td class="remaining">₹${parseFloat(p.remaining).toFixed(2)}</td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        </div>

        <div class="row">
          <div class="col-md-6">
            <div class="detail-section">
              <h6>Attendance (last 30 days)</h6>
              <div class="d-flex flex-wrap gap-1">
                ${item.attendance_history.map(a => `
                  <span class="attendance-badge ${a.status}">${a.date}</span>
                `).join('')}
              </div>
            </div>
          </div>
          <div class="col-md-6">
            <div class="detail-section">
              <h6>Payment History</h6>
              <div class="table-responsive">
                <table class="period-table">
                  <thead><tr><th>Date</th><th>Amount</th></tr></thead>
                  <tbody>
                    ${item.payment_history.map(p => `
                      <tr>
                        <td>${p.payment_date}</td>
                        <td>₹${parseFloat(p.amount).toFixed(2)}</td>
                      </tr>
                    `).join('')}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>

        <div class="pay-form">
          <form method="post" action="/portal/{{ tenant.schema_name }}/expenses/workers/pay/${item.worker.id}/">
            {% csrf_token %}
            <input type="hidden" name="next" value="{{ request.path }}">
            <div class="form-row">
              <div class="form-group">
                <label>Amount (₹)</label>
                <input type="number" name="amount" step="0.01" required>
              </div>
              <div class="form-group">
                <label>Payment Date</label>
                <input type="date" name="payment_date" value="{{ today|date:'Y-m-d' }}" required>
              </div>
              <div class="form-group">
                <label>Period Start</label>
                <input type="date" name="period_start" value="${item.pending_periods.length ? item.pending_periods[0].start : ''}">
              </div>
              <div class="form-group">
                <label>Period End</label>
                <input type="date" name="period_end" value="${item.pending_periods.length ? item.pending_periods[0].end : ''}">
              </div>
              <div class="form-group" style="flex:0 0 auto;">
                <button type="submit" class="btn-pay">Pay Now</button>
              </div>
            </div>
          </form>
        </div>
      `;
      modalBody.innerHTML = html;
      modal.show();
    });
  });
});
</script>

{% endblock %}
'''

def patch_template():
    if not os.path.isfile(TEMPLATE_PATH):
        print(f"❌ Template file not found: {TEMPLATE_PATH}")
        return False

    with open(TEMPLATE_PATH, 'w', encoding='utf-8') as f:
        f.write(NEW_TEMPLATE)

    print(f"✅ Replaced {TEMPLATE_PATH} with premium UI design.")
    return True

def main():
    print("🔧 Applying premium UI to pending payments page...")
    if patch_template():
        print("\n🎉 Patch applied successfully!")
        print("👉 Restart your Django server to see the new design.")
    else:
        print("\n❌ Patch failed. Please check the file path.")

if __name__ == "__main__":
    main()
