<!--
Verbatim text of two sections of the GLORIA release notes (Release 060, December 2024,
pages 22-24), written by the GLORIA team (Manfred Lenzen et al., Integrated Sustainability
Analysis, The University of Sydney). Reproduced in GLORIApp with attribution under
CC BY-NC 3.0 AU; NOT written by the authors of GLORIApp. Shown in the tab "About GLORIA"
(app/gloria_reading.R). The source note is added by the app.
-->

### A plain-English short philosophy of MRIO-building

Constructing an (MR)IO database is a severely underdetermined problem. Typically, MRIO tables for one year comprise in the order of ten million to a few billion elements<sup>10</sup>. These are constrained by primary data numbering between a few thousand up to a million points. This means that an MRIO needs to be constructed by starting with an initial estimate, and then by imposing constraints using optimisation. A particularly challenging feature of MRIO-building is that primary data sources do not agree with each other, and sometimes are even internally inconsistent.

Most primary data address fields in an MRIO matrix that interact with each other. For example, international trade data combines regions of origin with regions of destination, which are in turn represented by their own national accounts data, which in turn must comply with theoretical input-output balances. Information valued in purchasers' prices connects trade and transport margins with taxes and subsidies, and factory- and farm-gate (basic) prices. A single value of an individual country's GDP connects elements across the entire MRIO table. As a result, any oddity in one primary data source has consequences for the imposition of all other sources!

This means that there is no way that an MRIO database can be built in a way that perfectly represents all primary data. Instead, MRIO compilers use constrained optimisation techniques to find the MRIO table that has the best fit to all primary data simultaneously. For large MRIO tables, this requires uses high-performance computers with many terabytes of memory, and many processing units, to enable parallel computing.

More importantly, this also means that MRIO elements are not fixed numbers. They are estimates characterised by uncertainties. In the GLORIA database, these uncertainties are represented in the accompanying standard-deviations tables. These uncertainties tend to be larger for areas of the table that are only weakly constraint by primary data, such as low-income economies or small industries. During construction, such weakly-constrained areas "react" and "budge" to constraints being imposed on more densely constrained table areas. It's very much like a water bed – if you try to hold it in shape in one spot, it keeps bulging out in other spots where you're not holding it!

When primary data sources disagree with each other, one has to make a decision about how to handle any discrepancies. Some teams make binary decisions by excluding one or more databases entirely from the construction process. When constructing GLORIA, we take the perspective that no data source is entirely incorrect, but that different data sources have different degrees of reliability. Accordingly, we assign levels of uncertainty to each primary data point. Then, during the construction process more uncertain primary data are overridden by less uncertain primary data.

Importantly, this means that there is no single one "true" MRIO database. Depending on compilers' different selection of primary data, their different deeming of reliability and hence different relative priority settings, and their different classifications and degrees of regional and sectoral aggregation, amongst further criteria, mean that there are many ways to portray the structure of economies, and in general these do not perfectly agree (see an assembly of intercomparisons by Inomata and Owen 2014).

Any MRIO database will always mis-represent certain primary data, and users and compilers can have differing opinions about a preferred representation. For example, an officer from Japan's statistical bureau might require an MRIO to exactly represent Japan's domestic and external transactions, and an MRIO can in principle be built that sets adherence to Japan's own accounts as its highest priority. However, as a consequence, in the ensuing MRIO database, other countries' primary data may not be exactly represented, for example because their information on trade with Japan differs from Japan's own trade information.

For further details on issues of uncertainty, feel free to read "*Uncertainty and Reliability in the Eora MRIO tables*" at <a href="https://worldmrio.com/documentation/EoraConfidence.jsp" target="_blank">https://worldmrio.com/documentation/EoraConfidence.jsp</a>.

<p class="small text-muted"><sup>10</sup> GLORIA comprises (164 × 164) × [120 × (120+6+6)] × 5 = 2,130,163,200 elements for every year, and 80,946,201,600 elements for a time series spanning the years 1990 to 2028.</p>

### A plain-English explanation of MRIO-based footprinting

Many researchers use multi-region input-output (MRIO) data to calculate environmental, economic and social footprints that take into account numerous supply-chain transactions between regions and sectors of the global economy. MRIO data distinguish the entire flow of money through an economy, that is, i) intermediate demand (a matrix **T**) are transactions between producing sectors, ii) final demand (a matrix **Y**) are sales of sectors to agents such as households, the government and the capital sector, and iii) value added (a matrix **W**) are payments of sectors to the same agents. The entire economy is in balance according to **T** + **Y** = **W** + **T** (Tukker and Dietzenbacher 2013).

