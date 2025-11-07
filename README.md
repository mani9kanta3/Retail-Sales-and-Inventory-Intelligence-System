# 🛒 Retail Sales & Inventory Intelligence System

This project delivers a complete **Retail Sales & Inventory Intelligence System** that helps retail businesses analyze **sales performance, product demand, staff contribution, and stock efficiency** across multiple store locations.

By integrating **Excel**, **SQL**, and **Power BI**, the project transforms raw operational data into meaningful business insights that support **data-driven decision-making**.

---

## 📊 Project Architecture Overview

| Layer | Tool Used | Purpose |
|------|-----------|---------|
| Data Source | Excel | Initial review & validation |
| Data Modeling & Processing | SQL (PostgreSQL) | Schema creation, constraints, analytical views |
| Data Visualization | Power BI | Interactive dashboard for stakeholders |

---

## 🎯 Key Business Objectives

- Analyze **store-wise and region-wise sales performance**
- Identify **top-performing product categories and brands**
- Understand **customer purchasing patterns and order frequency**
- Measure **staff productivity and performance impact**
- Monitor **inventory efficiency & stock-to-sales balance**
- Evaluate **order fulfillment delays and on-time delivery performance**

---

## 🗂 Dataset Schema Overview

The project operates on two data domains:

| Domain | Description |
|--------|-------------|
| **Sales** | Customer, orders, stores, and staff information |
| **Production** | Product, brand, category, and stock availability |

Schemas and table relationships were created and enforced using the SQL script.  
🔗 **SQL File:** `Retail_Analysis.sql`  

---

## 🧩 Core SQL Deliverables

The SQL layer includes:

- **Primary & Foreign Key Constraints**
- **Indexes for Query Optimization**
- **Reusable Analytical Views**, such as:
  - `vw_store_sales`
  - `vw_product_sales`
  - `vw_region_sales`
  - `vw_staff_performance`
  - `vw_order_fulfillment_summary`
  - `vw_inventory_store_efficiency`

These views standardize KPI logic and feed directly into Power BI visuals.

---

## 📈 Power BI Dashboard Highlights

The dashboard provides:

| Insight Area | Visual Used |
|-------------|-------------|
| Sales Performance by Store | Bar Chart |
| Top Products & Brands | Ranked Revenue Matrix |
| Category Demand Distribution | Category-wise Units Sold Chart |
| Customer Base & Repeat Frequency | KPI + Multi-level breakdown |
| Staff Efficiency | Performance vs Revenue Contribution Chart |
| Order Fulfillment Status | Donut / Status Segmentation Chart |

🔗 **Power BI File:** `Retail_Analytical_Performance.pbix`

---

## 🔍 Business Insights Extracted

- Certain **stores outperform others** consistently in both revenue and AOV.
- **Mountain Bikes & Cruisers** categories show **highest demand**.
- A few **staff members contribute significantly** to total order revenue.
- Inventory imbalance across stores suggests opportunities for **stock optimization**.
- **On-time delivery rate is high**, but some orders show preventable delays.

---

## 📄 Full Project Documentation

A complete walkthrough — including objectives, data model diagrams, SQL workflow, dashboard explanation, and insights — is available here:

📘 **Documentation PDF: `Retail_Sales_Insights_Documentation.pdf`**  

---

## 🚀 How to Run the Project Locally

1. Import cleaned datasets into your SQL environment.
2. Execute SQL script to create schemas, tables, constraints, and views.
3. Open Power BI and connect to your SQL database.
4. Load the analytical views into Power BI.
5. Refresh the data model and publish / use the dashboard.

---

## 🧠 Skills Demonstrated

- Data Cleaning & Validation (Excel)
- Database Design & Schema Modeling (SQL)
- Analytical Query Writing (Window Functions, Joins, Aggregations)
- Data Visualization & Storytelling (Power BI)
- Business Insight & Decision Support

---

## 🤝 Contact

**Author:** *Manikanta Pudi*

**LinkedIn Profile:** *https://www.linkedin.com/in/manikanta3/* 

**Portfolio:** *https://manikantapudi.com/*

---
