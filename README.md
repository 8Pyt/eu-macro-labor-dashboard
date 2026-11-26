# eu-macro-labor-dashboard

# EU Macroeconomic & Labor Market Dashboard (2018–2025)

![Dashboard Overview](assets/dashboard_overview.png)

## Project Motivation & Analytical Questions
This project explores recent shifts in the European Union labor market and macroeconomic environment, evaluating whether recent labor market pressures resemble the 2020 shock. By combining unemployment rates with inflation, real wage growth, in-work poverty across age groups, and job vacancy ratios, the dashboard compares how EU countries and regions performed across pre-pandemic, shock, and recent periods.

## Data Sources & Scope
All underlying tables originate from **Eurostat** CSV exports covering **2018–2025** (`2018` is retained as a baseline/lag reference year, while incomplete `2026` data is excluded pending full-year closing statistics):

* **`une_rt_a`**: Annual unemployment rates and counts
* **`prc_hicp_aind`**: Annual inflation rates and price index comparisons
* **`earn_nt_net`**: Net earnings, focused on a single person earning 100% of average earnings (household/couple structures and lower-income tiers are future research goals)
* **`jvs_q_nace2`**: Quarterly job vacancies, aggregated to annual averages rather than summed to avoid rolling-quarter inflation when compared against annual indicators
* **`ilc_iw01`**: In-work poverty rates by age group

### Data Quality & Modeling Notes
* **Eurostat Reporting Gaps:** Missing series for specific countries/periods (such as vacancy figures for Italy and Denmark, and partial series for Estonia) were preserved rather than mixed with external sources, so that methodology consistency across Eurostat series is maintained.
* **Quarterly-to-Annual Alignment:** Using average quarterly vacancies avoids double-counting positions that roll over quarters.
* **SQL & Power BI Architecture:** Raw CSVs were cleaned, aggregated, and joined in **MySQL** (handling result-grid export row limits), then loaded into **Power BI** using a star schema connecting location and year dimension tables to analytical tables, with dynamic DAX measures, Field Parameters, and interactive cross-filtering.

## Key Findings
* **2020–2025 Shocks & Real Wage Divergence:** Most EU economies experienced recurring macro shocks marked by inflation spikes, unemployment increases, and real wage pressure. Real wage growth turned negative in several Western European economies relative to 2018, whereas many Central and Eastern European economies achieved substantial cumulative real wage gains—led by **Bulgaria** at roughly **+90%** cumulative real growth versus 2018.
* **Youth In-Work Poverty:** In-work poverty among young adults (ages 18–24) remains elevated across much of Europe. **Denmark** stood out in 2025 with a higher youth rate than several CEE and peer developed economies, while **Greece**, **Latvia**, **Czechia**, **Croatia**, **Slovenia**, **Malta**, **Portugal**, **Belgium**, and **Ireland** showed lower rates for young adults than for their general working-age populations.
* **Vacancy-to-Unemployed Competition:** Higher vacancy-to-unemployed ratios appeared in countries such as the **Netherlands**, **Germany**, **Malta**, **Austria**, and **Czechia** (roughly 1–2 unemployed per average quarterly vacancy), compared with lower ratios such as **Spain** at around **6 average quarterly vacancies per 100 unemployed** despite recent employment improvements. Thus, the first group showed lower risks, compared to the peer countreis within EU. 

## Repository Structure
* `sql/01_build_eu_macro_tables.sql` — MySQL table creation, cleaning, window calculations, and analytical queries
* `data/` — Dimension and processed CSV tables used for reporting
* `powerbi/eu_macro_dashboard.pbix` — Interactive Power BI report and data model
* `assets/dashboard_overview.png` — Preview screenshot of the dashboard

## Future Improvements
* Add full-year `2026` Eurostat data once year-end figures are published.
* Expand earnings and poverty analysis to additional household types and income levels.
* Automate data refresh steps beyond manual CSV exports.
