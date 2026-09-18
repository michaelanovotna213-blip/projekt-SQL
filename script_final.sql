/* ============================================================
   PROJEKT SQL — dostupnost základních potravin v ČR
   Michaela Novotná
   ============================================================ */


/* primární tabulka pro data mezd a cen potravin za Českou republiku
   sjednocených na totožné porovnatelné období – společné roky */

DROP TABLE IF EXISTS t_michaela_novotna_project_SQL_primary_final;

CREATE TABLE t_michaela_novotna_project_SQL_primary_final AS
SELECT
    mzdy.rok,
    mzdy.odvetvi,
    mzdy.mzda_kc,
    ceny.potravina,
    ceny.mnozstvi,
    ceny.jednotka,
    ceny.cena_kc
FROM
    (SELECT
         cp.payroll_year AS rok,
         ib.name AS odvetvi,
         CAST(AVG(cp.value) AS numeric(10,2)) AS mzda_kc
     FROM czechia_payroll cp
     JOIN czechia_payroll_industry_branch ib ON ib.code = cp.industry_branch_code
     WHERE cp.value IS NOT NULL
       AND cp.value_type_code = 5958    -- průměrná hrubá mzda na zaměstnance
       AND cp.calculation_code = 200    -- přepočtený počet zaměstnanců
     GROUP BY cp.payroll_year, ib.name) AS mzdy
JOIN
    (SELECT
         EXTRACT(YEAR FROM p.date_from) AS rok,
         pc.name AS potravina,
         pc.price_value AS mnozstvi,
         pc.price_unit AS jednotka,
         CAST(AVG(p.value) AS numeric(10,2)) AS cena_kc
     FROM czechia_price p
     JOIN czechia_price_category pc ON pc.code = p.category_code
     WHERE p.value IS NOT NULL
     GROUP BY EXTRACT(YEAR FROM p.date_from), pc.name, pc.price_value, pc.price_unit) AS ceny
ON ceny.rok = mzdy.rok;


/* sekundární tabulka pro dodatečná data o dalších evropských státech */

DROP TABLE IF EXISTS t_michaela_novotna_project_SQL_secondary_final;

CREATE TABLE t_michaela_novotna_project_SQL_secondary_final AS
SELECT
    c.country AS stat,
    e.year AS rok,
    e.gdp AS hdp,
    e.gini,
    e.population AS populace
FROM countries c
JOIN economies e ON e.country = c.country
WHERE c.continent = 'Europe'
  AND e.year BETWEEN 2006 AND 2018;


/* ------------------------------------------------------------
   otázka 1. Rostou v průběhu let mzdy ve všech odvětvích,
   nebo v některých klesají?

   odpověď - ne, nerostou všude. Ze 19 odvětví jich 16 zaznamenalo
   alespoň jeden meziroční pokles. Nejvíc poklesů má Těžba a dobývání
   (4), následuje Výroba a rozvod elektřiny (3). Bez poklesu prošly
   celé období jen Zpracovatelský průmysl, Zdravotní a sociální péče
   a Ostatní činnosti.
   ------------------------------------------------------------ */

SELECT DISTINCT
    t1.odvetvi,
    t2.rok,
    t1.mzda_kc                                    AS mzda_predchozi_rok,
    t2.mzda_kc                                    AS mzda_aktualni_rok,
    ROUND(100 * (t2.mzda_kc / t1.mzda_kc - 1), 2) AS zmena_pct
FROM t_michaela_novotna_project_SQL_primary_final AS t1
JOIN t_michaela_novotna_project_SQL_primary_final AS t2
  ON t2.odvetvi = t1.odvetvi
 AND t2.rok = t1.rok + 1
WHERE t2.mzda_kc < t1.mzda_kc
ORDER BY t1.odvetvi, t2.rok;


SELECT
    t1.odvetvi,
    COUNT(DISTINCT t2.rok) AS pocet_poklesu
FROM t_michaela_novotna_project_SQL_primary_final AS t1
JOIN t_michaela_novotna_project_SQL_primary_final AS t2
  ON t2.odvetvi = t1.odvetvi
 AND t2.rok = t1.rok + 1
