## How GLORIApp works

**GLORIA** is a global multi-regional input-output (MRIO) database. It describes, for 164 countries/regions and 120 sectors, who sells how much to whom, what is consumed in the end (final demand), and which environmental and social pressures (emissions, materials, land, water, energy, employment, ...) occur in each sector. Developed by the University of Sydney (Industrial Ecology Virtual Laboratory) for the UN International Resource Panel.

### The idea of a footprint

When you buy a smartphone in Austria, emissions happen in many places: mining in Chile, chip production in Taiwan, assembly in China, transport, retail in Austria. Input-output analysis follows these supply chains through the whole world economy and assigns all of these pressures to the **final consumer**.

- **Production-based (territorial) account:** pressure counted where it physically happens.
- **Consumption-based account (footprint):** pressure counted where the final product is consumed.
- **Net imports** = footprint minus production-based account. Positive values mean a region "imports" pressure embodied in goods.

### The maths in one line

Footprint = `s * L * Y`

- `s` - direct intensity: pressure per 1000 USD of output of each sector (e.g. kt CO2-eq / 1000 USD)
- `L` - Leontief inverse: how much output of every sector worldwide is needed to deliver one unit of a final product (all supply-chain steps)
- `Y` - final demand: what households, governments and investors buy

### Result types and breakdown

**Footprint** is the main result type. It works the same way for every indicator; with *Value added* it is the value-added footprint (trade in value added of final demand). In step 4 you choose how to split it:

| Dimension | Meaning | Typical question |
|---|---|---|
| Origin (regions, sectors) | where the pressure physically occurs | Which countries and sectors emit CO2 for Austrian consumption? |
| Final product (regions, sectors) | which final products are bought, and where they were made | Which products drive the EU's land footprint? |
| Consumer (regions, final demand category) | who buys | Which income group has the largest material footprint? |
| Origin x final product (expert) | both at once, a detailed from-to table | How much Chinese coal power is in cars bought in Germany? |

Other result types: **Overview** (production-based, consumption-based and net imports per region) and **Production-based** (territorial account). Under *Show expert options* you also find **Embodied in gross exports** (OECD TiVA style, domestic vs. foreign content of exports).

### Good to know

- All values are **totals per year** (not per capita). Units are given in the column `unit`.
- **Direct emissions of households** (heating, private cars) are not caused by any industry. If the checkbox is ticked, they are added to the footprint of the region where the households live (and to its production-based account).
- **Years after the latest statistical data** (roughly after 2022) are nowcasts/projections by the GLORIA team.
- **Rest-of-world regions** (Rest of Americas, Europe, Africa, Asia-Pacific) contain many small countries; they form their own group in the World Bank income grouping.
- Monetary values are in **1000 USD at current prices** (basic prices).

### Citation

Lenzen, M. et al. (2022): Implementing the material footprint to measure progress towards SDGs 8 and 12. *Nature Sustainability* 5, 157-166. Please also cite the GLORIA release notes of the version used (here v60).
