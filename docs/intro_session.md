# GLORIApp - introduction session (90 minutes)

Material for a hands-on introduction for colleagues without input-output background.
Participants need: the app running on their PC (or a shared PC), Excel or R.

## Agenda

| Time | Block | Content |
|---|---|---|
| 0:00 | Why footprints? | Production- vs. consumption-based accounting, outsourcing of pressures |
| 0:15 | GLORIA in 10 minutes | 164 regions, 120 sectors, 1990-2028, satellite accounts, where the data come from |
| 0:25 | Input-output logic | Supply chains, the Leontief inverse as "all supply-chain rounds at once" |
| 0:35 | App walk-through | The 6 steps of the sidebar, result types, csv export |
| 0:50 | Hands-on exercises | Exercises 1-5 below, in pairs |
| 1:20 | Pitfalls and discussion | Projections after ~2022, rest-of-world regions, gross vs. net trade, units |

## Key messages

1. **Production-based** = what happens inside a country. **Consumption-based (footprint)** = what a country's final demand causes worldwide. The difference is the *net import* of a pressure.
2. Every pressure ends up in some final demand: the global sum of all footprints equals the global sum of all production-based accounts.
3. A footprint can be split by **origin** (where does the pressure happen?) or by **final product** (what was bought?). Both give the same total.
4. **TiVA** with value added answers "who earns the money in exports?". Gross-export based indicators double count goods crossing borders several times; for "who causes what" use footprints.
5. Years after the latest statistics (roughly 2023+) are **nowcasts/projections**. Use them for trends with care, not for precise numbers.

## Input-output in one picture

```
 pressure            supply chain                 final demand
 (q / x)    x    (I - A)^-1 = L     x      Y (households, government, investment)
 "how dirty     "how much output of every          "what is bought, by whom"
  is 1 USD of    sector worldwide is needed
  output"        for 1 USD of final product"
```

## Exercises

**Exercise 1 - carbon footprint of Austria.**
Result type *Footprint: where the pressure happens*, indicator *Greenhouse gases (GWP100; EDGAR)*, year 2019, origin regions: *7 world regions*, consumer regions: *No aggregation*. Filter the csv for `to_region = Austria`.
- How large is Austria's carbon footprint (Mt CO2-eq = kt / 1000)?
- Which share happens outside Europe?

**Exercise 2 - production vs. consumption.**
Result type *Overview*, indicators *Greenhouse gases* and *Material footprint*, years 2000 and 2019, regions: *World Bank income groups*.
- Which income group is a net importer of emissions and materials? Did it change between 2000 and 2019?
- Check: net imports sum to (almost) zero over all groups. Why?

**Exercise 3 - what drives the footprint?**
Result type *Footprint: by final product*, indicator *Land use (total)*, year 2019, product regions: *World total*, sectors: tick *Show sector detail* with *6 broad sectors*, final demand categories shown separately.
- Which product groups and which final demand category drive the land footprint of the EU countries / of your country?

**Exercise 4 - own region grouping.**
Download the region template in step 4, define a group "EU27" (all other regions "Rest of world"), upload it and repeat exercise 1 with the EU27 as consumer.

**Exercise 5 - Trade in Value Added.**
Result type *TiVA*, indicator *Value added (total)*, year 2019, show sector detail with *6 broad sectors*.
- What share of Germany's manufacturing exports is foreign value added?
- Repeat with *Greenhouse gases*: how much of the emissions embodied in China's exports happen in China?

## Pitfalls checklist

- Units: kt vs. Mt, tonnes vs. Gt, 1000 ha, persons, 1000 USD (current prices).
- "Rest of ..." regions combine many small countries.
- Monetary values are in current USD: changes over time include inflation and exchange rates.
- Direct household emissions (heating, private cars) are included only if the checkbox in step 5 is ticked.
- Biomass includes crop residues and grazed biomass; metal ores are gross ore.

## Further reading

- GLORIA release notes v60 (in `C:/Users/<user>/Data/GLORIA/v60/raw/`).
- Miller & Blair (2022): *Input-Output Analysis: Foundations and Extensions*, 3rd ed., chapters 2, 3 and 10.
- Lenzen et al. (2022), *Nature Sustainability* 5, 157-166 (GLORIA material footprint).
