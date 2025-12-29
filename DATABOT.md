# YNAB Budget Analysis Project

## Project Overview
This project analyzes YNAB (You Need A Budget) export data to understand spending patterns and trends from March 2024 to February 2025.

## Data Files and Loading

### File Locations
All data files are stored in the `.cache/` directory:
- `transactions.parquet` - Main transaction data (2,407 records)
- `categories.parquet` - Budget categories (84 categories)
- `groups.parquet` - Category groups (15 groups)

### Loading Code
```python
import polars as pl
from plotnine import *

# Load YNAB data
transactions = pl.read_parquet(".cache/transactions.parquet")
categories = pl.read_parquet(".cache/categories.parquet")
groups = pl.read_parquet(".cache/groups.parquet")
```

## Data Structure

### Transactions DataFrame (2,407 × 27)
Key columns:
- `id` - Transaction ID
- `date` - Transaction date
- `amount` - Transaction amount (negative = expense, positive = income)
- `memo` - Transaction memo
- `account_name` - Account name
- `payee_name` - Payee name
- `category_name` - Budget category
- `group_name` - Category group

### Categories DataFrame (84 × 3)
- `category_id` - Category ID
- `category_name` - Category name
- `group_id` - Associated group ID

### Groups DataFrame (15 × 2)
- `group_id` - Group ID
- `group_name` - Group name (Daily, Adulting, Transportation, Savings, etc.)

## Data Cleaning Process

### Problem Identified
Raw YNAB data contains system transactions that skew analysis:
- Starting Balance entries from initial setup
- Reconciliation Balance Adjustments for investment accounts
- Manual Balance Adjustments
- Large internal transfers
- Closed account transactions

### Cleaning Code
```python
filtered_transactions = (
    transactions
    .filter(
        # Remove starting balances and reconciliation adjustments
        ~pl.col("payee_name").str.contains("Starting Balance", literal=True),
        ~pl.col("payee_name").str.contains("Reconciliation Balance", literal=True),
        ~pl.col("payee_name").str.contains("Manual Balance Adjustment", literal=True),
        
        # Remove very large amounts that are likely transfers or system entries
        pl.col("amount").abs() < 10000,
        
        # Remove internal transfers (uncategorized large amounts)
        ~((pl.col("category_name") == "Uncategorized") & (pl.col("amount").abs() > 5000)),
        
        # Remove closed account transactions
        ~pl.col("memo").str.contains("Closed Account", literal=True),
    )
)
```

### Cleaning Results
- **Original transactions**: 2,407
- **Filtered transactions**: 530
- **Removed**: 1,877 outlier/system transactions
- **Final amount range**: -$4,200 to $6,800

## Analysis Results

### Monthly Spending Trends (Cleaned Data)
```python
cleaned_monthly_trends = (
    filtered_transactions
    .with_columns(
        year_month=pl.col("date").dt.strftime("%Y-%m"),
        income=pl.when(pl.col("amount") > 0).then(pl.col("amount")).otherwise(0),
        expenses=pl.when(pl.col("amount") < 0).then(pl.col("amount").abs()).otherwise(0)
    )
    .group_by("year_month")
    .agg(
        pl.col("date").min().alias("month_date"),
        pl.col("income").sum().alias("total_income"),
        pl.col("expenses").sum().alias("total_expenses"),
        pl.col("amount").sum().alias("net_flow"),
        pl.len().alias("transaction_count")
    )
    .sort("month_date")
)
```

### Key Findings
- **Average Monthly Expenses**: $5,993
- **Average Monthly Income**: $3,636 (flowing through YNAB)
- **Average Monthly Deficit**: $2,357
- **Highest Spending Month**: November 2024 ($11,411)
- **Lowest Spending Month**: April 2024 ($1,760)
- **Positive Cash Flow Months**: 3 out of 12 (April, June, August 2024)

### Spending Patterns
- **Seasonal Trend**: Higher expenses in fall/winter months
- **Transaction Volume**: 22-68 transactions per month
- **Expense Range**: $1,760 - $11,411 per month
- **Income Variability**: Suggests main salary flows to investment accounts first

## Key DataFrames Available
- `transactions` - Original raw data
- `filtered_transactions` - Cleaned transaction data (530 records)
- `cleaned_monthly_trends` - Monthly spending summaries
- `categories` - Category reference data
- `groups` - Group reference data

## Visualization Code
```python
# Monthly income vs expenses visualization
p_cleaned = (
    ggplot(cleaned_monthly_viz, aes(x="month", y="amount", color="type"))
    + geom_line(size=1.2)
    + geom_point(size=3)
    + scale_y_continuous(labels=lambda x: [f"${v/1000:.1f}K" for v in x])
    + scale_x_date(date_breaks="1 month", date_labels="%b %Y")
    + labs(
        title="Monthly Income vs Expenses Over Time (Cleaned Data)",
        subtitle="Outliers and system transactions removed",
        x="Month",
        y="Amount ($)",
        color="Type"
    )
    + theme(axis_text_x=element_text(rotation=45, hjust=1))
)
```

## Report Generation
- Full analysis documented in `ynab_spending_analysis.qmd`
- Reproducible Quarto report with all code and findings
- Ready for rendering to HTML format

## Next Steps for Analysis
1. **Category-Level Analysis**: Break down spending by YNAB categories
2. **Seasonal Analysis**: Investigate fall/winter spending increases
3. **Transaction Pattern Analysis**: Examine spending frequency and amounts
4. **Group-Level Spending**: Analyze spending by category groups (Daily, Transportation, etc.)
5. **Specific Period Deep Dive**: Examine high-spending months like November 2024

## Important Notes
- Data represents actual spending patterns tracked through YNAB
- Most months show deficit because main income likely flows to investment accounts first
- Cleaning process removes investment transfers and system noise
- Analysis reflects day-to-day spending behavior, not total financial picture