WHERE t2.mzda_kc < t1.mzda_kc
GROUP BY t1.odvetvi
ORDER BY pocet_poklesu DESC;


/* ------------------------------------------------------------
   otázka 2. Kolik je možné si koupit litrů mléka a kilogramů chleba
   za první a poslední srovnatelné období?

   odpověď - za průměrnou mzdu se v roce 2018 koupilo 1 669,6 litru
   mléka a 1 365,2 kg chleba, oproti 1 465,7 litru a 1 313,0 kg
   v roce 2006. Dostupnost se tedy zlepšila o 13,9 % u mléka
   a o 4,0 % u chleba.
   ------------------------------------------------------------ */

SELECT
    ceny.rok,
    ceny.potravina,
    ceny.jednotka,
    mzdy.mzda_kc,
    ceny.cena_kc,
    ROUND(mzdy.mzda_kc / ceny.cena_kc, 1) AS mnozstvi_za_mzdu
FROM
    (SELECT rok, ROUND(AVG(mzda_kc), 2) AS mzda_kc
     FROM (SELECT DISTINCT rok, odvetvi, mzda_kc
           FROM t_michaela_novotna_project_SQL_primary_final) AS x
     GROUP BY rok) AS mzdy
JOIN
    (SELECT DISTINCT rok, potravina, jednotka, cena_kc
     FROM t_michaela_novotna_project_SQL_primary_final
     WHERE potravina IN ('Mléko polotučné pasterované',
                         'Chléb konzumní kmínový')) AS ceny
    ON ceny.rok = mzdy.rok
WHERE ceny.rok IN (2006, 2018)
ORDER BY ceny.potravina, ceny.rok;


/* ------------------------------------------------------------
   otázka 3. Která kategorie potravin zdražuje nejpomaleji?

   odpověď - nejnižší procentuální nárůst je u krystalového cukru,
   který za sledované období průměrně nezdražoval, ale zlevňoval
   o 1,92 % ročně. Druhá jsou rajčata (−0,74 %). Nejrychleji
   zdražovaly papriky (+7,29 %) a máslo (+6,67 %).
   ------------------------------------------------------------ */

SELECT
    t1.potravina,
    ROUND(AVG(100 * (t2.cena_kc / t1.cena_kc - 1)), 2) AS prumerny_mezirocni_rust
FROM t_michaela_novotna_project_SQL_primary_final AS t1
JOIN t_michaela_novotna_project_SQL_primary_final AS t2
  ON t2.potravina = t1.potravina
 AND t2.rok = t1.rok + 1
 AND t2.odvetvi = t1.odvetvi     -- aby se každá dvojice let počítala jen jednou
GROUP BY t1.potravina
ORDER BY prumerny_mezirocni_rust;


/* ------------------------------------------------------------
   otázka 4. Existuje rok, ve kterém byl meziroční nárůst cen
   potravin výrazně vyšší než růst mezd (větší než 10 %)?

   odpověď - ne, neexistuje. Největší rozdíl nastal v roce 2013
   a činil 7,57 procentního bodu. Hranice 10 bodů nebyla překročena
   ani jednou. Rok 2013 vyčnívá proto, že jako jediný rok v celém
   období mzdy klesly (−1,56 %).

   Poznámka k metodě: růst cen se počítá jako průměr procentních
   změn jednotlivých potravin. Průměr korun by nedával smysl,
   protože kilogram másla a půllitr piva nejdou sčítat.
   ------------------------------------------------------------ */

SELECT
    ceny.rok,
    mzdy.rust_mezd,
    ceny.rust_cen,
    ROUND(ceny.rust_cen - mzdy.rust_mezd, 2) AS rozdil_pb
