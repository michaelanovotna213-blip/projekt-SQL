/*primární tabulka pro data mezd a cen potravin za Českou republiku sjednocených na totožné porovnatelné období – společné roky*/
CREATE TABLE t_michaela_novotna_project_SQL_primary_final  AS
select
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
       AND cp.value_type_code = 5958
    AND cp.calculation_code = 200
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

/* sekundární tabulka pro dodatečná data o dalších evropských státech*/
CREATE TABLE "t_michaela_novotna_project_SQL_secondary_final" AS
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

/* otázka 1. Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?*/


WITH mzdy AS (
    SELECT DISTINCT rok, odvetvi, mzda_kc
    FROM t_michaela_novotna_project_SQL_primary_final
),
zmeny AS (
    SELECT
        odvetvi,
        rok,
        mzda_kc,
        LAG(mzda_kc) OVER (PARTITION BY odvetvi ORDER BY rok) AS mzda_predchozi_rok
    FROM mzdy
)
SELECT
    odvetvi,
    rok,
    mzda_predchozi_rok,
    mzda_kc AS mzda_aktualni_rok,
    ROUND(100 * (mzda_kc / mzda_predchozi_rok - 1), 2) AS zmena_pct
FROM zmeny
WHERE mzda_kc < mzda_predchozi_rok
ORDER BY odvetvi, rok;

/* Počet poklesů v každém odvětví. */

WITH mzdy AS (
    SELECT DISTINCT rok, odvetvi, mzda_kc
    FROM t_michaela_novotna_project_SQL_primary_final),
zmeny AS (
    SELECT
        odvetvi,
        rok,
        mzda_kc,
        LAG(mzda_kc) OVER (PARTITION BY odvetvi ORDER BY rok) AS mzda_predchozi_rok
    FROM mzdy)
SELECT
    odvetvi,
    COUNT(*) AS pocet_poklesu
FROM zmeny
WHERE mzda_kc < mzda_predchozi_rok
GROUP BY odvetvi
ORDER BY pocet_poklesu DESC, odvetvi;


/* otázka 2 Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd? */

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
           FROM t_michaela_novotna_project_SQL_primary_final ) AS x
     GROUP BY rok) AS mzdy
JOIN
    (SELECT DISTINCT rok, potravina, jednotka, cena_kc
     FROM t_michaela_novotna_project_SQL_primary_final
     WHERE potravina IN ('Mléko polotučné pasterované',
                         'Chléb konzumní kmínový')) AS ceny
    ON ceny.rok = mzdy.rok
WHERE ceny.rok IN (2006, 2018)
ORDER BY ceny.potravina, ceny.rok;

/*otázka 3 Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst*/

WITH ceny AS (
    SELECT DISTINCT rok, potravina, cena_kc
    FROM t_michaela_novotna_project_SQL_primary_final),
zmeny AS (
    SELECT
        potravina,
        rok,
        cena_kc,
        LAG(cena_kc) OVER (PARTITION BY potravina ORDER BY rok) AS cena_predchozi_rok
    FROM ceny)
SELECT
    potravina,
    ROUND(AVG(100 * (cena_kc / cena_predchozi_rok - 1)), 2) AS prumerny_mezirocni_rust
FROM zmeny
WHERE cena_predchozi_rok IS NOT NULL
GROUP BY potravina
ORDER BY prumerny_mezirocni_rust;


/* otázka 4 Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?*/

WITH mzdy AS (
    SELECT DISTINCT rok, odvetvi, mzda_kc
    FROM t_michaela_novotna_project_SQL_primary_final),
mzda_rok AS (
    SELECT rok, AVG(mzda_kc) AS mzda_kc
    FROM mzdy
    GROUP BY rok),
rust_mezd AS (
    SELECT
        rok,
        ROUND(100 * (mzda_kc / LAG(mzda_kc) OVER (ORDER BY rok) - 1), 2) AS rust
    FROM mzda_rok),
ceny AS (
    SELECT DISTINCT rok, potravina, cena_kc
    FROM t_michaela_novotna_project_SQL_primary_final),
zmeny_cen AS (
    SELECT
        potravina,
        rok,
        cena_kc,
        LAG(cena_kc) OVER (PARTITION BY potravina ORDER BY rok) AS cena_predchozi_rok
    FROM ceny),
rust_cen AS (
    SELECT
        rok,
        ROUND(AVG(100 * (cena_kc / cena_predchozi_rok - 1)), 2) AS rust
    FROM zmeny_cen
    WHERE cena_predchozi_rok IS NOT NULL
    GROUP BY rok)
SELECT
    rust_mezd.rok,
    rust_mezd.rust                           AS rust_mezd,
    rust_cen.rust                            AS rust_cen,
    ROUND(rust_cen.rust - rust_mezd.rust, 2) AS rozdil_pb
FROM rust_mezd
JOIN rust_cen ON rust_cen.rok = rust_mezd.rok
WHERE rust_mezd.rust IS NOT NULL
ORDER BY rozdil_pb DESC;


/* otázka 5 Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, projeví se to na cenách potravin či mzdách ve stejném nebo následujícím roce výraznějším růstem
 */
WITH mzdy AS (
    SELECT DISTINCT rok, odvetvi, mzda_kc
    FROM t_michaela_novotna_project_SQL_primary_final),
mzda_rok AS (
    SELECT rok, AVG(mzda_kc) AS mzda_kc
    FROM mzdy
    GROUP BY rok),
rust_mezd AS (
    SELECT
        rok,
        ROUND(100 * (mzda_kc / LAG(mzda_kc) OVER (ORDER BY rok) - 1), 2) AS rust
    FROM mzda_rok),
ceny AS (
    SELECT DISTINCT rok, potravina, cena_kc
    FROM t_michaela_novotna_project_SQL_primary_final),
zmeny_cen AS (
    SELECT
        potravina,
        rok,
        cena_kc,
        LAG(cena_kc) OVER (PARTITION BY potravina ORDER BY rok) AS cena_predchozi_rok
    FROM ceny),
rust_cen AS (
    SELECT
        rok,
        ROUND(AVG(100 * (cena_kc / cena_predchozi_rok - 1)), 2) AS rust
    FROM zmeny_cen
    WHERE cena_predchozi_rok IS NOT NULL
    GROUP BY rok),
rust_hdp AS (
    SELECT
        rok,
        ROUND(CAST(100 * (hdp / LAG(hdp) OVER (ORDER BY rok) - 1) AS numeric), 2) AS rust
    FROM t_michaela_novotna_project_SQL_secondary_final
    WHERE stat = 'Czech Republic')
SELECT
    rust_hdp.rok,
    rust_hdp.rust                                        AS rust_hdp,
    rust_mezd.rust                                       AS mzdy_stejny_rok,
    rust_cen.rust                                        AS ceny_stejny_rok,
    LEAD(rust_mezd.rust) OVER (ORDER BY rust_hdp.rok)    AS mzdy_dalsi_rok,
    LEAD(rust_cen.rust)  OVER (ORDER BY rust_hdp.rok)    AS ceny_dalsi_rok
FROM rust_hdp
LEFT JOIN rust_mezd ON rust_mezd.rok = rust_hdp.rok
LEFT JOIN rust_cen  ON rust_cen.rok  = rust_hdp.rok
WHERE rust_hdp.rust IS NOT NULL
ORDER BY rust_hdp.rok;

