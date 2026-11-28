---
title: "GLORIApp - User guide"
subtitle: "Footprints with the GLORIA global input-output database, without programming"
---

# What GLORIApp does

GLORIApp calculates **footprints**: the environmental, social and economic pressures that the consumption of a country (or group of countries) causes along the whole global supply chain. It uses **GLORIA**, a global multi-regional input-output database for 164 countries and regions, 120 sectors and the years 1990-2029, developed at the University of Sydney for the UN International Resource Panel.

You choose indicators, years, how regions and sectors are grouped, and how the result is split. The app calculates the table and you download it as a csv file for Excel, R, Python or any other tool. The tab *Charts* gives a quick interactive look at the result.

Typical questions:

- How large is Austria's carbon footprint, and in which countries are the emissions released?
- Which final products (food, cars, buildings, services) drive the land footprint of the EU?
- Are high-income countries net importers of materials?
- Where is the income (value added) behind German consumption earned?

# Key ideas in plain language

## Production-based and consumption-based accounts

A **production-based** (territorial) account counts a pressure where it physically happens: the CO2 from a steel plant in China is counted for China. National emission inventories work like this.

A **consumption-based** account, the **footprint**, counts the same CO2 for the country where the final product is bought: if the steel ends up in a car bought by an Austrian household, the emission is part of Austria's footprint.

Both views are correct. Summed over the whole world they are equal. The difference for one country is its **net import** of the pressure. Positive net imports mean that a country relies on pressures that happen abroad.

## Supply chains and the Leontief inverse

Producing a car needs steel, which needs electricity and iron ore, which need machines, which need steel again, and so on. Input-output analysis follows **all** these rounds at once. The tool for this is the **Leontief inverse**, named after the economist Wassily Leontief.

## Final demand

**Final demand** is what is bought for final use and not processed further: purchases of households, non-profit institutions and governments, investment in buildings and machinery (gross fixed capital formation), changes in inventories and valuables. GLORIA distinguishes these six categories for every country.

Some pressures are caused by final users directly, without any industry, e.g. the emissions from heating a home or driving a private car. GLORIA reports them separately ("direct emissions of households"). The app adds them to the footprint of the country where the households live (option in step 5).

# The mathematics, step by step

This section explains the calculation with a tiny example. You do not need it to use the app, but it helps to interpret the results.

## The data

An input-output table describes, in money, who sells to whom. Take two regions, *Alpland* (A) and *Coalland* (C), each with one sector:

| sold by \\ bought by | industry A | industry C | final demand A | final demand C | total output |
|---|---|---|---|---|---|
| industry A | 20 | 20 | 50 | 10 | **100** |
| industry C | 10 | 40 | 20 | 30 | **100** |