<table class="table table-sm table-bordered text-center" style="max-width: 720px; margin: 1em auto;">
<thead>
<tr><th colspan="2"></th><th colspan="2">Region 1</th><th colspan="2">Region 2</th><th colspan="2">Final demand</th></tr>
<tr><th colspan="2"></th><th>Goods</th><th>Services</th><th>Goods</th><th>Services</th><th>Region 1</th><th>Region 2</th></tr>
</thead>
<tbody>
<tr><th rowspan="2">Region 1</th><th>Goods</th><td style="background:#dbe7f5">100</td><td style="background:#dbe7f5">10</td><td style="background:#dbe7f5">5</td><td style="background:#dbe7f5">0</td><td style="background:#f8d9d9">30</td><td style="background:#f8d9d9">0</td></tr>
<tr><th>Services</th><td style="background:#dbe7f5">0</td><td style="background:#dbe7f5">20</td><td style="background:#dbe7f5">0</td><td style="background:#dbe7f5">0</td><td style="background:#f8d9d9">20</td><td style="background:#f8d9d9">5</td></tr>
<tr><th rowspan="2">Region 2</th><th>Goods</th><td style="background:#dbe7f5">30</td><td style="background:#dbe7f5">0</td><td style="background:#dbe7f5">20</td><td style="background:#dbe7f5">0</td><td style="background:#f8d9d9">15</td><td style="background:#f8d9d9">10</td></tr>
<tr><th>Services</th><td style="background:#dbe7f5">10</td><td style="background:#dbe7f5">10</td><td style="background:#dbe7f5">0</td><td style="background:#dbe7f5">5</td><td style="background:#f8d9d9">0</td><td style="background:#f8d9d9">10</td></tr>
<tr><th colspan="2">Value added</th><td style="background:#d9f0dd">5</td><td style="background:#d9f0dd">5</td><td style="background:#d9f0dd">50</td><td style="background:#d9f0dd">30</td><td colspan="2"></td></tr>
</tbody>
</table>

<p class="small">Schematic of multi-region input-output data for a simplified 2-region economy. Blue: intermediate demand <b>T</b>, red: final demand <b>Y</b>, green: value added <b>W</b> (taken from Kanemoto and Murray 2010). Here, producers in region 2 supply producers in region 1 with 30 units of goods, and final demand agents in region 1 with 15 units of goods.</p>

The founder of input-output analysis, Nobel-Prize laureate Wassily Leontief, had environmental (Leontief and Ford 1970) and social (Leontief 1986; Leontief and Duchin 1986) applications in mind already in the 1970s! Other early work connects input-output tables with local ecologies and trophic chains (Isard et al. 1967; Isard 1975). Considering that input-output tables are able to capture regional and sectoral relationships across complex supply-chain networks, Leontief's work had enormous influence on research aimed at enumerating the direct and indirect effects of consumption decisions (such as in Life-Cycle Assessment, LCA) or economic disruptions (such as from the early oil crises). Following Leontief's work, the disciplines of LCA (Bullard et al. 1978) and energy analysis (Herendeen 1973) adopted input-output analysis into best-of-many-worlds hybrid methods (Suh et al. 2004). Later, footprinting emerged out of LCA, and input-output analysis became central to its technical repertoire (Wiedmann 2009).

Leontief's basic idea was to couple environmental accounts to the input-output system (Leontief and Ford 1970), as additional rows in the schema above (Forssell 1998), and his idea is still followed in today's footprinting. This matrix coupling enables environmental and social externalities to be connected to the monetary representation of the global economy, which is precisely the feature that footprints offer: the embodiment of environmental and social quantities in monetary amounts of final demand. Analytical techniques from the input-output toolbox such as series expansion (Waugh 1950) and structural path analysis (Treloar 1997) then enable the dissection of footprints into contribution by regions, sectors, upstream production stages and even individual supply chains.

Thanks to the ability of MRIO assessments to capture direct and indirect supply-chain contributions, the input-output-based carbon footprint of, for example, the usage of a motor vehicle, includes:

