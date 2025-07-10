## 📄 About the Dataset
The dataset was sourced from **Kaggle** and originally contained approximately **1 million** records of real estate transactions.

- For github's storage restrictions, I uploaded a sample of the data in the `\data` field. 

> Download the dataset:
![Link of the dataset](https://drive.google.com/open?id=16NAgq64JgW7JhgnNT0FSgh0hO-6cIdMZ&usp=drive_fs)

During initial exploration, several columns were found to be heavily skewed or sparsely populated:

- Columns like **Geo Location**, **OPM Remarks**, and others had over 70% missing values.

- One column had nearly **98%** nulls, making it unfit for meaningful analysis.

- Some columns such as property_type and residential_type had around 30% of null. Had to drop those nulls because it was hard to impute and also imputation may've caused data distortion.

To ensure data integrity and maintain a clean, analysis-ready structure, all such columns were dropped.


## 🧹 Data Cleaning Process

The dataset underwent a comprehensive cleaning process using Python (Pandas), with special attention given to preserving business logic and preparing the data for warehousing.

Key cleaning steps included:

- 1. Replaced the existing `serial_id` (not consistently unique) with a custom surrogate key `fact_id` in the `fact_property` table to support star schema best practices.

- 2. Handled missing values:
  - Columns like `date_recorded` and `address` had <1% nulls — imputed using `mode()` instead of dropping rows.

- 3. Created a new derived column:
  - `assessed_vs_sales_pct` – to calculate the percentage difference between assessed value and sale price.

- 4. Dropped low-quality records:
  - Years(date recorded) with fewer than 10 property sales were removed due to potential data entry issues.

- 5. Normalized property classification:
  - The dataset had overlapping values in `property_type` and `residential_type`.
  - Cleaned and retained `residential_type` only for rows where `property_type = 'residential'`.
  - Flagged non-residential entries in `residential_type` as `"Non Residential"` to maintain completeness.

- 6. Outlier Detection:
  - Used the **IQR (Interquartile Range)** method to detect spread in `assessed_value`, `sale_amount`, and `town`.
  - Instead of dropping outliers:
    - Flagged unusually low or high values in `assessed_value` and `sale_amount` (e.g., < ₹1,000 or > ₹1,00,00,000).
    - Flagged outlier towns as `"town_outlier"` to retain rare but valid real estate behavior.

> ** Real estate data is often unpredictable due to market variability — so records were **flagged** instead of removed to retain analytical value.

---

###  Post-Cleaning Result

- Reduced dataset size from **~1 million** to **~600,000** high-quality, cleaned records.
- Final dataset is structured, statistically profiled, and ready for warehouse modeling and proper analysis.
- Used **SQLAlchemy** with Pandas' `to_sql()` method to load the cleaned data into a SQL database as part of the data warehouse pipeline.


## ⚒️ Data Warehouse Creation

I chose **star schema** for schema design in SQL for structured, scalable analysis and future BI tools integration.

The final warehouse consists of:

- `fact_property` — central fact table containing transactional-level property sales data
- `dim_property` — descriptive attributes of the property (e.g., property_type, residential_type)
- `dim_location` — location-based details (e.g., town, address)
- `dim_date` — custom-built date dimension derived from the `date_recorded` column, used to enable time-based slicing in tools like Power BI
- `Indexes` on frequently used joining columns(e.g. property_id) and some descriptive columns(e.g. property_type) to improve performance while querying data


###  Why Star Schema?

A **star schema** is one of the most effective data modeling techniques in data warehousing for the following reasons:

- Simplifies complex queries for reporting and dashboarding
- Optimizes performance through de-normalized dimension tables
- Easy to join using surrogate keys (fact-to-dimension)
- Well-supported by BI tools like Power BI, Tableau, and Looker

Below is a diagram of the data warehouse:

![Star schema diagram](pngs/Real%20Estate%20diagram.png)

---

##  Power BI Dashboard

Even though this was primarily a data warehouse and ETL-focused project, I performed some analysis in **Power BI** to demonstrate the usefulness of the warehouse design for downstream reporting.



![COVID Analysis](pngs/Covid%20analysis.png)

> This time-based analysis focuses on the period from **2018 to 2023**, capturing pre-COVID, during-COVID, and post-COVID patterns in the real estate market.


### Covid analysis Key Insights

1. A total of **$113B** in property sales occurred between 2018–2023, covering **44.84%** of the full dataset's timespan — highlighting the significant economic impact COVID had on real estate market behavior.
Also, 

2. **Residential** properties saw the highest average sale amount (approx. $450,000), followed by **Single Family** homes (approx. $380,000). This may reflect financial stress among property holders, as individuals potentially liquidated high-value assets during the COVID era.

3. All four quarters in both **2020** and **2021** had the **highest count of property sales** across all years — suggesting a spike in property transactions during COVID. These two years also emerged as **outliers** in the IQR distribution, indicating a burst-like activity in the housing market.

4. From the pie chart titled *“Total Sales Amount (2018–2023)”*, the majority of sales (~**42.52%**) occurred **during COVID**. Sales declined to a normal level in the **post-COVID** period, contributing **31.44%** of the total.

5. The ribbon chart showing *Assessed Value vs. Sale Amount* distribution revealed a highlighting shifts between **2019 and 2020**, where:
   - Sale amounts increased by **50.24%**
   - Assessed values increased by **44.66%**
   Showing a quick shift of the market, creating more unpredictability of the market at that time.

6. Over the 6-year span, **Q2–Q3** consistently showed the most growth in sales volume and pricing, while **Q4** (winter period) often experienced a decline following **(Q3)**, Showing how Q2 and Q3 offered stable growth in the real estate market for individuals.



> To view the full interactive dashboard, please download the Power BI file:  
[Download PBIX Report](dashboards/real%20estate%20dashboard.pbix)


---

## 🛠️ Tools Used

- **Python (Pandas)** – for data cleaning and transformation  
- **SQL (via SQLAlchemy)** – for loading and modeling data into a warehouse  
- **Power BI** – for analysis and dashboarding

---

## 👨‍💻 Author

Created by [Arit gon].  
I’ll continue updating the dataset and dashboards over time to refine the analysis further.

*Feedback, suggestions, or collaborations are always welcome!*