FROM
    (SELECT t2.rok,
            ROUND(AVG(100 * (t2.cena_kc / t1.cena_kc - 1)), 2) AS rust_cen
     FROM (SELECT DISTINCT rok, potravina, cena_kc
           FROM t_michaela_novotna_project_SQL_primary_final) AS t1
     JOIN (SELECT DISTINCT rok, potravina, cena_kc
           FROM t_michaela_novotna_project_SQL_primary_final) AS t2
       ON t2.potravina = t1.potravina AND t2.rok = t1.rok + 1
     GROUP BY t2.rok) AS ceny
JOIN
    (SELECT t2.rok,
            ROUND(100 * (AVG(t2.mzda_kc) / AVG(t1.mzda_kc) - 1), 2) AS rust_mezd
     FROM (SELECT DISTINCT rok, odvetvi, mzda_kc
           FROM t_michaela_novotna_project_SQL_primary_final) AS t1
     JOIN (SELECT DISTINCT rok, odvetvi, mzda_kc
           FROM t_michaela_novotna_project_SQL_primary_final) AS t2
       ON t2.odvetvi = t1.odvetvi AND t2.rok = t1.rok + 1
     GROUP BY t2.rok) AS mzdy
    ON mzdy.rok = ceny.rok
ORDER BY rozdil_pb DESC;


/* ------------------------------------------------------------
   otázka 5. Má výška HDP vliv na změny ve mzdách a cenách potravin?

   odpověď - na mzdách se růst HDP projeví, ale se zpožděním
   zhruba jednoho roku. Po nejsilnějších letech HDP (2015: +5,39 %,
   2017: +5,17 %) vzrostly mzdy nejvíc až v roce následujícím
   (2018: +7,70 %, nejvíc za celé období). Naopak roky se slabým
   HDP (2012, 2013) přinesly nejslabší mzdový vývoj.

   Na cenách potravin se růst HDP neprojeví. V roce 2009 ceny
   propadly o 6,58 % a v letech 2014–2016 klesaly, přestože HDP rostlo.

   Jde ale o souběh, ne o prokázanou příčinu. 12 meziročních změn
   je malý vzorek a mzdy jsou nominální, neočištěné o inflaci.
   ------------------------------------------------------------ */

SELECT
    hdp.rok,
    hdp.rust_hdp,
    mzdy.rust_mezd AS mzdy_stejny_rok,
    ceny.rust_cen  AS ceny_stejny_rok
FROM
    (SELECT t2.rok,
            ROUND(CAST(100 * (t2.hdp / t1.hdp - 1) AS numeric), 2) AS rust_hdp
     FROM t_michaela_novotna_project_SQL_secondary_final AS t1
     JOIN t_michaela_novotna_project_SQL_secondary_final AS t2
       ON t2.rok = t1.rok + 1 AND t2.stat = t1.stat
     WHERE t1.stat = 'Czech Republic') AS hdp
JOIN
    (SELECT t2.rok,
            ROUND(100 * (AVG(t2.mzda_kc) / AVG(t1.mzda_kc) - 1), 2) AS rust_mezd
     FROM (SELECT DISTINCT rok, odvetvi, mzda_kc
           FROM t_michaela_novotna_project_SQL_primary_final) AS t1
     JOIN (SELECT DISTINCT rok, odvetvi, mzda_kc
           FROM t_michaela_novotna_project_SQL_primary_final) AS t2
       ON t2.odvetvi = t1.odvetvi AND t2.rok = t1.rok + 1
     GROUP BY t2.rok) AS mzdy
    ON mzdy.rok = hdp.rok
JOIN
    (SELECT t2.rok,
            ROUND(AVG(100 * (t2.cena_kc / t1.cena_kc - 1)), 2) AS rust_cen
     FROM (SELECT DISTINCT rok, potravina, cena_kc
           FROM t_michaela_novotna_project_SQL_primary_final) AS t1
     JOIN (SELECT DISTINCT rok, potravina, cena_kc
           FROM t_michaela_novotna_project_SQL_primary_final) AS t2
       ON t2.potravina = t1.potravina AND t2.rok = t1.rok + 1
     GROUP BY t2.rok) AS ceny
    ON ceny.rok = hdp.rok
ORDER BY hdp.rok;