- direct emissions from combusting petrol or diesel in the engine;
- 1st-order emissions for example by vehicle assembly plants welding parts together for making finished motor vehicles;
- 2nd-order emissions for example by metal rolling plants manufacturing the vehicle body's sheet metal for assembly plants for making finished motor vehicles;
- 3rd-order emissions for example by smelters making steel for rolling plants making steel sheet for assembly plants making finished motor vehicles;
- 4th-order emissions for example by iron ore mines supplying iron ore to steel smelters making steel for rolling plants making steel sheet for assembly plants making finished motor vehicles;
- 5th-order emissions for example by mining machinery manufacturers making excavators for iron ore mines supplying iron ore to steel smelters making steel for rolling plants making steel sheet for assembly plants making finished motor vehicles;
- and so on.

MRIO-based carbon footprints are thus complete, that is they capture upstream supply-chain contributions of infinite order, in a collectively exhaustive and mutually exclusive way. This means that MRIO-based carbon footprints are complete and are not affected by any double-counting. Mathematically, this is facilitated by the so-called Leontief inverse, a matrix conceived by Wassily Leontief. Evaluating upstream supply-chain contributions to footprints is important for policy-making, procurement and product design, in order to enable valid comparisons and benchmarking (Foran et al. 2005), and to avoid misleading conclusions and recommendations (Lenzen and Treloar 2003).

#### References cited in these two sections

<div class="small">

- Bullard, C.W., P.S. Penner and D.A. Pilati (1978) Net energy analysis - handbook for combining process and input-output analysis. Resources and Energy 1, 267-313.
- Foran, B., M. Lenzen, C. Dey and M. Bilek (2005) Integrating Sustainable Chain Management with Triple Bottom Line Reporting. Ecological Economics 52, 143-157.
- Forssell, O. (1998) Extending economy-wide models with environment-related parts. Economic Systems Research 10, 183-199.
- Herendeen, R.A. (1973) Use of input-output analysis to determine the energy cost of goods and services. In: M.S. Macrakis (ed.) Energy: Demand, Conservation, and Institutional Problems. Cambridge, MA, USA, Massachusetts Institute of Technology, 141-158.
- Inomata, S. and A. Owen (2014) Comparative evaluation of MRIO databases. Economic Systems Research 26, 239-244.
- Isard, W. (1975) Economic-ecologic conflict and environmental quality. Introduction to Regional Science. Englewood Cliffs, NJ, USA, Prentice-Hall, 341-371.
- Isard, W., K. Bassett, C. Choguill, J. Furtado, R. Izumita, J. Kissin, E. Romanoff, R. Seyfarth and R. Tatlock (1967) On the linkage of socio-economic and ecologic systems. Papers and Proceedings of the Regional Science Association 21, 79-99.
- Kanemoto, K. and J. Murray (2010) What is MRIO: Benefits and limitations. In: J. Murray and R. Wood (eds.) The Sustainability Practitioner's Guide to Input-Output Analysis. Champaign, USA, Common Ground, 167-178.
- Lenzen, M. and G. Treloar (2003) Differential convergence of life-cycle inventories towards upstream production layers. Journal of Industrial Ecology 6, 137-160.
- Leontief, W. (1986) An information system for policy decisions in a modern economy. Input-Output Economics. New York, NY, USA, Oxford University Press, 418-428.
- Leontief, W. and F. Duchin (1986) The future impact of automation on workers. Oxford, UK, Oxford University Press.
- Leontief, W. and D. Ford (1970) Environmental repercussions and the economic structure: an input-output approach. Review of Economics and Statistics 52, 262-271.
- Suh, S., M. Lenzen, G.J. Treloar, H. Hondo, A. Horvath, G. Huppes, O. Jolliet, U. Klann, W. Krewitt, Y. Moriguchi, J. Munksgaard and G. Norris (2004) System boundary selection in Life-Cycle Inventories. Environmental Science & Technology 38, 657-664.
- Treloar, G. (1997) Extracting embodied energy paths from input-output tables: towards an input-output-based hybrid energy analysis method. Economic Systems Research 9, 375-391.
- Tukker, A. and E. Dietzenbacher (2013) Global multiregional input-output frameworks: An introduction and outlook. Economic Systems Research 25, 1-19.
- Waugh, F.V. (1950) Inversion of the Leontief matrix by power series. Econometrica 18, 142-154.
- Wiedmann, T. (2009) Carbon footprint and input-output analysis: an introduction. Economic Systems Research 21, 175-186.

</div>
