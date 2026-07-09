#!/usr/bin/env python3
"""
Upgrades the categories table to clearly distinguish Grinding vs Selling.
Adds distinct colors, icons, and a premium look.
"""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
TEMPLATES_DIR = PROJECT_ROOT / 'reports' / 'templates'

DESKTOP_CATEGORIES_DISTINCT = '''{% extends "desktop/base.html" %}
{% load static %}
{% block title %}Category Performance | {{ tenant.name }}{% endblock %}
{% block extra_head %}
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
  /* ===== Premium Design – Dark Accent Theme ===== */
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
    flex-wrap: wrap;
    gap: 1rem;
  }
  .page-header h2 {
    font-size: 2.2rem;
    font-weight: 700;
    color: var(--text);
    margin: 0;
    letter-spacing: -0.02em;
  }
  .page-header h2 i {
    color: var(--accent);
    margin-right: 0.5rem;
  }
  .page-header .subtitle {
    color: var(--muted);
    font-size: 0.95rem;
    font-weight: 400;
  }

  /* ===== KPI Grid ===== */
  .kpi-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1.2rem;
    margin-bottom: 2.5rem;
  }
  .kpi-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 1.4rem 1rem;
    text-align: center;
    box-shadow: var(--shadow);
    transition: all 0.3s ease;
    position: relative;
    overflow: hidden;
  }
  .kpi-card::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 4px;
    background: linear-gradient(90deg, var(--accent), var(--accent-hover));
    opacity: 0;
    transition: opacity 0.3s ease;
  }
  .kpi-card:hover {
    transform: translateY(-6px);
    box-shadow: 0 12px 40px rgba(0,0,0,0.08);
    border-color: var(--accent);
  }
  .kpi-card:hover::before {
    opacity: 1;
  }
  .kpi-card .icon {
    font-size: 1.8rem;
    color: var(--accent);
    display: block;
    margin-bottom: 0.3rem;
  }
  .kpi-card .number {
    font-size: 2.2rem;
    font-weight: 700;
    color: var(--text);
    line-height: 1.2;
  }
  .kpi-card .label {
    font-size: 0.7rem;
    text-transform: uppercase;
    color: var(--muted);
    font-weight: 600;
    letter-spacing: 0.06em;
    margin-top: 0.1rem;
  }

  /* ===== Filter Bar ===== */
  .filter-bar {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 0.8rem 1.5rem;
    margin-bottom: 2rem;
    box-shadow: var(--shadow);
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 1rem;
  }
  .filter-bar .search-box {
    flex: 2;
    min-width: 220px;
    display: flex;
    align-items: center;
    gap: 0.6rem;
    background: var(--bg);
    border-radius: 40px;
    padding: 0.2rem 0.8rem;
    border: 1px solid var(--border);
    transition: border-color 0.2s, box-shadow 0.2s;
  }
  .filter-bar .search-box:focus-within {
    border-color: var(--accent);
    box-shadow: 0 0 0 4px rgba(26,42,58,0.08);
  }
  .filter-bar .search-box input {
    border: none;
    background: transparent;
    padding: 0.5rem 0;
    font-size: 0.95rem;
    width: 100%;
    outline: none;
    color: var(--text);
  }
  .filter-bar .search-box i {
    color: var(--muted);
    font-size: 1.1rem;
  }
  .filter-bar .sort-options {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.6rem;
  }
  .filter-bar .sort-options select {
    padding: 0.4rem 1rem;
    border-radius: 40px;
    border: 1px solid var(--border);
    background: var(--surface);
    color: var(--text);
    font-size: 0.85rem;
    outline: none;
    cursor: pointer;
    transition: border-color 0.2s;
    appearance: none;
    -webkit-appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%236b7280' d='M6 8L1 3h10z'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 10px center;
    padding-right: 2rem;
  }
  .filter-bar .sort-options select:focus {
    border-color: var(--accent);
  }
  .filter-bar .sort-options .btn-sort {
    background: var(--accent);
    color: #fff;
    border: none;
    border-radius: 40px;
    padding: 0.4rem 1.4rem;
    font-weight: 600;
    font-size: 0.85rem;
    cursor: pointer;
    transition: transform 0.2s, box-shadow 0.2s;
    box-shadow: 0 4px 12px rgba(26,42,58,0.25);
  }
  .filter-bar .sort-options .btn-sort:hover {
    background: var(--accent-hover);
    transform: translateY(-2px);
    box-shadow: 0 8px 24px rgba(26,42,58,0.35);
  }
  .filter-bar .sort-options .btn-clear {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 40px;
    padding: 0.4rem 1.2rem;
    font-size: 0.85rem;
    color: var(--text-secondary);
    text-decoration: none;
    transition: 0.2s;
  }
  .filter-bar .sort-options .btn-clear:hover {
    background: var(--surface-alt);
    border-color: var(--accent);
    color: var(--accent);
  }

  /* ===== Chart Container with Toggle (Visible) ===== */
  .chart-wrapper {
    background: var(--surface);
    border-radius: var(--radius);
    border: 1px solid var(--border);
    box-shadow: var(--shadow);
    margin-bottom: 2.5rem;
    overflow: hidden;
    transition: all 0.3s ease;
  }
  .chart-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.6rem 1.2rem;
    cursor: pointer;
    user-select: none;
    transition: background 0.2s;
  }
  .chart-header:hover {
    background: var(--bg);
  }
  .chart-header .title {
    font-weight: 600;
    font-size: 0.9rem;
    color: var(--text-secondary);
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .chart-header .title i {
    color: var(--accent);
  }
  .chart-header .toggle-icon {
    font-size: 1.1rem;
    color: var(--muted);
    transition: transform 0.3s ease;
  }
  .chart-header .toggle-icon.expanded {
    transform: rotate(180deg);
  }
  .chart-body {
    padding: 0.5rem 1.2rem 1rem;
    transition: all 0.3s ease;
    overflow: hidden;
    max-height: 350px;
    min-height: 200px;
  }
  .chart-body.collapsed {
    max-height: 0;
    padding: 0 1.2rem;
    min-height: 0;
    opacity: 0;
  }
  .chart-body canvas {
    width: 100% !important;
    height: auto !important;
    max-height: 300px;
    min-height: 180px;
  }

  /* ===== Table with Distinct Type Styling ===== */
  .table-wrap {
    background: var(--surface);
    border-radius: var(--radius);
    border: 1px solid var(--border);
    overflow: hidden;
    box-shadow: var(--shadow);
  }
  .table-wrap table {
    width: 100%;
    border-collapse: collapse;
  }
  .table-wrap th {
    background: var(--surface-alt);
    color: var(--text-secondary);
    font-weight: 600;
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    padding: 0.9rem 1rem;
    text-align: left;
  }
  .table-wrap td {
    padding: 0.8rem 1rem;
    border-bottom: 1px solid var(--border);
    vertical-align: middle;
    color: var(--text);
  }
  .table-wrap tr:last-child td {
    border-bottom: none;
  }
  .table-wrap tr:hover td {
    background: var(--bg);
  }

  /* ---- Type-specific row styling ---- */
  .table-wrap tr.type-grinding td {
    border-left: 4px solid #3b82f6;
  }
  .table-wrap tr.type-grinding:hover td {
    background: #eff6ff;
  }
  .table-wrap tr.type-selling td {
    border-left: 4px solid #22c55e;
  }
  .table-wrap tr.type-selling:hover td {
    background: #f0fdf4;
  }

  /* ---- Type Badge with Icon ---- */
  .type-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.2rem 0.8rem 0.2rem 0.6rem;
    border-radius: 30px;
    font-weight: 600;
    font-size: 0.75rem;
    text-transform: capitalize;
  }
  .type-badge.grinding {
    background: #dbeafe;
    color: #1e40af;
  }
  .type-badge.grinding i {
    color: #1e40af;
  }
  .type-badge.selling {
    background: #dcfce7;
    color: #166534;
  }
  .type-badge.selling i {
    color: #166534;
  }

  .table-wrap .amount {
    font-weight: 600;
  }
  .table-wrap .profit-positive {
    color: #16a34a;
  }
  .table-wrap .profit-negative {
    color: #dc2626;
  }
  .table-wrap .action-link {
    color: var(--accent);
    text-decoration: none;
    font-weight: 600;
    transition: color 0.2s;
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
  }
  .table-wrap .action-link:hover {
    color: var(--accent-hover);
    text-decoration: underline;
  }
  .table-wrap .action-link i {
    font-size: 0.7rem;
  }

  .empty-state {
    text-align: center;
    padding: 3rem;
    color: var(--muted);
  }
  .empty-state i {
    font-size: 3rem;
    display: block;
    margin-bottom: 0.5rem;
    color: var(--border);
  }

  /* Responsive */
  @media (max-width: 992px) {
    .kpi-grid { grid-template-columns: repeat(2, 1fr); }
  }
  @media (max-width: 768px) {
    .page-header { flex-direction: column; align-items: flex-start; }
    .filter-bar { flex-direction: column; align-items: stretch; }
    .filter-bar .search-box { min-width: 100%; }
    .filter-bar .sort-options { justify-content: space-between; }
    .kpi-grid { grid-template-columns: 1fr 1fr; gap: 0.8rem; }
    .kpi-card { padding: 1rem 0.5rem; }
    .kpi-card .number { font-size: 1.6rem; }
    .table-wrap { overflow-x: auto; }
    .chart-header .title { font-size: 0.85rem; }
    .chart-body { max-height: 280px; min-height: 160px; }
    .chart-body canvas { max-height: 250px; min-height: 140px; }
  }
  @media (max-width: 576px) {
    .kpi-grid { grid-template-columns: 1fr 1fr; }
    .filter-bar .sort-options select { flex: 1; min-width: 80px; }
    .chart-body { max-height: 240px; min-height: 130px; }
    .chart-body canvas { max-height: 200px; min-height: 110px; }
    .type-badge { font-size: 0.65rem; padding: 0.15rem 0.6rem 0.15rem 0.4rem; }
  }
</style>
{% endblock %}
{% block content %}
<div class="page-header">
  <div>
    <h2><i class="fas fa-tags"></i> Category Performance</h2>
    <div class="subtitle">Track revenue and order metrics across all categories</div>
  </div>
</div>

<!-- KPI Grid -->
<div class="kpi-grid">
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-layer-group"></i></span>
    <div class="number">{{ total_categories }}</div>
    <div class="label">Total Categories</div>
  </div>
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-coins"></i></span>
    <div class="number">₹{{ total_revenue|floatformat:0 }}</div>
    <div class="label">Total Revenue</div>
  </div>
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-clipboard-list"></i></span>
    <div class="number">{{ total_orders }}</div>
    <div class="label">Total Orders</div>
  </div>
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-chart-line"></i></span>
    <div class="number">₹{{ total_profit|floatformat:0 }}</div>
    <div class="label">Total Profit</div>
  </div>
  <div class="kpi-card">
    <span class="icon"><i class="fas fa-calculator"></i></span>
    <div class="number">₹{{ avg_revenue|floatformat:2 }}</div>
    <div class="label">Avg Revenue / Category</div>
  </div>
</div>

<!-- Filter Bar -->
<div class="filter-bar">
  <form method="get" class="search-box">
    <i class="fas fa-search"></i>
    <input type="text" name="search" placeholder="Search categories..." value="{{ search }}">
    <button type="submit" style="display:none;"></button>
  </form>
  <div class="sort-options">
    <select name="sort">
      <option value="name" {% if sort == 'name' %}selected{% endif %}>Sort by Name</option>
      <option value="revenue" {% if sort == 'revenue' %}selected{% endif %}>Sort by Revenue</option>
      <option value="orders" {% if sort == 'orders' %}selected{% endif %}>Sort by Orders</option>
      <option value="profit" {% if sort == 'profit' %}selected{% endif %}>Sort by Profit</option>
    </select>
    <select name="order">
      <option value="asc" {% if order == 'asc' %}selected{% endif %}>Ascending</option>
      <option value="desc" {% if order == 'desc' %}selected{% endif %}>Descending</option>
    </select>
    <button type="submit" class="btn-sort"><i class="fas fa-arrow-right"></i> Apply</button>
    <a href="?" class="btn-clear"><i class="fas fa-times"></i> Clear</a>
  </div>
</div>

<!-- Chart with Toggle (Visible when expanded) -->
<div class="chart-wrapper">
  <div class="chart-header" id="chartToggleHeader">
    <span class="title"><i class="fas fa-chart-bar"></i> Revenue Chart</span>
    <span class="toggle-icon" id="chartToggleIcon"><i class="fas fa-chevron-down"></i></span>
  </div>
  <div class="chart-body collapsed" id="chartBody">
    <canvas id="categoryChart" height="250"></canvas>
  </div>
</div>

<!-- Table with Distinct Type Styling -->
<div class="table-wrap">
  <div class="table-responsive">
    <table>
      <thead>
        <tr>
          <th>Category</th>
          <th>Type</th>
          <th>Orders</th>
          <th>Quantity</th>
          <th>Revenue</th>
          <th>Profit</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
        {% for cat in categories %}
        <tr class="type-{{ cat.type }}">
          <td><strong>{{ cat.name }}</strong></td>
          <td>
            <span class="type-badge {{ cat.type }}">
              <i class="fas {% if cat.type == 'grinding' %}fa-cogs{% else %}fa-shopping-cart{% endif %}"></i>
              {{ cat.type }}
            </span>
          </td>
          <td>{{ cat.total_orders }}</td>
          <td>{{ cat.total_quantity|floatformat:1 }} {{ cat.quantity_unit }}</td>
          <td class="amount">₹{{ cat.total_revenue|floatformat:2 }}</td>
          <td class="amount {% if cat.total_profit and cat.total_profit >= 0 %}profit-positive{% elif cat.total_profit %}profit-negative{% endif %}">
            {% if cat.total_profit is not None %}₹{{ cat.total_profit|floatformat:2 }}{% else %}—{% endif %}
          </td>
          <td>
            <a href="{% url cat.url_name schema_name=tenant.schema_name category_id=cat.id %}" class="action-link">
              Details <i class="fas fa-arrow-right"></i>
            </a>
          </td>
        </tr>
        {% empty %}
        <tr><td colspan="7"><div class="empty-state"><i class="fas fa-inbox"></i>No categories found.</div></td></tr>
        {% endfor %}
      </tbody>
    </table>
  </div>
</div>

<script>
  document.addEventListener('DOMContentLoaded', function() {
    // Chart initialization
    const ctx = document.getElementById('categoryChart').getContext('2d');
    const chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: {{ chart_labels|safe }},
        datasets: [{
          label: 'Revenue per Category (₹)',
          data: {{ chart_data }},
          backgroundColor: 'rgba(26,42,58,0.7)',
          borderColor: 'var(--accent)',
          borderWidth: 2,
          borderRadius: 6,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: true, labels: { color: '#6b7280', font: { size: 12 } } }
        },
        scales: {
          y: { beginAtZero: true, grid: { color: 'rgba(0,0,0,0.04)' } },
          x: { grid: { display: false } }
        }
      }
    });

    // Toggle functionality
    const header = document.getElementById('chartToggleHeader');
    const body = document.getElementById('chartBody');
    const icon = document.getElementById('chartToggleIcon');

    // Start collapsed (default)
    body.classList.add('collapsed');
    icon.innerHTML = '<i class="fas fa-chevron-down"></i>';

    header.addEventListener('click', function() {
      const isCollapsed = body.classList.contains('collapsed');
      if (isCollapsed) {
        body.classList.remove('collapsed');
        icon.innerHTML = '<i class="fas fa-chevron-up"></i>';
        setTimeout(() => chart.resize(), 100);
      } else {
        body.classList.add('collapsed');
        icon.innerHTML = '<i class="fas fa-chevron-down"></i>';
      }
    });
  });
</script>
{% endblock %}
'''

def main():
    print("🎨 Upgrading categories table with distinct type styling...")
    desktop_path = TEMPLATES_DIR / 'desktop' / 'reports_categories.html'
    desktop_path.parent.mkdir(parents=True, exist_ok=True)
    desktop_path.write_text(DESKTOP_CATEGORIES_DISTINCT)
    print(f"✅ {desktop_path}")
    print("\n✅ Table now clearly distinguishes Grinding vs Selling:")
    print("   - Blue left border + light blue hover for Grinding")
    print("   - Green left border + light green hover for Selling")
    print("   - Icons (⚙️ for Grinding, 🛒 for Selling) inside badges")
    print("📌 Restart your server to see the changes.")
    print("   python3 manage.py runserver")

if __name__ == "__main__":
    main()