The first two columns are the inter-industry flows $Z$ (e.g. Coalland's industry buys goods worth 20 from Alpland). The next two columns are final demand $Y$. The row sums are the total output $x$.

Emissions (satellite account $q$): Alpland emits 10 kt CO2, Coalland 60 kt.

## Step 1: technical coefficients

Divide each column of $Z$ by the output of the buying industry. This tells how much input is needed per unit of output:

$$A = Z \, \mathrm{diag}(x)^{-1} = \begin{pmatrix} 0.2 & 0.2 \\ 0.1 & 0.4 \end{pmatrix}$$

To produce goods worth 1 USD, Coalland's industry needs inputs worth 0.2 USD from Alpland and 0.4 USD from itself.

## Step 2: the Leontief inverse

The inputs need inputs again, and so on. The sum of all rounds $I + A + A^2 + A^3 + \dots$ equals the Leontief inverse:

$$L = (I - A)^{-1} = \begin{pmatrix} 1.304 & 0.435 \\ 0.217 & 1.739 \end{pmatrix}$$

Reading example: one USD of final products from Coalland requires 0.435 USD of production in Alpland and 1.739 USD in Coalland (including the final product itself) over the whole supply chain.

## Step 3: direct intensities

Emissions per USD of output: $s = q / x$, here $s_A = 10/100 = 0.1$ and $s_C = 60/100 = 0.6$ kt per USD.

## Step 4: the footprint

The footprint of the final demand $y$ of a consumer is

$$F = \mathrm{diag}(s) \, L \, y$$

For Alpland's consumers ($y = (50, 20)$):

| emitted in | footprint of Alpland's consumers (kt) |
|---|---|
| Alpland | 7.4 |
| Coalland | 27.4 |
| **total** | **34.8** |

Alpland emits only 10 kt on its own territory (production-based), but its consumption causes 34.8 kt worldwide. Most of it is released in Coalland. Alpland is a **net importer** of 24.8 kt CO2. Coalland's footprint is 35.2 kt, against 60 kt production-based. The world totals match: 10 + 60 = 34.8 + 35.2.

## Step 5: split by final product

The same footprint can be split by the final products bought instead of by where emissions happen. The **multiplier** $m = s \, L$ gives the emissions along the whole supply chain per USD of final product: 0.26 kt for Alpland's products and 1.09 kt for Coalland's products. Alpland's consumers buy products from Alpland worth 50 (50 × 0.26 = 13.0 kt) and from Coalland worth 20 (20 × 1.09 = 21.7 kt). The total is again 34.8 kt.

## Every indicator works the same way

Replace the emissions $q$ by tonnes of extracted materials, hectares of land, number of workers or **value added** (wages, profits, taxes), and the same formula gives the material, land, employment or **value-added footprint**. The value-added footprint shows in which countries the income behind a country's consumption is earned. This is also known as **trade in value added** from the final-demand perspective.

In GLORIApp the real tables have 164 × 120 = 19,680 rows and columns. The principle is exactly the same.

# Using the app

Start the app (see the README or ask your colleague who installed it). It opens in the web browser. The left sidebar contains seven steps; the main area shows the result, explanations of all indicators, the data update tab and a short help page.

## Step 1 - What do you want to calculate?

- **Footprint (consumption-based)**: the standard choice.
- **Overview**: one line per region with the production-based account, the footprint and the net imports.
- **Production-based (territorial) account**: pressures where they occur.

## Step 2 - Indicators

Choose one or more of the recommended indicators: materials (biomass, metal ores, minerals, fossil fuels), greenhouse gases and single gases, air pollutants and their health effects, land use, primary energy, employment (by gender and skill), water, biodiversity and value added. The tab *Indicator explanations* describes each of them in one or two sentences, including the unit.

*Expert mode* gives access to all 6,130 raw GLORIA satellite rows, e.g. a single gas from a single emission source.

## Step 3 - Years

Any selection of the years 1990-2029. GLORIA is based on statistics up to about 2022. Later years are nowcasts and projections; use them for trends and with care.

## Step 4 - Breakdown of the result

Here you decide which columns the result table has. Both sides of the footprint are described the same way: **where** (region) and **what** (sector or product); the consumption side also by **who** (final demand category).

| Side | Question | Drop-down | Column in the table |
|---|---|---|---|
| Production side | **Where** does the pressure occur? | Where: region | production_region |
| Production side | **What** (which sector) causes it directly? | What: sector | production_sector |
| Consumption side | **Where** are the consumers? | Where: region | consumption_region |
| Consumption side | **What** final products do they buy? | What: final product | consumption_product |
| Consumption side | **Who** buys (households, government, investment, ...)? | Who: split by final demand category | consumption_category |
| Consumption side (optional) | Where was the final product made? | region where the final product was made | product_made_in |

*Do not split (total)* leaves a dimension out. Splitting the production side **and** the final product at the same time gives a very detailed from-to table (e.g. "Chinese coal power in cars bought in Germany"). It takes longer (10-60 seconds per year and indicator), so group regions and sectors coarsely in that case.

For *Overview* and *Production-based* only the production side is used.

Region groupings: countries, 7 world regions, World Bank income groups (classification of July 2025), World Bank regions, development groups, world total, or your own groups (step 6). Sector groupings: 120 sectors, 20 ISIC sections, 6 broad sectors, or your own groups.

## Step 5 - Final demand

Choose which final demand categories to include (usually all six) and whether direct emissions of households are added. Without the households' direct emissions the footprint only contains what industries emit.

## Step 6 - Own groupings

Define your own groups, e.g. "EU27" from 27 countries or "Food" from the agricultural and food sectors. Type a name, choose the members and click *Add group*. Everything not assigned goes into a rest group (name adjustable). The grouping appears as *Own grouping (step 6)* in all drop-down menus of step 4. Save it as a csv file to load it again next time.

## Step 7 - Output table

- **Long format**: one value per row with all dimensions as columns. This is the format for pivot tables in Excel and for analysis in R or Python. Recommended.
- **Wide format**: a cross table with one column per year (or per indicator), handy for a quick look in Excel.

**File format** for the download:

- **CSV, comma-separated**: the international standard, for R, Python and English-language Excel.
- **CSV for German/Austrian Excel**: semicolon-separated with decimal comma - opens correctly with a double click in German Excel.
- **Excel workbook (.xlsx)**: sheet *result* plus a sheet *info* with all settings and the plausibility checks. Excel allows at most 1,048,576 rows; for bigger results the app asks you to choose CSV/text or to group more coarsely.
- **Text, tab-separated (.txt)**.

Click **Calculate**. The result appears as a preview (first 1,000 rows) and can be downloaded with the **Download** button. The column *unit* gives the unit of every value. Next to it, **Save in folder** writes the file directly into the folder given in step 7 (default: *Documents/GLORIApp_results*; *remember this folder* keeps your choice). Downloads go to your browser's download folder.

## Charts

After *Calculate*, the tab **Charts** shows the result as an interactive chart. Hover over it for exact values; the camera icon saves a PNG.

- **Ranking (bars)**: the largest groups of one column (e.g. production regions), for one year.
- **Time series (lines)**: one line per group over all calculated years.
- **Composition (stacked bars)**: one column on the axis, another as colour (e.g. consumer regions by production sector).

Choose the indicator, the column to show (*Show by*), optionally a filter (e.g. only `consumption_region = Austria`) and the number of groups; smaller groups are combined into *Other*. The charts are for a quick look; for publication-quality figures use the csv in your own tool.
**Export**: below the chart settings choose *PNG*, *JPEG* (images, 300 dpi), *SVG* or *PDF* (vector graphics, can be edited e.g. in Inkscape or Illustrator) and click *Download image*, or *Save image in folder* to save it directly into the folder set in step 7.


# Typical questions - which settings?

Each recipe lists what to set; everything not mentioned stays at its default (all final demand categories, direct household emissions included, long format). "Production side" and "Consumption side" refer to the two boxes in step 4. "Not split" means *Do not split (total)*. Choose the indicator and year(s) you need; the examples use greenhouse gases.

**1. How large is the carbon footprint of my country?**
Step 1 *Footprint*. Production side: where *not split*, what *not split*. Consumption side: where *Countries/regions*, what *not split*, who unticked.
→ One row per country; filter `consumption_region`.

**2. In which countries are the emissions of my country's consumption released?**
As 1, but production side where *Countries/regions* (or *7 world regions*).
→ Filter `consumption_region` = your country; `production_region` shows where the emissions happen. Chart: *Ranking*, show by *production region*, filter on *consumption region*.

**3. Which sectors (at home and abroad) cause them?**
As 2, plus production side what *6 broad sectors* (or *Sectors (120)*).
→ `production_sector` shows e.g. electricity, agriculture, manufacturing. *Direct emissions of final users* are households' own heating and cars.

**4. Which products drive the footprint (food, cars, buildings, services ...)?**
Production side: both *not split*. Consumption side: where *Countries/regions*, what *6 broad sectors* or *Sectors (120)*.
→ `consumption_product` = the final products bought, with the emissions of their whole supply chain.

**5. Is it households, the government or investment?**
Any recipe above, plus consumption side *Who: split by final demand category*.
→ Column `consumption_category`.

**6. Footprints of income groups or world regions**
Consumption side where *World Bank income groups* (or *7 world regions*, *World Bank regions*).

**7. Is my country a net importer of emissions (or materials, land ...)?**
Step 1 *Overview*, regions *Countries/regions*.
→ For each region: production-based, consumption-based and net imports (positive = net importer).

**8. How much is emitted inside each country, by sector? (territorial, like national inventories)**
Step 1 *Production-based*. Where *Countries/regions*, what *6 broad sectors*.

**9. How has the footprint developed over time?**
Recipe 1 with *select all years* (or *every 5th year*) in step 3.
→ Charts tab: *Time series*. Note: years after ~2022 are projections.

**10. Where is the income behind my country's consumption earned? (value-added footprint, trade in value added)**
Recipe 2 with indicator *Value added (total)*.
→ Share of `production_region` other than your country = value added earned abroad.

**11. How many jobs abroad depend on EU consumption?**
Step 6: define *EU27* (rest = *Rest of world*). Indicator *Employment (total)*. Production side where *Countries/regions*; consumption side where *Own grouping (step 6)*.
→ Filter `consumption_region = EU27`, then look at `production_region` outside the EU.

**12. What is the land footprint of the food we eat?**
Step 6: define a sector group *Food* (crop and animal farming, fishing, the food and beverage manufacturing sectors, *Hospitality* ...). Indicator *Land use (total)*. Production side where *7 world regions*; consumption side where *Countries/regions*, what *Own grouping (step 6)*.
→ Filter `consumption_product = Food`.

**13. Which of my country's consumption is made abroad, and what does it cause there?**
Production side *not split*; consumption side where *Countries/regions*, what *6 broad sectors*, made in *Countries/regions*.
→ `product_made_in` = where the final product was produced (e.g. cars made in Germany bought in Austria).

**14. Very detailed: how much coal power from China is in the cars bought in Germany?**
Production side where *Countries/regions*, what *Sectors (120)*. Consumption side where *Countries/regions*, what *Sectors (120)*.
→ Filter `production_region = China`, `production_sector` = *Electric power generation, transmission and distribution*, `consumption_product` = *Motor vehicles, trailers and semi-trailers*, `consumption_region = Germany`. This "both sides" breakdown is slow (up to a minute per year) and gives very large tables; group coarsely where you can and use few years.

# Reading the results correctly

- **Plausibility checks**: below every result the app shows a green box (*all checks passed*) or a red one. Click it to see the details. The checks verify basic input-output identities on the real data, e.g. that the footprints of all consumers add up to the total emissions of the world. A red box means something went wrong - do not use that result and report it.
- **Units**: kt = 1,000 tonnes; Mt = 1,000 kt. Land in 1,000 hectares, energy in terajoules, employment in persons, money in 1,000 USD at current prices (so values over time include inflation).
- **Rest-of-world regions**: four GLORIA regions (Rest of Americas, Europe, Africa, Asia-Pacific) bundle many small countries. In the World Bank income grouping they form their own group.
- **Recent years** are projections (see step 3).
- **Sums**: the world total of a footprint equals the world total of the production-based account, if direct household emissions are included in both.
- **Negative values** can appear for inventory changes (final demand category "changes in inventories").

# Getting and updating the GLORIA data

**Option A - use an already compiled GLORIA (easiest).** If a colleague shares the compiled GLORIA (a folder called e.g. 'v60', about 125 GB) via Box, a network drive or a disk: download the whole folder, put it anywhere on your PC (e.g. *D:/GLORIA/v60*), open the tab **Data & updates**, enter the folder under *Option A* and click *Check and use this folder*. The app checks that nothing is missing or incomplete and uses the data after a restart. No Google account and no compiling is needed.

**Option B - download and compile from Google Drive.**

When a new GLORIA release is published, the tab **Data & updates** downloads and compiles it. At the top of the tab you choose where the compiled MRIO and the temporary raw files are stored (two folders, may be on different drives; *Save folders as default* keeps them for the next time). Connect Google Drive once, paste the link of the release folder, check it and start the update. It runs in the background for several hours, year by year, and deletes the raw files after each year. Afterwards restart the app. See the developer guide for details.

# How to cite

Please cite GLORIA: Lenzen, M., Geschke, A., West, J. et al. (2022). Implementing the material footprint to measure progress towards Sustainable Development Goals 8 and 12. *Nature Sustainability* 5, 157-166. Also cite the release notes of the GLORIA version used (shown in the app title).
